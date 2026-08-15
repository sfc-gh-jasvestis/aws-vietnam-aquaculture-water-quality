-- ============================================================================
-- Water Quality Monitoring
-- Water Quality Monitoring for Vietnam - ML.FORECAST and Dynamic Tables power real-time water quality monitoring intelligence for aquaculture & seafood in Can Tho & Ca Mau.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS AQUACULTURE_WATER;
CREATE WAREHOUSE IF NOT EXISTS AQUACULTURE_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE AQUACULTURE_WATER;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE AQUACULTURE_WH;
