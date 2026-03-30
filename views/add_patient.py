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
    if st.button("← Volver al panel"):
        st.session_state.page = "dashboard"
        st.rerun()

    st.title("Añadir nuevo paciente")
    st.caption("Rellena los datos del paciente. Todos los campos excepto el nombre son opcionales.")

    with st.form("add_patient_form", clear_on_submit=True):
        name = st.text_input("Nombre completo *", placeholder="p. ej. Maria García")

        dob = st.date_input(
            "Fecha de nacimiento",
            value=None,
            min_value=date(1900, 1, 1),
            max_value=date.today(),
        )

        notes = st.text_area(
            "Notas iniciales",
            placeholder="Antecedentes relevantes, diagnóstico, alergias…",
            height=100,
        )

        submitted = st.form_submit_button("Crear paciente", type="primary")

    if submitted:
        if not name.strip():
            st.error("El nombre del paciente es obligatorio.")
            return

        patient = create_patient(
            name=name.strip(),
            dob=dob,
            notes=notes.strip(),
        )

        st.success(f"Paciente **{patient['name']}** creado correctamente.")

        # Navigate directly to the new patient's detail page
        st.session_state.page = "patient_detail"
        st.session_state.selected_patient_id = patient["id"]
        st.rerun()
