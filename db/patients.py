"""
db/patients.py
--------------
All database operations that are primarily about *patients* —
creating, reading, and updating patient rows, plus managing the
phase-progress audit trail when a patient advances to a new phase.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Optional

from db.client import get_supabase


# ── Helpers ───────────────────────────────────────────────────────────────────

def _now_utc() -> str:
    return datetime.now(timezone.utc).isoformat()


# ── Read ──────────────────────────────────────────────────────────────────────

def get_all_patients() -> list[dict]:
    """
    Return all patients with their current phase name joined in.
    Used by the dashboard to show the patient list.
    """
    sb = get_supabase()
    result = (
        sb.table("patients")
        .select("id, name, date_of_birth, current_phase_id, notes, created_at, phases(name, order_index)")
        .order("name")
        .execute()
    )
    return result.data


def get_patient(patient_id: str) -> dict:
    """
    Return a single patient row with joined phase info.
    Raises an exception if the patient is not found.
    """
    sb = get_supabase()
    result = (
        sb.table("patients")
        .select("id, name, date_of_birth, gender, previous_injuries, sports_practiced, current_phase_id, notes, created_at, phases(id, name, description, order_index)")
        .eq("id", patient_id)
        .single()
        .execute()
    )
    return result.data


def get_phase_history(patient_id: str) -> list[dict]:
    """
    Return the phase progression audit trail for a patient,
    newest first.
    """
    sb = get_supabase()
    result = (
        sb.table("patient_phase_progress")
        .select("phase_id, started_at, completed_at, phases(name)")
        .eq("patient_id", patient_id)
        .order("started_at", desc=True)
        .execute()
    )
    return result.data


# ── Write ─────────────────────────────────────────────────────────────────────

def create_patient(
    name: str,
    dob: Optional[date],
    notes: str,
    gender: Optional[str] = None,
    previous_injuries: Optional[str] = None,
    sports_practiced: Optional[str] = None,
) -> dict:
    """
    Insert a new patient starting at Phase 1.
    Also seeds the phase-progress audit row for Phase 1.
    Returns the created patient row.
    """
    sb = get_supabase()

    # 1. Insert patient
    patient_result = (
        sb.table("patients")
        .insert({
            "name": name,
            "date_of_birth": dob.isoformat() if dob else None,
            "notes": notes,
            "gender": gender or None,
            "previous_injuries": previous_injuries or None,
            "sports_practiced": sports_practiced or None,
            "current_phase_id": 1,
        })
        .execute()
    )
    patient = patient_result.data[0]

    # 2. Seed Phase 1 audit row
    sb.table("patient_phase_progress").insert({
        "patient_id": patient["id"],
        "phase_id": 1,
    }).execute()

    return patient


def advance_patient_phase(patient_id: str, current_phase_id: int) -> int:
    """
    Move a patient from current_phase_id to current_phase_id + 1.
    - Marks the current phase-progress row as completed.
    - Inserts a new phase-progress row for the next phase.
    - Updates patients.current_phase_id.

    Returns the new phase id, or current_phase_id if already at 8.
    """
    if current_phase_id >= 8:
        return current_phase_id  # already at final phase

    next_phase_id = current_phase_id + 1
    sb = get_supabase()
    now = _now_utc()

    # 1. Close the current phase-progress row
    sb.table("patient_phase_progress").update(
        {"completed_at": now}
    ).eq("patient_id", patient_id).eq("phase_id", current_phase_id).is_(
        "completed_at", "null"
    ).execute()

    # 2. Open the next phase-progress row
    sb.table("patient_phase_progress").insert({
        "patient_id": patient_id,
        "phase_id": next_phase_id,
        "started_at": now,
    }).execute()

    # 3. Update the patient's current phase
    sb.table("patients").update(
        {"current_phase_id": next_phase_id}
    ).eq("id", patient_id).execute()

    return next_phase_id


def update_patient_notes(patient_id: str, notes: str) -> None:
    """Persist free-text notes for a patient."""
    get_supabase().table("patients").update(
        {"notes": notes}
    ).eq("id", patient_id).execute()


def update_patient_info(
    patient_id: str,
    dob: Optional[date],
    gender: Optional[str],
    previous_injuries: Optional[str],
    sports_practiced: Optional[str],
) -> None:
    """Persist demographic/profile fields for a patient."""
    get_supabase().table("patients").update({
        "date_of_birth":    dob.isoformat() if dob else None,
        "gender":           gender or None,
        "previous_injuries": previous_injuries or None,
        "sports_practiced": sports_practiced or None,
    }).eq("id", patient_id).execute()


def delete_patient(patient_id: str) -> None:
    """
    Permanently delete a patient and all related data.
    Relies on CASCADE DELETE in the database schema to remove
    patient_events, patient_phase_progress, and patient_requirement_progress.
    """
    get_supabase().table("patients").delete().eq("id", patient_id).execute()
