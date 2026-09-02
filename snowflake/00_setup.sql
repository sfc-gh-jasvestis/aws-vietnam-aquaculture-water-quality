-- Generated from generator/demo_specs/aws-vietnam-aquaculture-water-quality.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-vietnam-aquaculture-water-quality
-- This is the schema that is actually deployed for VIETNAM_AQUACULTURE_WATER_QUALITY.

-- VIETNAM_AQUACULTURE_WATER_QUALITY  (Water Quality Monitoring)
-- generated from generator/demo_specs/aws-vietnam-aquaculture-water-quality.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS VIETNAM_AQUACULTURE_WATER_QUALITY;
CREATE SCHEMA IF NOT EXISTS VIETNAM_AQUACULTURE_WATER_QUALITY.RAW;
CREATE SCHEMA IF NOT EXISTS VIETNAM_AQUACULTURE_WATER_QUALITY.CURATED;
CREATE SCHEMA IF NOT EXISTS VIETNAM_AQUACULTURE_WATER_QUALITY.APP;
USE DATABASE VIETNAM_AQUACULTURE_WATER_QUALITY;

-- 5 real regions; entity names carry their region so the two always agree
