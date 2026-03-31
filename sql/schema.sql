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

-- ============================================================
-- SEED DATA — 8 fases y sus requisitos (en español)
-- ============================================================

INSERT INTO phases (id, name, description, order_index) VALUES
(1, 'Fase 1 — Post-op inmediato',        'Días 0–3: Estabilización y control del dolor.',                     1),
(2, 'Fase 2 — Recuperación temprana',    'Días 4–14: Monitorización de la herida y movilidad básica.',        2),
(3, 'Fase 3 — Cicatrización',            'Días 15–30: Cierre de la herida y vigilancia de infecciones.',      3),
(4, 'Fase 4 — Restauración de movilidad','Días 31–60: Recuperación del rango de movimiento.',                 4),
(5, 'Fase 5 — Fortalecimiento',          'Días 61–90: Ejercicios de resistencia progresiva.',                 5),
(6, 'Fase 6 — Entrenamiento funcional',  'Días 91–120: Ejercicios funcionales específicos de la actividad.',  6),
(7, 'Fase 7 — Retorno a la actividad',   'Días 121–150: Reincorporación gradual a las actividades normales.', 7),
(8, 'Fase 8 — Recuperación completa',    'Días 151+: Planificación del alta y seguimiento a largo plazo.',    8)
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
(5, 'Al menos 61 días desde la cirugía',                                'time_based', 61,  'surgery_date', 1),
(5, 'Fuerza ≥ 50% del lado contralateral',                              'manual',     NULL, NULL,          2),
(5, 'Sin inflamación ni derrame en reposo',                             'manual',     NULL, NULL,          3),
(5, 'Paciente gestiona de forma autónoma el plan de ejercicios en casa','manual',     NULL, NULL,          4),

-- Fase 6
(6, 'Al menos 91 días desde la cirugía',                                'time_based', 91,  'surgery_date', 1),
(6, 'Puntuación del test de movimiento funcional ≥ 14',                 'manual',     NULL, NULL,          2),
(6, 'Sin dolor en las tareas funcionales diarias',                      'manual',     NULL, NULL,          3),
(6, 'Pruebas de equilibrio y propiocepción dentro de la normalidad',    'manual',     NULL, NULL,          4),

-- Fase 7
(7, 'Al menos 121 días desde la cirugía',                'time_based', 121, 'surgery_date', 1),
(7, 'Autorizado para deporte/actividad de bajo impacto', 'manual',     NULL, NULL,           2),
(7, 'Fuerza ≥ 80% del lado contralateral',               'manual',     NULL, NULL,           3),
(7, 'Disposición psicológica confirmada',                'manual',     NULL, NULL,           4),

-- Fase 8
(8, 'Al menos 151 días desde la cirugía',                                  'time_based', 151, 'surgery_date', 1),
(8, 'Retorno completo al nivel de actividad previo a la lesión',           'manual',     NULL, NULL,          2),
(8, 'Educación al paciente sobre prevención de lesiones completada',       'manual',     NULL, NULL,          3),
(8, 'Carta de alta / plan de seguimiento documentado',                     'manual',     NULL, NULL,          4)
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