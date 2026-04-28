-- SafePass v2: Corridor Edition Schema
-- Run this in your Supabase SQL Editor

DROP TABLE IF EXISTS public.user_reports CASCADE;

CREATE TABLE public.user_reports (
  id          uuid    DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at  timestamptz DEFAULT timezone('utc', now()) NOT NULL,
  user_id     text    NOT NULL,
  location    text    NOT NULL CHECK (location IN ('mumbai', 'khopoli', 'lonavala', 'pune')),
  rainfall    text    NOT NULL CHECK (rainfall IN ('No Rainfall', 'Low Rainfall', 'Medium', 'High', 'Very High')),
  visibility  text    NOT NULL CHECK (visibility IN ('Clear', 'Low')),
  temperature text    NOT NULL CHECK (temperature IN ('Low', 'High', 'Very High'))
);

CREATE INDEX IF NOT EXISTS idx_reports_location_time
  ON public.user_reports (location, created_at DESC);

ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anonymous inserts" ON public.user_reports
  FOR INSERT TO public WITH CHECK (true);

CREATE POLICY "Allow public read access" ON public.user_reports
  FOR SELECT TO public USING (true);
