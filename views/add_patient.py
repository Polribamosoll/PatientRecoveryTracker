"""
views/add_patient.py
--------------------
Form to register a new patient.
On submission: creates the patient in the DB and navigates
straight to their detail page.
"""

from __future__ import annotations

from datetime import date

import streamlit as st

from db.patients import create_patient


def show_add_patient() -> None:
    if st.button("← Back to Dashboard"):
        st.session_state.page = "dashboard"
        st.rerun()

    st.title("Add New Patient")
    st.caption("Fill in the patient details below. All fields except Name are optional.")

    with st.form("add_patient_form", clear_on_submit=True):
        name = st.text_input("Full Name *", placeholder="e.g. Maria Garcia")

        dob = st.date_input(
            "Date of Birth",
            value=None,
            min_value=date(1900, 1, 1),
            max_value=date.today(),
        )

        notes = st.text_area(
            "Initial Notes",
            placeholder="Any relevant background, diagnosis, allergies…",
            height=100,
        )

        submitted = st.form_submit_button("Create Patient", type="primary")

    if submitted:
        if not name.strip():
            st.error("Patient name is required.")
            return

        patient = create_patient(
            name=name.strip(),
            dob=dob,
            notes=notes.strip(),
        )

        st.success(f"Patient **{patient['name']}** created successfully!")

        # Navigate directly to the new patient's detail page
        st.session_state.page = "patient_detail"
        st.session_state.selected_patient_id = patient["id"]
        st.rerun()
