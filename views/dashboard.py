"""
views/dashboard.py
------------------
The main patient list dashboard.
Shows all patients, their current phase, and days in that phase.
Clicking a patient navigates to the Patient Detail view.
"""

from __future__ import annotations

from datetime import date

import matplotlib.pyplot as plt
import streamlit as st
import pandas as pd

from db.patients import get_all_patients, get_phase_history
from db.progress import get_all_phases


def show_dashboard() -> None:
    patients = get_all_patients()

    title_col, count_col = st.columns([7, 3])
    with title_col:
        st.title("Panel de pacientes")
        st.caption("Resumen de todos los pacientes y su progreso de recuperación.")
    with count_col:
        st.metric("Pacientes activos", len(patients))

    col_refresh, col_add = st.columns([8, 2])
    with col_add:
        if st.button("+ Añadir paciente", use_container_width=True, type="primary"):
            st.session_state.page = "add_patient"
            st.rerun()

    st.divider()

    if not patients:
        st.info("No hay pacientes aún. Usa **+ Añadir paciente** para empezar.")
        return

    # Phase timeline chart

    phases = get_all_phases()
    _show_phase_timeline(patients, phases)

    st.divider()

    # Build the summary table
    rows = []
    for p in patients:
        phase_name = p.get("phases", {}).get("name", "—") if p.get("phases") else "—"
        days_in_phase = _days_in_current_phase(p["id"], p["current_phase_id"])
        rows.append({
            "Nombre":          p["name"],
            "Fase":            phase_name,
            "Días en fase":    days_in_phase if days_in_phase is not None else "—",
            "Añadido":         p["created_at"][:10],  # trim to date
            "_id":             p["id"],
        })

    df = pd.DataFrame(rows)

    # Render each patient as a clickable row
    st.markdown(f"### {len(patients)} PACIENTE{'S' if len(patients) != 1 else ''}")

    # Column headers with styled background
    st.markdown(
        """
        <style>
        .table-header {
            background-color: #3A7FBD;
            border-radius: 6px;
            padding: 8px 12px;
            margin-bottom: 4px;
        }
        .table-header span {
            color: white;
            font-weight: 700;
            font-size: 0.78rem;
            letter-spacing: 0.08em;
            text-transform: uppercase;
        }
        </style>
        """,
        unsafe_allow_html=True,
    )

    hcols = st.columns([3, 4, 2, 2, 2])
    for col, header in zip(hcols, ["Nombre", "Fase actual", "Días en fase", "Añadido", ""]):
        if header:
            col.markdown(
                f'<div class="table-header"><span>{header}</span></div>',
                unsafe_allow_html=True,
            )

    st.markdown("<div style='margin-top:4px'></div>", unsafe_allow_html=True)

    for _, row in df.iterrows():
        cols = st.columns([3, 4, 2, 2, 2])
        cols[0].markdown(f"**{row['Nombre']}**")
        cols[1].write(row["Fase"])
        cols[2].write(str(row["Días en fase"]))
        cols[3].write(row["Añadido"])
        with cols[4]:
            if st.button("Ver →", key=f"view_{row['_id']}"):
                st.session_state.page = "patient_detail"
                st.session_state.selected_patient_id = row["_id"]
                st.rerun()


def _show_phase_timeline(patients: list[dict], phases: list[dict]) -> None:
    """
    Render a horizontal timeline with one node per recovery phase.
    Patient names appear above the node that matches their current phase.
    """
    # Group patient names by their current phase id
    phase_patients: dict[int, list[str]] = {}
    for p in patients:
        phase_patients.setdefault(p["current_phase_id"], []).append(p["name"])

    fig_height = 2.8

    n = len(phases)
    fig, ax = plt.subplots(figsize=(13, fig_height))
    fig.patch.set_facecolor("#EEF2F7")
    ax.set_facecolor("#EEF2F7")

    # Horizontal backbone
    ax.plot([1, n], [0, 0], color="#3A7FBD", linewidth=2.5, zorder=1, solid_capstyle="round")

    for i, phase in enumerate(phases):
        x = i + 1
        pid = phase["id"]
        names = phase_patients.get(pid, [])
        occupied = bool(names)

        # Phase node
        node_color = "#3A7FBD" if occupied else "#C5D8EC"
        ax.scatter([x], [0], s=150, color=node_color, zorder=3, edgecolors="white", linewidths=2)

        # Phase name below the line (rotated so they don't overlap)
        ax.text(
            x, -0.12, phase["name"],
            ha="right", va="top", fontsize=7,
            color="#1C2B3A", rotation=38, rotation_mode="anchor",
        )

        # Patient count badge above the node
        if occupied:
            count = len(names)
            ax.plot([x, x], [0.06, 0.14], color="#3A7FBD", lw=1, zorder=2)
            ax.text(
                x, 0.22, str(count),
                ha="center", va="bottom", fontsize=9, color="#1C2B3A", fontweight="bold",
                bbox=dict(
                    boxstyle="round,pad=0.35",
                    facecolor="white",
                    edgecolor="#3A7FBD",
                    linewidth=1.2,
                    alpha=0.95,
                ),
            )

    upper = 0.75
    ax.set_xlim(0.4, n + 0.6)
    ax.set_ylim(-0.85, upper)
    ax.axis("off")
    plt.tight_layout(pad=0.3)
    st.pyplot(fig, use_container_width=True)
    plt.close(fig)


def _days_in_current_phase(patient_id: str, current_phase_id: int) -> int | None:
    """
    Look up when the patient entered their current phase and return
    how many days ago that was.
    """
    history = get_phase_history(patient_id)
    for entry in history:
        if entry["phase_id"] == current_phase_id and entry["completed_at"] is None:
            started = entry["started_at"][:10]  # 'YYYY-MM-DD'
            return (date.today() - date.fromisoformat(started)).days
    return None
