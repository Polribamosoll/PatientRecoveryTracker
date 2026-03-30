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
(1, 'Fase 1 — Post-op inmediato',       'Días 0–3: Estabilización y control del dolor.',                    1),
(2, 'Fase 2 — Recuperación temprana',   'Días 4–14: Monitorización de la herida y movilidad básica.',       2),
(3, 'Fase 3 — Cicatrización',           'Días 15–30: Cierre de la herida y vigilancia de infecciones.',     3),
(4, 'Fase 4 — Restauración de movilidad','Días 31–60: Recuperación del rango de movimiento.',               4),
(5, 'Fase 5 — Fortalecimiento',         'Días 61–90: Ejercicios de resistencia progresiva.',                5),
(6, 'Fase 6 — Entrenamiento funcional', 'Días 91–120: Ejercicios funcionales específicos de la actividad.', 6),
(7, 'Fase 7 — Retorno a la actividad',  'Días 121–150: Reincorporación gradual a las actividades normales.',7),
(8, 'Fase 8 — Recuperación completa',   'Días 151+: Planificación del alta y seguimiento a largo plazo.',   8)
ON CONFLICT (id) DO NOTHING;

INSERT INTO phase_requirements (phase_id, description, requirement_type, days_threshold, event_key, order_index) VALUES
-- Fase 1
(1, 'Constantes vitales estables (TA, FC, SpO₂ en rango normal)', 'manual',     NULL, NULL,           1),
(1, 'Puntuación de dolor ≤ 6 en la ENR',                          'manual',     NULL, NULL,           2),
(1, 'Sin signos de complicación quirúrgica inmediata',             'manual',     NULL, NULL,           3),
(1, 'El paciente tolera líquidos por vía oral',                    'manual',     NULL, NULL,           4),

-- Fase 2
(2, 'Al menos 4 días desde la cirugía',                            'time_based', 4,    'surgery_date', 1),
(2, 'Herida revisada — sin signos de infección',                   'manual',     NULL, NULL,           2),
(2, 'Puntuación de dolor ≤ 4 en la ENR',                          'manual',     NULL, NULL,           3),
(2, 'Paciente deambula con asistencia',                            'manual',     NULL, NULL,           4),

-- Fase 3
(3, 'Al menos 15 días desde la cirugía',                           'time_based', 15,   'surgery_date', 1),
(3, 'Herida completamente cerrada o con buena evolución',          'manual',     NULL, NULL,           2),
(3, 'Puntos/grapas retirados o programados',                       'manual',     NULL, NULL,           3),
(3, 'Paciente tolera alimentación sólida',                         'manual',     NULL, NULL,           4),

-- Fase 4
(4, 'Al menos 31 días desde la cirugía',                           'time_based', 31,   'surgery_date', 1),
(4, 'ROM mejorado ≥ 20° respecto al nivel post-op inicial',        'manual',     NULL, NULL,           2),
(4, 'Capaz de caminar 100 m sin dolor significativo',              'manual',     NULL, NULL,           3),
(4, 'Sesiones de fisioterapia iniciadas',                          'manual',     NULL, NULL,           4),

-- Fase 5
(5, 'Al menos 61 días desde la cirugía',                           'time_based', 61,   'surgery_date', 1),
(5, 'Fuerza ≥ 50% del lado contralateral',                         'manual',     NULL, NULL,           2),
(5, 'Sin inflamación ni derrame en reposo',                        'manual',     NULL, NULL,           3),
(5, 'Paciente gestiona de forma autónoma el plan de ejercicios en casa', 'manual', NULL, NULL,         4),

-- Fase 6
(6, 'Al menos 91 días desde la cirugía',                           'time_based', 91,   'surgery_date', 1),
(6, 'Puntuación del test de movimiento funcional ≥ 14',            'manual',     NULL, NULL,           2),
(6, 'Sin dolor en las tareas funcionales diarias',                 'manual',     NULL, NULL,           3),
(6, 'Pruebas de equilibrio y propiocepción dentro de la normalidad','manual',    NULL, NULL,           4),

