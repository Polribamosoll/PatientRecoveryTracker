-- ============================================================
-- Patient Recovery Tracker — Supabase / PostgreSQL Schema
-- Run this entire file once in the Supabase SQL editor.
-- ============================================================

-- ── 1. PHASES ────────────────────────────────────────────────
-- Static lookup table. 8 rows, one per recovery phase.
-- Customize the names/descriptions here or in Supabase directly.

CREATE TABLE IF NOT EXISTS phases (
    id           INTEGER PRIMARY KEY,   -- 1 through 8
    name         TEXT    NOT NULL,
    description  TEXT,
    order_index  INTEGER NOT NULL       -- same as id here, kept for clarity
);

-- ── 2. PHASE REQUIREMENTS ────────────────────────────────────
-- Static lookup table. Each phase has N requirements.
-- requirement_type:
--   'manual'     → doctor ticks a checkbox
--   'time_based' → auto-satisfied when enough days have elapsed
--                  since a named patient event (event_key)

CREATE TABLE IF NOT EXISTS phase_requirements (
    id                UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    phase_id          INTEGER NOT NULL REFERENCES phases(id),
    description       TEXT    NOT NULL,
    requirement_type  TEXT    NOT NULL DEFAULT 'manual'
                          CHECK (requirement_type IN ('manual', 'time_based')),
    days_threshold    INTEGER,          -- only for time_based
    event_key         TEXT,             -- e.g. 'surgery_date' — only for time_based
    order_index       INTEGER NOT NULL DEFAULT 0
);

-- ── 3. PATIENTS ───────────────────────────────────────────────
-- One row per patient. current_phase_id is the live phase (1–8).

CREATE TABLE IF NOT EXISTS patients (
    id               UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
    name             TEXT  NOT NULL,
    date_of_birth    DATE,
    current_phase_id INTEGER NOT NULL DEFAULT 1 REFERENCES phases(id),
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 4. PATIENT EVENTS ─────────────────────────────────────────
-- Key dates per patient (surgery, injury, last checkup, etc.).
-- event_key must match what you use in phase_requirements.event_key.

CREATE TABLE IF NOT EXISTS patient_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id  UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    event_key   TEXT NOT NULL,   -- machine-readable key, e.g. 'surgery_date'
    event_label TEXT NOT NULL,   -- human-readable label, e.g. 'Surgery Date'
    event_date  DATE NOT NULL,
    notes       TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (patient_id, event_key)   -- one date per event type per patient
);

-- ── 5. PATIENT PHASE PROGRESS ─────────────────────────────────
-- Audit trail: when did each patient enter/leave each phase?
-- completed_at is NULL while the patient is still in that phase.

CREATE TABLE IF NOT EXISTS patient_phase_progress (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id   UUID    NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    phase_id     INTEGER NOT NULL REFERENCES phases(id),
    started_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ          -- NULL = currently active
);

-- ── 6. PATIENT REQUIREMENT PROGRESS ──────────────────────────
-- One row per (patient, requirement). Tracks whether the doctor
-- has checked off each requirement.

CREATE TABLE IF NOT EXISTS patient_requirement_progress (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id     UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    requirement_id UUID NOT NULL REFERENCES phase_requirements(id) ON DELETE CASCADE,
    is_met         BOOLEAN     NOT NULL DEFAULT FALSE,
    met_at         TIMESTAMPTZ,        -- when was it checked off?
    notes          TEXT,
    UNIQUE (patient_id, requirement_id)
);

-- ============================================================
-- SEED DATA — 8 phases and their requirements
-- These are generic post-surgical recovery phases.
-- Adjust descriptions and thresholds to match your specialty.
-- ============================================================

INSERT INTO phases (id, name, description, order_index) VALUES
(1, 'Phase 1 — Immediate Post-Op',    'Days 0–3: Stabilisation and pain control.',           1),
(2, 'Phase 2 — Early Recovery',       'Days 4–14: Wound monitoring and basic mobility.',     2),
(3, 'Phase 3 — Wound Healing',        'Days 15–30: Wound closure and infection surveillance.',3),
(4, 'Phase 4 — Mobility Restoration', 'Days 31–60: Restoring range of motion.',              4),
(5, 'Phase 5 — Strength Building',    'Days 61–90: Progressive resistance exercises.',       5),
(6, 'Phase 6 — Functional Training',  'Days 91–120: Task-specific functional exercises.',    6),
(7, 'Phase 7 — Return to Activity',   'Days 121–150: Gradual return to normal activities.',  7),
(8, 'Phase 8 — Full Recovery',        'Days 151+: Discharge planning and long-term follow-up.',8)
ON CONFLICT (id) DO NOTHING;

