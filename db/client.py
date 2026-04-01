"""
db/client.py
------------
Creates and caches a single Supabase client for the lifetime of the
Streamlit server process.  Using @st.cache_resource means the client is
created once and reused across every user session (fine for a single-
doctor app).
"""

import os

import streamlit as st
from supabase import create_client, Client


def _get_secret(key: str) -> str:
    """Read a secret from environment variables first, then st.secrets."""
    value = os.environ.get(key)
    if value:
        return value
    return st.secrets[key]


@st.cache_resource
def get_supabase() -> Client:
    """Return a cached Supabase client."""
    url: str = _get_secret("SUPABASE_URL")
    key: str = _get_secret("SUPABASE_KEY")
    return create_client(url, key)