-- Fase 7
(7, 'Al menos 121 días desde la cirugía',                          'time_based', 121,  'surgery_date', 1),
(7, 'Autorizado para deporte/actividad de bajo impacto',           'manual',     NULL, NULL,           2),
(7, 'Fuerza ≥ 80% del lado contralateral',                         'manual',     NULL, NULL,           3),
(7, 'Disposición psicológica confirmada',                          'manual',     NULL, NULL,           4),

-- Fase 8
(8, 'Al menos 151 días desde la cirugía',                          'time_based', 151,  'surgery_date', 1),
(8, 'Retorno completo al nivel de actividad previo a la lesión',   'manual',     NULL, NULL,           2),
(8, 'Educación al paciente sobre prevención de lesiones completada','manual',    NULL, NULL,           3),
(8, 'Carta de alta / plan de seguimiento documentado',             'manual',     NULL, NULL,           4);

-- ============================================================
-- TRADUCCIÓN AL ESPAÑOL — ejecutar en Supabase SQL editor si la
-- base de datos ya existe con los datos en inglés.
-- ============================================================

-- Fases
UPDATE phases SET name = 'Fase 1 — Post-op inmediato',        description = 'Días 0–3: Estabilización y control del dolor.'                     WHERE id = 1;
UPDATE phases SET name = 'Fase 2 — Recuperación temprana',    description = 'Días 4–14: Monitorización de la herida y movilidad básica.'          WHERE id = 2;
UPDATE phases SET name = 'Fase 3 — Cicatrización',            description = 'Días 15–30: Cierre de la herida y vigilancia de infecciones.'        WHERE id = 3;
UPDATE phases SET name = 'Fase 4 — Restauración de movilidad',description = 'Días 31–60: Recuperación del rango de movimiento.'                   WHERE id = 4;
UPDATE phases SET name = 'Fase 5 — Fortalecimiento',          description = 'Días 61–90: Ejercicios de resistencia progresiva.'                   WHERE id = 5;
UPDATE phases SET name = 'Fase 6 — Entrenamiento funcional',  description = 'Días 91–120: Ejercicios funcionales específicos de la actividad.'    WHERE id = 6;
UPDATE phases SET name = 'Fase 7 — Retorno a la actividad',   description = 'Días 121–150: Reincorporación gradual a las actividades normales.'   WHERE id = 7;
UPDATE phases SET name = 'Fase 8 — Recuperación completa',    description = 'Días 151+: Planificación del alta y seguimiento a largo plazo.'      WHERE id = 8;

-- Requisitos — Fase 1
UPDATE phase_requirements SET description = 'Constantes vitales estables (TA, FC, SpO₂ en rango normal)' WHERE phase_id = 1 AND order_index = 1;
UPDATE phase_requirements SET description = 'Puntuación de dolor ≤ 6 en la ENR'                          WHERE phase_id = 1 AND order_index = 2;
UPDATE phase_requirements SET description = 'Sin signos de complicación quirúrgica inmediata'             WHERE phase_id = 1 AND order_index = 3;
UPDATE phase_requirements SET description = 'El paciente tolera líquidos por vía oral'                    WHERE phase_id = 1 AND order_index = 4;

-- Requisitos — Fase 2
UPDATE phase_requirements SET description = 'Al menos 4 días desde la cirugía'          WHERE phase_id = 2 AND order_index = 1;
UPDATE phase_requirements SET description = 'Herida revisada — sin signos de infección'  WHERE phase_id = 2 AND order_index = 2;
UPDATE phase_requirements SET description = 'Puntuación de dolor ≤ 4 en la ENR'         WHERE phase_id = 2 AND order_index = 3;
UPDATE phase_requirements SET description = 'Paciente deambula con asistencia'           WHERE phase_id = 2 AND order_index = 4;

