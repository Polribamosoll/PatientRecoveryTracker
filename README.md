# Patient Recovery Tracker

Internal web app for tracking patient recovery across 8 sequential phases.

Built with **Python · Streamlit · Supabase (PostgreSQL)**.

## Quick Start

### 1. Supabase — run the schema

Open your Supabase project → SQL Editor → paste and run `sql/schema.sql`.
This creates all tables and seeds the 8 phases + their default requirements.

### 2. Configure secrets

```bash
cp .streamlit/secrets.toml.example .streamlit/secrets.toml
```

Edit `.streamlit/secrets.toml` and fill in:

| Key | Where to find it |
|---|---|
| `APP_PASSWORD` | Pick anything strong |
| `SUPABASE_URL` | Supabase → Project Settings → API → Project URL |
| `SUPABASE_KEY` | Supabase → Project Settings → API → anon / public key |

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Run

```bash
streamlit run app.py
```

---

## Project Structure

```
app.py                    # Entry point — auth, routing, sidebar
requirements.txt
sql/
  schema.sql              # Full DB schema + seed data (run once in Supabase)
db/
  client.py               # Supabase client singleton
  patients.py             # Patient CRUD + phase advancement
  progress.py             # Requirements, events, progress tracking
views/
  dashboard.py            # Patient list overview
  patient_detail.py       # Per-patient detail, requirements, phase advance
  add_patient.py          # New patient form
.streamlit/
  secrets.toml.example    # Template — copy to secrets.toml and fill in
```

## Deploying to Streamlit Cloud

1. Push the repo to GitHub (secrets.toml is git-ignored).
2. Go to share.streamlit.io → New app → select your repo.
3. Add secrets via the Secrets section in the app settings (same key/value pairs as secrets.toml).
4. Deploy.

## Customising Phases & Requirements

Edit `sql/schema.sql` — specifically the `INSERT INTO phase_requirements` block — then re-run just those inserts in Supabase. You can also add/edit rows directly in the Supabase Table Editor without touching code.

To add a new tracked event date (beyond surgery, injury, last checkup), add a tuple to `KNOWN_EVENTS` in `views/patient_detail.py` and use the matching `event_key` in a `time_based` requirement row.
