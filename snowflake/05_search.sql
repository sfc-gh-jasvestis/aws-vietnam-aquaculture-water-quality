-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Water Quality Monitoring
-- ============================================================================
USE DATABASE AQUACULTURE_WATER;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.AQUACULTURE_WATER_SEARCH
  ON CONTENT
  ATTRIBUTES DOC_TYPE, CATEGORY
  WAREHOUSE = AQUACULTURE_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.DOCUMENTS
);
