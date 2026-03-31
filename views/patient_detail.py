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

import matplotlib.pyplot as plt
import streamlit as st

from db.patients import get_patient, advance_patient_phase, update_patient_notes, delete_patient, update_patient_info
from db.progress import (
    get_all_phases,
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
    ("injury_date",    "Fecha de lesión / inicio"),
    ("surgery_date",   "Fecha de cirugía"),
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

    # ── Phase Timeline ────────────────────────────────────────────────────────
    phases_simple = get_all_phases()
    _show_patient_timeline(current_phase_id, phases_simple)

    st.divider()

    # ── Key Events ────────────────────────────────────────────────────────────
    with st.expander("Fechas clave", expanded=True):
        st.caption("Registra las fechas importantes. Se usan para los requisitos basados en tiempo.")
        event_cols = st.columns(len(KNOWN_EVENTS))
        new_dates: dict[str, tuple[str, object]] = {}

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
                new_dates[event_key] = (event_label, new_date)

        if st.button("Guardar fechas", key=f"save_events_{patient_id}"):
            for event_key, (event_label, new_date) in new_dates.items():
                upsert_patient_event(patient_id, event_key, event_label, new_date)
            st.success("Fechas guardadas.")
            st.rerun()

    # ── Patient Info ──────────────────────────────────────────────────────────
    with st.expander("Información del paciente", expanded=False):
        st.caption("Datos demográficos y antecedentes del paciente.")
        info_col1, info_col2 = st.columns(2)

        with info_col1:
            current_dob = (
                date.fromisoformat(patient["date_of_birth"])
                if patient.get("date_of_birth") else None
            )
            new_dob = st.date_input(
                "Fecha de nacimiento",
                value=current_dob,
                min_value=date(1900, 1, 1),
                max_value=date.today(),
                key=f"info_dob_{patient_id}",
            )
            gender_options = ["", "Masculino", "Femenino", "Otro", "No especificado"]
            current_gender = patient.get("gender") or ""
            gender_index = gender_options.index(current_gender) if current_gender in gender_options else 0
            new_gender = st.selectbox(
                "Género",
                options=gender_options,
                index=gender_index,
                key=f"info_gender_{patient_id}",
            )

        with info_col2:
            new_injuries = st.text_area(
                "Lesiones previas",
                value=patient.get("previous_injuries") or "",
                height=100,
                placeholder="p. ej. Esguince de tobillo 2021, rotura fibrilar isquiotibial…",
                key=f"info_injuries_{patient_id}",
            )
            new_sports = st.text_input(
                "Deportes practicados",
                value=patient.get("sports_practiced") or "",
                placeholder="p. ej. Fútbol, natación, ciclismo…",
                key=f"info_sports_{patient_id}",
            )

        if st.button("Guardar información", key=f"save_info_{patient_id}"):
            update_patient_info(
                patient_id,
                dob=new_dob if new_dob else None,
                gender=new_gender if new_gender else None,
                previous_injuries=new_injuries.strip() or None,
                sports_practiced=new_sports.strip() or None,
            )
            st.success("Información guardada.")
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


def _show_patient_timeline(current_phase_id: int, phases: list[dict]) -> None:
    """
    Horizontal timeline for a single patient.
    Past phases → filled grey-blue, current → highlighted blue + larger,
    future phases → empty/light.  Phase names appear below each node.
    """
    n = len(phases)
    fig, ax = plt.subplots(figsize=(13, 2.2))
    fig.patch.set_facecolor("#EEF2F7")
    ax.set_facecolor("#EEF2F7")

    # Backbone — split into completed and pending segments
    if current_phase_id > 1:
        ax.plot([1, current_phase_id], [0, 0], color="#3A7FBD", linewidth=2.5, zorder=1, solid_capstyle="round")
    if current_phase_id < n:
        ax.plot([current_phase_id, n], [0, 0], color="#C5D8EC", linewidth=2.5, zorder=1, solid_capstyle="round")

    for i, phase in enumerate(phases):
        x = i + 1
        pid = phase["id"]

        if pid < current_phase_id:
            # Completed phase
            color, size, edgecolor, lw = "#3A7FBD", 120, "white", 2
        elif pid == current_phase_id:
            # Current phase — bigger, brighter, with a label above
            color, size, edgecolor, lw = "#1A5FA8", 260, "white", 3
            ax.text(
                x, 0.22, "ACTUAL",
                ha="center", va="bottom", fontsize=7.5, color="#1A5FA8",
                fontweight="bold",
                bbox=dict(boxstyle="round,pad=0.3", facecolor="white",
                          edgecolor="#1A5FA8", linewidth=1.2, alpha=0.95),
            )
            ax.plot([x, x], [0.07, 0.14], color="#1A5FA8", lw=1.2, zorder=2)
        else:
            # Future phase
            color, size, edgecolor, lw = "#C5D8EC", 100, "#8FAFC8", 1.5

        ax.scatter([x], [0], s=size, color=color, zorder=3,
                   edgecolors=edgecolor, linewidths=lw)

        # Phase name below the line
        ax.text(
            x, -0.12, phase["name"],
            ha="right", va="top", fontsize=7,
            color="#1C2B3A", rotation=38, rotation_mode="anchor",
        )

    ax.set_xlim(0.4, n + 0.6)
    ax.set_ylim(-0.85, 0.65)
    ax.axis("off")
    plt.tight_layout(pad=0.3)
    st.pyplot(fig, use_container_width=True)
    plt.close(fig)
