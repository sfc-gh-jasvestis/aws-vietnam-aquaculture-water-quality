-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Water Quality Monitoring
-- ============================================================================
USE DATABASE AQUACULTURE_WATER;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.AQUACULTURE_WATER_AGENT
  COMMENT = 'Water Quality Monitoring AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'AQUACULTURE_WATER.APP.AQUACULTURE_WATER_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'AQUACULTURE_WATER.SEARCH.AQUACULTURE_WATER_SEARCH', TOOL_DESCRIPTION => 'Search documents for Aquaculture & Seafood information')
  )
  SYSTEM_PROMPT = 'You are the Water Quality Monitoring Agent for Vietnamese aquaculture & seafood operations in Can Tho & Ca Mau.';
