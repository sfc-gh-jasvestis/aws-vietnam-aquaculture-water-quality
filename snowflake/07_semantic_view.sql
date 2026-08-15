-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Water Quality Monitoring
-- ============================================================================
USE DATABASE AQUACULTURE_WATER;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.AQUACULTURE_WATER_ANALYTICS
  COMMENT = 'Aquaculture & Seafood water quality monitoring analytics'
AS
  TABLES (
    CURATED.PERFORMANCE_DASHBOARD AS performance_dashboard,CURATED.TREND_ANALYTICS AS trend_analytics,CURATED.FORECAST_INPUT AS forecast_input,CURATED.OPERATIONAL_RISK AS operational_risk
  );
