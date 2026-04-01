-- Migration: add has_extension flag to patient_phase_progress
--            and extend week_number constraint to allow weeks 7–8 (prórroga)
-- Run once against your Supabase project.

ALTER TABLE patient_phase_progress
  ADD COLUMN IF NOT EXISTS has_extension BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE patient_weekly_checks
  DROP CONSTRAINT IF EXISTS patient_weekly_checks_week_number_check;

ALTER TABLE patient_weekly_checks
  ADD CONSTRAINT patient_weekly_checks_week_number_check
    CHECK (week_number BETWEEN 1 AND 8);
