"""
app.py
------
Entry point for the Patient Recovery Tracker.

Run with:
    streamlit run app.py

Navigation is handled via st.session_state.page so that we can pass
state (e.g. selected patient ID) between views without URL params.

Pages:
  'dashboard'      → views/dashboard.py
  'patient_detail' → views/patient_detail.py  (requires session_state.selected_patient_id)
  'add_patient'    → views/add_patient.py
"""

import streamlit as st

from views.dashboard import show_dashboard
from views.patient_detail import show_patient_detail
from views.add_patient import show_add_patient


# ── Page config ───────────────────────────────────────────────────────────────
# Must be the very first Streamlit call in the script.
st.set_page_config(
    page_title="Seguimiento de Recuperación de Pacientes",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded",
)


# ── Auth ──────────────────────────────────────────────────────────────────────

def check_auth() -> None:
    """
    Simple password gate.  The password lives in .streamlit/secrets.toml
    under the key APP_PASSWORD.

    On Streamlit Cloud, add it via the Secrets management UI instead of
    committing a secrets.toml file.
    """
    if st.session_state.get("authenticated"):
        return  # already logged in

    # Centre the login form
    _, centre, _ = st.columns([2, 3, 2])
    with centre:
        st.markdown("## 🏥 Seguimiento de Recuperación de Pacientes")
        st.markdown("Introduce la contraseña para continuar.")
        password = st.text_input("Contraseña", type="password", key="login_pw")
        if st.button("Entrar", type="primary", use_container_width=True):
            if password == st.secrets.get("APP_PASSWORD", ""):
                st.session_state.authenticated = True
                st.rerun()
            else:
                st.error("Contraseña incorrecta.")

    st.stop()  # Block the rest of the app from rendering


# ── Sidebar ───────────────────────────────────────────────────────────────────

def render_sidebar() -> None:
    with st.sidebar:
        st.markdown("### 🏥 Seguimiento de Recuperación")
        st.divider()

        # Botones de navegación
        if st.button("📋  Panel principal", use_container_width=True):
            st.session_state.page = "dashboard"
            st.session_state.pop("selected_patient_id", None)
            st.rerun()

        if st.button("➕  Añadir paciente", use_container_width=True):
            st.session_state.page = "add_patient"
            st.session_state.pop("selected_patient_id", None)
            st.rerun()

        st.divider()

        if st.button("🚪  Cerrar sesión", use_container_width=True):
            st.session_state.authenticated = False
            st.session_state.page = "dashboard"
            st.session_state.pop("selected_patient_id", None)
            st.rerun()


# ── Router ────────────────────────────────────────────────────────────────────

def main() -> None:
    check_auth()
    render_sidebar()

    # Default page
    page = st.session_state.get("page", "dashboard")

    if page == "patient_detail":
        patient_id = st.session_state.get("selected_patient_id")
        if not patient_id:
            # Guard against arriving here without a patient selected
            st.session_state.page = "dashboard"
            st.rerun()
        show_patient_detail(patient_id)

    elif page == "add_patient":
        show_add_patient()

    else:
        show_dashboard()


if __name__ == "__main__":
    main()