INSERT INTO phase_requirements (phase_id, description, requirement_type, days_threshold, event_key, order_index) VALUES
-- Phase 1
(1, 'Vitals stable (BP, HR, SpO₂ within normal range)',  'manual',     NULL, NULL,           1),
(1, 'Pain score ≤ 6 on NRS',                             'manual',     NULL, NULL,           2),
(1, 'No signs of immediate surgical complication',       'manual',     NULL, NULL,           3),
(1, 'Patient can tolerate oral fluids',                  'manual',     NULL, NULL,           4),

-- Phase 2
(2, 'At least 4 days since surgery',                     'time_based', 4,    'surgery_date', 1),
(2, 'Wound site inspected — no signs of infection',      'manual',     NULL, NULL,           2),
(2, 'Pain score ≤ 4 on NRS',                             'manual',     NULL, NULL,           3),
(2, 'Patient ambulating with assistance',                'manual',     NULL, NULL,           4),

-- Phase 3
(3, 'At least 15 days since surgery',                    'time_based', 15,   'surgery_date', 1),
(3, 'Wound fully closed or progressing well',            'manual',     NULL, NULL,           2),
(3, 'Sutures/staples removed or scheduled',              'manual',     NULL, NULL,           3),
(3, 'Patient tolerating solid food',                     'manual',     NULL, NULL,           4),

-- Phase 4
(4, 'At least 31 days since surgery',                    'time_based', 31,   'surgery_date', 1),
(4, 'ROM improved by ≥ 20° vs post-op baseline',         'manual',     NULL, NULL,           2),
(4, 'Able to walk 100 m without significant pain',       'manual',     NULL, NULL,           3),
(4, 'Physiotherapy sessions commenced',                  'manual',     NULL, NULL,           4),

-- Phase 5
(5, 'At least 61 days since surgery',                    'time_based', 61,   'surgery_date', 1),
(5, 'Strength ≥ 50% of contralateral side',              'manual',     NULL, NULL,           2),
(5, 'No swelling or effusion at rest',                   'manual',     NULL, NULL,           3),
(5, 'Patient independently managing home exercise plan', 'manual',     NULL, NULL,           4),

-- Phase 6
(6, 'At least 91 days since surgery',                    'time_based', 91,   'surgery_date', 1),
(6, 'Functional movement screen score ≥ 14',             'manual',     NULL, NULL,           2),
(6, 'No pain with daily functional tasks',               'manual',     NULL, NULL,           3),
(6, 'Balance and proprioception tests within norms',     'manual',     NULL, NULL,           4),

-- Phase 7
(7, 'At least 121 days since surgery',                   'time_based', 121,  'surgery_date', 1),
(7, 'Cleared for low-impact sport/activity',             'manual',     NULL, NULL,           2),
(7, 'Strength ≥ 80% of contralateral side',              'manual',     NULL, NULL,           3),
(7, 'Psychological readiness confirmed',                 'manual',     NULL, NULL,           4),

-- Phase 8
(8, 'At least 151 days since surgery',                   'time_based', 151,  'surgery_date', 1),
(8, 'Full return to pre-injury activity level',          'manual',     NULL, NULL,           2),
(8, 'Patient education on injury prevention completed',  'manual',     NULL, NULL,           3),
(8, 'Discharge letter / follow-up plan documented',      'manual',     NULL, NULL,           4);

-- ============================================================
-- ROW-LEVEL SECURITY (optional but recommended)
-- Enable RLS on all tables and restrict to authenticated users.
-- In Supabase: Authentication → Policies.
-- Quick setup for single-user app — allow all for authenticated:
-- ============================================================
-- ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "auth users only" ON patients FOR ALL TO authenticated USING (true);
-- (Repeat for each table if you enable Supabase Auth)
