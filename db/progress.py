"""
db/progress.py
--------------
Database operations for requirements, events, and the per-patient
progress on each requirement.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Optional

from db.client import get_supabase


# ── Helpers ───────────────────────────────────────────────────────────────────

def _now_utc() -> str:
    return datetime.now(timezone.utc).isoformat()


# ── Phases & Requirements (static lookup) ─────────────────────────────────────

def get_all_phases() -> list[dict]:
    """
    Return all 8 phases ordered by order_index (id, name, description, order_index).
    Lighter than get_all_phases_with_requirements — no requirements nested.
    """
    sb = get_supabase()
    result = (
        sb.table("phases")
        .select("id, name, description, order_index")
        .order("order_index")
        .execute()
    )
    return result.data


def get_all_phases_with_requirements() -> list[dict]:
    """
    Return all 8 phases, each with its list of requirements nested.
    Shape: [{id, name, description, order_index, phase_requirements: [...]}, ...]
    """
    sb = get_supabase()
    result = (
        sb.table("phases")
        .select("id, name, description, order_index, phase_requirements(id, description, requirement_type, days_threshold, event_key, order_index)")
        .order("order_index")
        .execute()
    )
    # Sort requirements within each phase
    for phase in result.data:
        phase["phase_requirements"].sort(key=lambda r: r["order_index"])
    return result.data


# ── Patient Events ─────────────────────────────────────────────────────────────

def get_patient_events(patient_id: str) -> dict[str, dict]:
    """
    Return patient events keyed by event_key for fast lookup.
    e.g. {'surgery_date': {'event_date': '2024-01-15', 'event_label': 'Surgery Date', ...}}
    """
    sb = get_supabase()
    result = (
        sb.table("patient_events")
        .select("id, event_key, event_label, event_date, notes")
        .eq("patient_id", patient_id)
        .execute()
    )
    return {row["event_key"]: row for row in result.data}


def upsert_patient_event(
    patient_id: str,
    event_key: str,
    event_label: str,
    event_date: date,
    notes: str = "",
) -> None:
    """
    Insert or update a patient event.
    The UNIQUE(patient_id, event_key) constraint makes this an upsert.
    """
    get_supabase().table("patient_events").upsert(
        {
            "patient_id": patient_id,
            "event_key": event_key,
            "event_label": event_label,
            "event_date": event_date.isoformat(),
            "notes": notes,
        },
        on_conflict="patient_id,event_key",
    ).execute()


# ── Requirement Progress ───────────────────────────────────────────────────────

def get_patient_requirement_progress(patient_id: str) -> dict[str, dict]:
    """
    Return requirement progress for a patient, keyed by requirement_id.
    e.g. {'uuid-...': {'is_met': True, 'met_at': '...', 'notes': ''}}
    """
    sb = get_supabase()
    result = (
        sb.table("patient_requirement_progress")
        .select("requirement_id, is_met, met_at, notes")
        .eq("patient_id", patient_id)
        .execute()
    )
    return {row["requirement_id"]: row for row in result.data}


def set_requirement_met(
    patient_id: str,
    requirement_id: str,
    is_met: bool,
) -> None:
    """
    Toggle a requirement as met or unmet for a patient.
    Uses upsert so we don't need to check if a row exists first.
    """
    sb = get_supabase()
    sb.table("patient_requirement_progress").upsert(
        {
            "patient_id": patient_id,
            "requirement_id": requirement_id,
            "is_met": is_met,
            "met_at": _now_utc() if is_met else None,
        },
        on_conflict="patient_id,requirement_id",
    ).execute()


# ── Time-based requirement auto-evaluation ────────────────────────────────────

def days_since_event(event_date_str: Optional[str]) -> Optional[int]:
    """
    Given an ISO date string (or None), return how many full days
    have elapsed since that date up to today.
    Returns None if event_date_str is None (event not yet recorded).
    """
    if not event_date_str:
        return None
    event_date = date.fromisoformat(event_date_str)
    return (date.today() - event_date).days


def is_time_based_requirement_met(
    requirement: dict,
    events: dict[str, dict],
) -> tuple[bool, Optional[int]]:
    """
    For a time_based requirement, check whether the days threshold is met.

    Returns:
        (is_met: bool, days_elapsed: int | None)
        days_elapsed is None if the referenced event hasn't been recorded yet.
    """
    event_key = requirement.get("event_key")
    threshold = requirement.get("days_threshold")

    if not event_key or threshold is None:
        return False, None

    event = events.get(event_key)
    if not event:
        return False, None

    elapsed = days_since_event(event["event_date"])
    if elapsed is None:
        return False, None

    return elapsed >= threshold, elapsed
