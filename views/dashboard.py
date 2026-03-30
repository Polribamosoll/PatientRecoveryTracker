"""
views/dashboard.py
------------------
The main patient list dashboard.
Shows all patients, their current phase, and days in that phase.
Clicking a patient navigates to the Patient Detail view.
"""

from __future__ import annotations

from datetime import date

import streamlit as st
import pandas as pd

from db.patients import get_all_patients, get_phase_history


def show_dashboard() -> None:
    st.title("Patient Dashboard")
    st.caption("Overview of all patients and their recovery progress.")

    col_refresh, col_add = st.columns([8, 2])
    with col_add:
        if st.button("+ Add Patient", use_container_width=True, type="primary"):
            st.session_state.page = "add_patient"
            st.rerun()

    st.divider()

    patients = get_all_patients()

    if not patients:
        st.info("No patients yet. Use **+ Add Patient** to get started.")
        return

    # Build the summary table
    rows = []
    for p in patients:
        phase_name = p.get("phases", {}).get("name", "—") if p.get("phases") else "—"
        days_in_phase = _days_in_current_phase(p["id"], p["current_phase_id"])
        rows.append({
            "Name":          p["name"],
            "Phase":         phase_name,
            "Days in Phase": days_in_phase if days_in_phase is not None else "—",
            "Added":         p["created_at"][:10],  # trim to date
            "_id":           p["id"],
        })

    df = pd.DataFrame(rows)

    # Render each patient as a clickable row
    st.subheader(f"{len(patients)} patient(s)")

    # Column headers
    hcols = st.columns([3, 4, 2, 2, 2])
    for col, header in zip(hcols, ["Name", "Current Phase", "Days in Phase", "Added", ""]):
        col.markdown(f"**{header}**")

    st.divider()

    for _, row in df.iterrows():
        cols = st.columns([3, 4, 2, 2, 2])
        cols[0].write(row["Name"])
        cols[1].write(row["Phase"])
        cols[2].write(str(row["Days in Phase"]))
        cols[3].write(row["Added"])
        with cols[4]:
            if st.button("View →", key=f"view_{row['_id']}"):
                st.session_state.page = "patient_detail"
                st.session_state.selected_patient_id = row["_id"]
                st.rerun()


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
