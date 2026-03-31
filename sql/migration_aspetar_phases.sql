-- ============================================================
-- MIGRACIÓN: Reemplazar fases genéricas por protocolo Aspetar
-- Ejecutar UNA sola vez en el SQL Editor de Supabase.
-- ============================================================

-- PASO 0: Crear tabla de seguimiento semanal (si no existe)
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

-- PASO 1: Borrar progreso de requisitos y checks semanales (los IDs de requisitos cambian)
DELETE FROM patient_weekly_checks;
DELETE FROM patient_requirement_progress;

-- PASO 2: Borrar todos los requisitos actuales
DELETE FROM phase_requirements;

-- PASO 3: Mover pacientes en fases 7 u 8 (ya no existen) a la fase 6
UPDATE patients
SET current_phase_id = 6
WHERE current_phase_id > 6;

-- PASO 4: Actualizar el historial de fases (completar filas abiertas > 6)
UPDATE patient_phase_progress
SET completed_at = NOW()
WHERE phase_id > 6 AND completed_at IS NULL;

DELETE FROM patient_phase_progress
WHERE phase_id > 6;

-- PASO 5: Borrar las fases 7 y 8
DELETE FROM phases WHERE id > 6;

-- PASO 6: Actualizar nombres y descripciones de las fases 1–6
UPDATE phases SET
    name        = 'Fase 0 — Pre-operatorio',
    description = 'Antes de la cirugía: criterios de entrada para operar.',
    order_index = 1
WHERE id = 1;

UPDATE phases SET
    name        = 'Fase 1 — 0–6 semanas',
    description = 'Semanas 0–6: protección, recuperación de ROM y activación muscular.',
    order_index = 2
WHERE id = 2;

UPDATE phases SET
    name        = 'Fase 2 — 6–12 semanas',
    description = 'Semanas 6–12: fuerza básica y control motor.',
    order_index = 3
WHERE id = 3;

UPDATE phases SET
    name        = 'Fase 3 — 12–18 semanas',
    description = 'Semanas 12–18: fuerza, inicio de impacto y running.',
    order_index = 4
WHERE id = 4;

UPDATE phases SET
    name        = 'Fase 4 — 18–24 semanas',
    description = 'Semanas 18–24: cambio de dirección y deporte específico inicial.',
    order_index = 5
WHERE id = 5;

UPDATE phases SET
    name        = 'Fase 5 — 24–30 semanas',
    description = 'Semanas 24–30: alto rendimiento y vuelta al deporte.',
    order_index = 6
WHERE id = 6;

-- PASO 7: Asegurarse de que cada paciente tiene una fila abierta en patient_phase_progress
-- (necesario para que advance_patient_phase pueda cerrarla al avanzar)
INSERT INTO patient_phase_progress (patient_id, phase_id, started_at)
SELECT p.id, p.current_phase_id, NOW()
FROM patients p
WHERE NOT EXISTS (
    SELECT 1 FROM patient_phase_progress pp
    WHERE pp.patient_id = p.id
      AND pp.phase_id   = p.current_phase_id
      AND pp.completed_at IS NULL
);

-- PASO 8: Insertar los nuevos requisitos
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
(6, 'Mecánica simétrica en running y COD',            'manual', NULL, NULL, 6);
