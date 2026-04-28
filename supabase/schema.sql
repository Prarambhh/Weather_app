-- ============================================================
-- SafePass MVP — Supabase Database Schema
-- ============================================================
-- Run this in: Supabase Dashboard → SQL Editor → New Query → Run
-- ============================================================

-- 1. Enable the pgcrypto extension (needed for gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Create the hazard type enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'hazard_type_enum') THEN
        CREATE TYPE hazard_type_enum AS ENUM (
            'waterlogging',
            'smog',
            'standstill',
            'clear'
        );
    END IF;
END$$;

-- 3. Create the user_reports table
CREATE TABLE IF NOT EXISTS user_reports (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     TEXT        NOT NULL,
    hazard_type TEXT        NOT NULL
                            CHECK (hazard_type IN ('waterlogging', 'smog', 'standstill', 'clear')),
    location    TEXT        NOT NULL DEFAULT 'mumbai',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Index for the Trust Engine query (filters by location + created_at)
CREATE INDEX IF NOT EXISTS idx_user_reports_location_time
    ON user_reports (location, created_at DESC);

-- 5. Row Level Security — open for MVP (lock down in production)
ALTER TABLE user_reports ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts from the app
CREATE POLICY "Allow anonymous inserts"
    ON user_reports
    FOR INSERT
    WITH CHECK (true);

-- Allow the backend service role to read all rows
CREATE POLICY "Allow service role reads"
    ON user_reports
    FOR SELECT
    USING (true);

-- ============================================================
-- Optional: seed a few test records to verify the Trust Engine
-- ============================================================
-- INSERT INTO user_reports (user_id, hazard_type, location)
-- VALUES
--   ('test-device-001', 'waterlogging', 'mumbai'),
--   ('test-device-002', 'waterlogging', 'mumbai'),
--   ('test-device-003', 'standstill',   'mumbai');
