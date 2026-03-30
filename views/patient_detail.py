"""
views/patient_detail.py
-----------------------
Detailed view for a single patient.

Sections:
  1. Header — name, current phase, quick stats
  2. Key Events — record/edit important dates (surgery date, etc.)
  3. Recovery Phases — collapsible accordion for all 8 phases
     Each phase shows its requirements with checkboxes.
     Time-based requirements show days elapsed automatically.
  4. Advance Phase — button to move the patient to the next phase.
  5. Notes — free-text notes field.
"""

from __future__ import annotations

from datetime import date

import streamlit as st

from db.patients import get_patient, advance_patient_phase, update_patient_notes, delete_patient
from db.progress import (
    get_all_phases_with_requirements,
    get_patient_events,
    get_patient_requirement_progress,
    upsert_patient_event,
    set_requirement_met,
    is_time_based_requirement_met,
    days_since_event,
)

# The key events the app knows about.
# Add more tuples here to track additional dates.
KNOWN_EVENTS: list[tuple[str, str]] = [
    ("surgery_date",   "Fecha de cirugía"),
    ("injury_date",    "Fecha de lesión / inicio"),
    ("last_checkup",   "Última revisión"),
]


def show_patient_detail(patient_id: str) -> None:
    # ── Navigation breadcrumb ─────────────────────────────────────────────────
    nav_col, del_col = st.columns([6, 1])
    with nav_col:
        if st.button("← Volver al panel"):
            st.session_state.page = "dashboard"
            st.session_state.pop("selected_patient_id", None)
            st.rerun()
    with del_col:
        if st.button("🗑 Eliminar paciente", type="secondary"):
            st.session_state[f"confirm_delete_{patient_id}"] = True

    # ── Load data ─────────────────────────────────────────────────────────────
    patient  = get_patient(patient_id)
    events   = get_patient_events(patient_id)          # dict keyed by event_key
    req_prog = get_patient_requirement_progress(patient_id)  # dict keyed by req id
    all_phases = get_all_phases_with_requirements()    # all 8 phases with reqs

    current_phase_id = patient["current_phase_id"]

    # ── Confirm delete dialog ─────────────────────────────────────────────────
    if st.session_state.get(f"confirm_delete_{patient_id}"):
        st.error(f"¿Seguro que quieres eliminar a **{patient['name']}**? Esta acción es irreversible y borrará todos sus datos.")
        confirm_col, cancel_col = st.columns([1, 5])
        with confirm_col:
            if st.button("Sí, eliminar", type="primary"):
                delete_patient(patient_id)
                st.session_state.pop(f"confirm_delete_{patient_id}", None)
                st.session_state.page = "dashboard"
                st.session_state.pop("selected_patient_id", None)
                st.rerun()
        with cancel_col:
            if st.button("Cancelar"):
                st.session_state.pop(f"confirm_delete_{patient_id}", None)
                st.rerun()

    # ── Header ────────────────────────────────────────────────────────────────
    st.title(patient["name"])

    phase_info = patient.get("phases") or {}
    phase_label = phase_info.get("name", f"Phase {current_phase_id}")
    col1, col2, col3 = st.columns(3)
    col1.metric("Fase actual", phase_label)

    surgery_event = events.get("surgery_date")
    if surgery_event:
        days_post_op = days_since_event(surgery_event["event_date"])
        col2.metric("Días post-op", days_post_op)
    else:
        col2.metric("Días post-op", "—")

    if patient.get("date_of_birth"):
        dob = date.fromisoformat(patient["date_of_birth"])
        age = (date.today() - dob).days // 365
        col3.metric("Edad", age)

    st.divider()

    # ── Key Events ────────────────────────────────────────────────────────────
    with st.expander("Fechas clave", expanded=True):
        st.caption("Registra las fechas importantes. Se usan para los requisitos basados en tiempo.")
        event_cols = st.columns(len(KNOWN_EVENTS))

        for i, (event_key, event_label) in enumerate(KNOWN_EVENTS):
            existing = events.get(event_key)
            existing_date = (
                date.fromisoformat(existing["event_date"]) if existing else None
            )
            with event_cols[i]:
                new_date = st.date_input(
                    event_label,
                    value=existing_date,
                    max_value=date.today(),
                    key=f"event_{patient_id}_{event_key}",
                )
                if st.button("Guardar", key=f"save_event_{patient_id}_{event_key}"):
                    upsert_patient_event(
                        patient_id, event_key, event_label, new_date
                    )
                    st.success(f"{event_label} guardado.")
                    st.rerun()

    st.divider()

    # ── Phases & Requirements ─────────────────────────────────────────────────
    st.subheader("Fases de recuperación")

    for phase in all_phases:
        phase_id   = phase["id"]
        phase_name = phase["name"]
        reqs       = phase["phase_requirements"]

        is_current  = phase_id == current_phase_id
        is_past     = phase_id < current_phase_id
        is_future   = phase_id > current_phase_id

        # Label decoration
        if is_past:
            label = f"✅ {phase_name}"
        elif is_current:
            label = f"▶ {phase_name}  *(actual)*"
        else:
            label = f"🔒 {phase_name}"

        # Current phase is expanded by default; past/future collapsed
        with st.expander(label, expanded=is_current):
            if phase.get("description"):
                st.caption(phase["description"])

            if not reqs:
                st.info("No hay requisitos definidos para esta fase.")
                continue

            # Render each requirement
            for req in reqs:
                req_id   = req["id"]
                req_type = req["requirement_type"]
                progress = req_prog.get(req_id, {})

                if req_type == "time_based":
                    # Auto-compute from events; not manually checkable
                    met, elapsed = is_time_based_requirement_met(req, events)
                    threshold    = req["days_threshold"]
                    event_key    = req["event_key"]

                    if elapsed is not None:
                        status_icon = "✅" if met else "⏳"
                        status_text = f"{elapsed} / {threshold} days"
                    else:
                        status_icon = "❓"
                        status_text = f"('{event_key}' aún no registrado)"

                    # Show as a disabled, informational row
                    rcol1, rcol2 = st.columns([5, 2])
                    rcol1.markdown(f"{status_icon} &nbsp; {req['description']}")
                    rcol2.caption(status_text)

                else:
                    # Manual checkbox — only interactive for the current phase
                    current_value = progress.get("is_met", False)

                    if is_current:
                        new_value = st.checkbox(
                            req["description"],
                            value=current_value,
                            key=f"req_{patient_id}_{req_id}",
                        )
                        if new_value != current_value:
                            set_requirement_met(patient_id, req_id, new_value)
                            st.rerun()
                    else:
                        # Past or future: show as read-only
                        icon = "✅" if (is_past or current_value) else "☐"
                        st.markdown(f"{icon} &nbsp; {req['description']}")

    st.divider()

    # ── Advance Phase ─────────────────────────────────────────────────────────
    if current_phase_id < 8:
        st.subheader("Avanzar a la siguiente fase")

        # Count how many requirements are satisfied in the current phase
        current_phase = next(p for p in all_phases if p["id"] == current_phase_id)
        reqs          = current_phase["phase_requirements"]
        total         = len(reqs)
        met_count     = 0

        for req in reqs:
            if req["requirement_type"] == "time_based":
                met, _ = is_time_based_requirement_met(req, events)
                if met:
                    met_count += 1
            else:
                if req_prog.get(req["id"], {}).get("is_met", False):
                    met_count += 1

        all_met = met_count == total
        st.progress(met_count / total if total else 1.0, text=f"{met_count} / {total} requisitos completados")

        if not all_met:
            st.warning("Completa todos los requisitos anteriores antes de avanzar.")

        advance_label = f"Avanzar a la fase {current_phase_id + 1} →"
        if st.button(advance_label, disabled=not all_met, type="primary"):
            new_phase = advance_patient_phase(patient_id, current_phase_id)
            st.success(f"¡Paciente avanzado a la fase {new_phase}!")
            st.rerun()
    else:
        st.success("🎉 ¡El paciente ha completado las 8 fases — recuperación completa!")

    st.divider()

    # ── Notes ─────────────────────────────────────────────────────────────────
    with st.expander("Notas del paciente"):
        current_notes = patient.get("notes") or ""
        new_notes = st.text_area(
            "Notas",
            value=current_notes,
            height=150,
            key=f"notes_{patient_id}",
            label_visibility="collapsed",
        )
        if st.button("Guardar notas"):
            update_patient_notes(patient_id, new_notes)
            st.success("Notas guardadas.")
