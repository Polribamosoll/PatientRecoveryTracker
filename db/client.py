"""
db/client.py
------------
Creates and caches a single Supabase client for the lifetime of the
Streamlit server process.  Using @st.cache_resource means the client is
created once and reused across every user session (fine for a single-
doctor app).
"""

import streamlit as st
from supabase import create_client, Client


@st.cache_resource
def get_supabase() -> Client:
    """Return a cached Supabase client built from st.secrets."""
    url: str = st.secrets["SUPABASE_URL"]
    key: str = st.secrets["SUPABASE_KEY"]
    return create_client(url, key)