-- Requisitos — Fase 3
UPDATE phase_requirements SET description = 'Al menos 15 días desde la cirugía'                         WHERE phase_id = 3 AND order_index = 1;
UPDATE phase_requirements SET description = 'Herida completamente cerrada o con buena evolución'         WHERE phase_id = 3 AND order_index = 2;
UPDATE phase_requirements SET description = 'Puntos/grapas retirados o programados'                      WHERE phase_id = 3 AND order_index = 3;
UPDATE phase_requirements SET description = 'Paciente tolera alimentación sólida'                         WHERE phase_id = 3 AND order_index = 4;

-- Requisitos — Fase 4
UPDATE phase_requirements SET description = 'Al menos 31 días desde la cirugía'                      WHERE phase_id = 4 AND order_index = 1;
UPDATE phase_requirements SET description = 'ROM mejorado ≥ 20° respecto al nivel post-op inicial'   WHERE phase_id = 4 AND order_index = 2;
UPDATE phase_requirements SET description = 'Capaz de caminar 100 m sin dolor significativo'         WHERE phase_id = 4 AND order_index = 3;
UPDATE phase_requirements SET description = 'Sesiones de fisioterapia iniciadas'                      WHERE phase_id = 4 AND order_index = 4;

-- Requisitos — Fase 5
UPDATE phase_requirements SET description = 'Al menos 61 días desde la cirugía'                                   WHERE phase_id = 5 AND order_index = 1;
UPDATE phase_requirements SET description = 'Fuerza ≥ 50% del lado contralateral'                                 WHERE phase_id = 5 AND order_index = 2;
UPDATE phase_requirements SET description = 'Sin inflamación ni derrame en reposo'                                 WHERE phase_id = 5 AND order_index = 3;
UPDATE phase_requirements SET description = 'Paciente gestiona de forma autónoma el plan de ejercicios en casa'   WHERE phase_id = 5 AND order_index = 4;

-- Requisitos — Fase 6
UPDATE phase_requirements SET description = 'Al menos 91 días desde la cirugía'                                    WHERE phase_id = 6 AND order_index = 1;
UPDATE phase_requirements SET description = 'Puntuación del test de movimiento funcional ≥ 14'                     WHERE phase_id = 6 AND order_index = 2;
UPDATE phase_requirements SET description = 'Sin dolor en las tareas funcionales diarias'                          WHERE phase_id = 6 AND order_index = 3;
UPDATE phase_requirements SET description = 'Pruebas de equilibrio y propiocepción dentro de la normalidad'        WHERE phase_id = 6 AND order_index = 4;

-- Requisitos — Fase 7
UPDATE phase_requirements SET description = 'Al menos 121 días desde la cirugía'                WHERE phase_id = 7 AND order_index = 1;
UPDATE phase_requirements SET description = 'Autorizado para deporte/actividad de bajo impacto' WHERE phase_id = 7 AND order_index = 2;
UPDATE phase_requirements SET description = 'Fuerza ≥ 80% del lado contralateral'              WHERE phase_id = 7 AND order_index = 3;
UPDATE phase_requirements SET description = 'Disposición psicológica confirmada'                WHERE phase_id = 7 AND order_index = 4;

-- Requisitos — Fase 8
UPDATE phase_requirements SET description = 'Al menos 151 días desde la cirugía'                                   WHERE phase_id = 8 AND order_index = 1;
UPDATE phase_requirements SET description = 'Retorno completo al nivel de actividad previo a la lesión'            WHERE phase_id = 8 AND order_index = 2;
UPDATE phase_requirements SET description = 'Educación al paciente sobre prevención de lesiones completada'        WHERE phase_id = 8 AND order_index = 3;
UPDATE phase_requirements SET description = 'Carta de alta / plan de seguimiento documentado'                      WHERE phase_id = 8 AND order_index = 4;

-- ============================================================
-- ROW-LEVEL SECURITY (optional but recommended)
-- Enable RLS on all tables and restrict to authenticated users.
-- In Supabase: Authentication → Policies.
-- Quick setup for single-user app — allow all for authenticated:
-- ============================================================
-- ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "auth users only" ON patients FOR ALL TO authenticated USING (true);
-- (Repeat for each table if you enable Supabase Auth)
