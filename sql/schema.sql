-- ============================================================
-- Patient Recovery Tracker — Supabase / PostgreSQL Schema
-- Run this entire file once in the Supabase SQL editor.
-- ============================================================

-- ── 1. PHASES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS phases (
    id           INTEGER PRIMARY KEY,
    name         TEXT    NOT NULL,
    description  TEXT,
    order_index  INTEGER NOT NULL
);

-- ── 2. PHASE REQUIREMENTS ────────────────────────────────────
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
    days_threshold    INTEGER,
    event_key         TEXT,
    order_index       INTEGER NOT NULL DEFAULT 0,
    UNIQUE (phase_id, order_index)
);

-- ── 3. PATIENTS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS patients (
    id               UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
    name             TEXT  NOT NULL,
    date_of_birth    DATE,
    current_phase_id INTEGER NOT NULL DEFAULT 1 REFERENCES phases(id),
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 4. PATIENT EVENTS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS patient_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id  UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    event_key   TEXT NOT NULL,
    event_label TEXT NOT NULL,
    event_date  DATE NOT NULL,
    notes       TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (patient_id, event_key)
);

-- ── 5. PATIENT PHASE PROGRESS ─────────────────────────────────
CREATE TABLE IF NOT EXISTS patient_phase_progress (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id   UUID    NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    phase_id     INTEGER NOT NULL REFERENCES phases(id),
    started_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- ── 6. PATIENT REQUIREMENT PROGRESS ──────────────────────────
CREATE TABLE IF NOT EXISTS patient_requirement_progress (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id     UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    requirement_id UUID NOT NULL REFERENCES phase_requirements(id) ON DELETE CASCADE,
    is_met         BOOLEAN     NOT NULL DEFAULT FALSE,
    met_at         TIMESTAMPTZ,
    notes          TEXT,
    UNIQUE (patient_id, requirement_id)
);

-- ── 7. PATIENT WEEKLY CHECKS ──────────────────────────────────
-- Stores the pass/fail result for each manual requirement per week within a phase.
-- week_number 1–6 corresponds to the 6 weeks of each Aspetar phase.
CREATE TABLE IF NOT EXISTS patient_weekly_checks (
    id             UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id     UUID     NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    phase_id       INTEGER  NOT NULL REFERENCES phases(id),
    week_number    SMALLINT NOT NULL CHECK (week_number BETWEEN 1 AND 6),
    requirement_id UUID     NOT NULL REFERENCES phase_requirements(id) ON DELETE CASCADE,
    is_met         BOOLEAN  NOT NULL DEFAULT FALSE,
    recorded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes          TEXT,
    UNIQUE (patient_id, phase_id, week_number, requirement_id)
);

-- ============================================================
-- SEED DATA — 6 fases Aspetar y sus requisitos (en español)
-- ============================================================

INSERT INTO phases (id, name, description, order_index) VALUES
(1, 'Fase 0 — Pre-operatorio',    'Antes de la cirugía: criterios de entrada para operar.',                               1),
(2, 'Fase 1 — 0–6 semanas',       'Semanas 0–6: protección, recuperación de ROM y activación muscular.',                  2),
(3, 'Fase 2 — 6–12 semanas',      'Semanas 6–12: fuerza básica y control motor.',                                         3),
(4, 'Fase 3 — 12–18 semanas',     'Semanas 12–18: fuerza, inicio de impacto y running.',                                  4),
(5, 'Fase 4 — 18–24 semanas',     'Semanas 18–24: cambio de dirección y deporte específico inicial.',                     5),
(6, 'Fase 5 — 24–30 semanas',     'Semanas 24–30: alto rendimiento y vuelta al deporte.',                                 6)
ON CONFLICT (id) DO NOTHING;

INSERT INTO phase_requirements (phase_id, description, requirement_type, days_threshold, event_key, order_index) VALUES
-- Fase 0 — Pre-operatorio
(1, 'Extensión completa de rodilla',      'manual', NULL, NULL, 1),
(1, 'Flexión de rodilla >120°',           'manual', NULL, NULL, 2),
(1, 'Inflamación mínima',                 'manual', NULL, NULL, 3),
(1, 'Sin lag de cuádriceps',              'manual', NULL, NULL, 4),
(1, 'Marcha normal',                      'manual', NULL, NULL, 5),

-- Fase 1 — 0–6 semanas
(2, 'Extensión completa de rodilla',      'manual', NULL, NULL, 1),
(2, 'Flexión progresiva >120°',           'manual', NULL, NULL, 2),
(2, 'Disminución de inflamación',         'manual', NULL, NULL, 3),
(2, 'Activación de cuádriceps',           'manual', NULL, NULL, 4),
(2, 'Marcha sin muletas',                 'manual', NULL, NULL, 5),

-- Fase 2 — 6–12 semanas
(3, 'Extensión completa de rodilla',      'manual', NULL, NULL, 1),
(3, 'Flexión ≥130°',                      'manual', NULL, NULL, 2),
(3, '15 sentadillas unilaterales a 90° (SL squat)', 'manual', NULL, NULL, 3),
(3, '20 sentadillas bilaterales a >90° (DL squat)', 'manual', NULL, NULL, 4),
(3, 'Inicio de saltos sin dolor',         'manual', NULL, NULL, 5),

-- Fase 3 — 12–18 semanas (criterios para correr)
(4, 'Al menos 12 semanas desde la cirugía (84 días)', 'time_based', 84, 'surgery_date', 1),
(4, 'Sin inflamación articular',                      'manual', NULL, NULL, 2),
(4, 'ROM completo (extensión total + flexión ≥135°)', 'manual', NULL, NULL, 3),
(4, 'Dolor 0/10 en reposo y actividad',               'manual', NULL, NULL, 4),
(4, '30 pogos unipodales correctos',                  'manual', NULL, NULL, 5),
(4, 'LSI cuádriceps >70%',                            'manual', NULL, NULL, 6),
(4, 'IKDC >64%',                                      'manual', NULL, NULL, 7),

-- Fase 4 — 18–24 semanas (criterios COD / deporte)
(5, 'SL squat a 90° con técnica correcta',  'manual', NULL, NULL, 1),
(5, 'Saltos multidireccionales correctos',  'manual', NULL, NULL, 2),
(5, 'Protocolo de running completado',      'manual', NULL, NULL, 3),
(5, 'Fuerza >80% LSI',                      'manual', NULL, NULL, 4),
(5, 'Saltos >80% LSI',                      'manual', NULL, NULL, 5),
(5, 'RSI >80%',                             'manual', NULL, NULL, 6),

-- Fase 5 — 24–30 semanas (criterios de vuelta al deporte)
(6, 'Cuádriceps >90% LSI',                            'manual', NULL, NULL, 1),
(6, 'Isquiotibiales >90% LSI',                        'manual', NULL, NULL, 2),
(6, 'CMJ >90% respecto al lado contralateral',        'manual', NULL, NULL, 3),
(6, 'Hop test >90%',                                  'manual', NULL, NULL, 4),
(6, 'SL squat perfecto (técnica y control)',           'manual', NULL, NULL, 5),
(6, 'Mecánica simétrica en running y COD',            'manual', NULL, NULL, 6)
ON CONFLICT (phase_id, order_index) DO NOTHING;

-- ============================================================
-- MIGRATION — new patient profile columns
-- Run once in the Supabase SQL editor.
-- ============================================================
ALTER TABLE patients ADD COLUMN IF NOT EXISTS gender             TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS previous_injuries  TEXT;
ALTER TABLE patients ADD COLUMN IF NOT EXISTS sports_practiced   TEXT;

-- ============================================================
-- ROW-LEVEL SECURITY (opcional — recomendado si se añade auth)
-- ============================================================
-- ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "auth users only" ON patients FOR ALL TO authenticated USING (true);
-- (Repetir para cada tabla)