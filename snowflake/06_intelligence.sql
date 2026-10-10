-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-telemetry alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_TELEMETRY.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic pond water quality knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.FARM_SOP_DOCS AS
WITH causes AS (
  SELECT DISTINCT r.ROOT_CAUSE, h.CATEGORY
  FROM RAW.FARM_DAILY r JOIN RAW.FARMS h ON h.ID = r.ENTITY_ID
  WHERE r.ROOT_CAUSE IS NOT NULL AND r.WQ_EVENT_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, ROOT_CAUSE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  ROOT_CAUSE,
  CATEGORY || ' - ' || ROOT_CAUSE || ' water quality response' AS TITLE,
  'Synthetic demo SOP. Farm type: ' || CATEGORY || '. Water quality event cause: ' || ROOT_CAUSE || '. '
  || 'Step 1: notify the farm shift technician, log the pond IDs affected, take a handheld reading of dissolved oxygen, pH, temperature and salinity to confirm the probe values, and pause feeding in those ponds. '
  || 'Step 2: ' || CASE
       WHEN ROOT_CAUSE ILIKE '%oxygen%' OR ROOT_CAUSE ILIKE '%aerator%' OR ROOT_CAUSE ILIKE '%blower%' THEN 'start the standby aerators or blowers from the readiness pool, run aeration continuously until dissolved oxygen recovers and log the failed unit for inspection.'
       WHEN ROOT_CAUSE ILIKE '%ammonia%' OR ROOT_CAUSE ILIKE '%nitrite%' OR ROOT_CAUSE ILIKE '%biofilter%' OR ROOT_CAUSE ILIKE '%sludge%' THEN 'reduce the feed ration, exchange water from the treated reservoir in small steps and siphon or flush accumulated sludge before restoring the ration.'
       WHEN ROOT_CAUSE ILIKE '%algae%' OR ROOT_CAUSE ILIKE '%ph%' THEN 'increase aeration overnight, re-check pH at dawn and dusk and stabilise alkalinity with a measured liming dose recorded in the pond log.'
       WHEN ROOT_CAUSE ILIKE '%saline%' OR ROOT_CAUSE ILIKE '%power%' THEN 'close intake gates, start backup generation where fitted, prioritise aeration for the most heavily stocked ponds and record salinity hourly until conditions stabilise.'
       WHEN ROOT_CAUSE ILIKE '%heater%' OR ROOT_CAUSE ILIKE '%turbidity%' THEN 'switch to the standby heater or settled seawater reserve, hold new stocking into affected tanks and record temperature and turbidity every two hours.'
       WHEN ROOT_CAUSE ILIKE '%probe%' THEN 'recalibrate the probe against a handheld meter, flag readings since the last good calibration for review and replace the sensor if drift persists.'
       ELSE 'record the issue, contain the affected ponds and escalate to the regional aquaculture lead.'
     END
  || ' Step 3: if total ammonia stays above 1.2 mg/L or aerator load stays above 92% after recovery, keep the farm on the watch list and defer new stocking. '
  || 'Step 4: confirm recovery of the in-band rate and record the root cause and pond IDs in the water quality log.' AS CONTENT
FROM causes;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.FARM_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, ROOT_CAUSE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, ROOT_CAUSE, CONTENT FROM SEARCH.FARM_SOP_DOCS);

-- ---------- Total ammonia anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.AMMONIA_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, AMMONIA_MG_L::FLOAT AS AMMONIA
FROM RAW.FARM_DAILY;
CREATE OR REPLACE VIEW ML.AMMONIA_TRAIN AS
SELECT * FROM ML.AMMONIA_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.AMMONIA_SERIES);
CREATE OR REPLACE VIEW ML.AMMONIA_DETECT AS
SELECT * FROM ML.AMMONIA_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.AMMONIA_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.AMMONIA_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.AMMONIA_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'AMMONIA',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.AMMONIA_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS AMMONIA, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.AMMONIA_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.AMMONIA_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'AMMONIA'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.WATER_QUALITY_ANALYTICS
  TABLES (
    farms AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'farms', 'aquaculture farms', 'grow-out sites', 'hatcheries')
      COMMENT = 'One row per aquaculture farm (entity), 90-day totals',
    risk AS ML.WQ_EVENT_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day water quality event probability per farm',
    causes AS CURATED.WQ_EVENT_CAUSES PRIMARY KEY (ROOT_CAUSE)
      COMMENT = 'Water quality events by root cause, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_farm AS risk (ENTITY_ID) REFERENCES farms)
  FACTS (
    farms.in_band_f AS IN_BAND_READINGS,
    farms.readings_f AS PROBE_READINGS,
    farms.checks_f AS PARAMETER_CHECKS,
    farms.alarms_f AS ALARM_CHECKS,
    farms.wq_events_f AS WQ_EVENT_COUNT,
    farms.downtime_hours_f AS DOWNTIME_HOURS,
    farms.operating_hours_f AS OPERATING_HOURS,
    farms.planned_hours_f AS PLANNED_HOURS,
    risk.wq_event_prob_f AS WQ_EVENT_PROB_7D,
    causes.cause_wq_events_f AS WQ_EVENT_COUNT,
    causes.cause_out_of_band_f AS OUT_OF_BAND_READINGS,
    causes.cause_hours_f AS DOWNTIME_HOURS,
    daily.day_in_band_f AS IN_BAND_READINGS,
    daily.day_readings_f AS PROBE_READINGS,
    daily.day_wq_events_f AS WQ_EVENT_COUNT
  )
  DIMENSIONS (
    farms.farm_id AS ENTITY_ID WITH SYNONYMS = ('farm', 'entity', 'entity id', 'farm code'),
    farms.farm_name AS ENTITY_NAME,
    farms.region AS REGION WITH SYNONYMS = ('region', 'city', 'province', 'farming hub') COMMENT = 'Vietnam city',
    farms.farm_type AS CATEGORY WITH SYNONYMS = ('farm type', 'pond type', 'category'),
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    causes.root_cause AS ROOT_CAUSE,
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    farms.farm_count AS COUNT(farms.farm_id) WITH SYNONYMS = ('number of entities', 'entity count', 'number of farms'),
    farms.in_band_reading_pct AS 100 * SUM(farms.in_band_f) / NULLIF(SUM(farms.readings_f), 0)
      WITH SYNONYMS = ('in-band rate', 'water quality compliance') COMMENT = 'In-band probe readings / probe readings',
    farms.total_wq_events AS SUM(farms.wq_events_f) WITH SYNONYMS = ('water quality events', 'pond events'),
    farms.alarm_checks_per_1k AS 1000 * SUM(farms.alarms_f) / NULLIF(SUM(farms.checks_f), 0),
    farms.total_probe_readings AS SUM(farms.readings_f) WITH SYNONYMS = ('reading volume', 'probe readings'),
    farms.total_parameter_checks AS SUM(farms.checks_f),
    farms.aeration_uptime_rate AS 100 * SUM(farms.operating_hours_f) / NULLIF(SUM(farms.planned_hours_f), 0),
    farms.total_downtime_hours AS SUM(farms.downtime_hours_f),
    risk.avg_wq_event_prob AS AVG(risk.wq_event_prob_f),
    causes.cause_wq_events AS SUM(causes.cause_wq_events_f),
    causes.cause_out_of_band_readings AS SUM(causes.cause_out_of_band_f),
    causes.cause_downtime_hours AS SUM(causes.cause_hours_f),
    daily.daily_in_band_pct AS 100 * SUM(daily.day_in_band_f) / NULLIF(SUM(daily.day_readings_f), 0),
    daily.daily_probe_readings AS SUM(daily.day_readings_f),
    daily.daily_wq_events AS SUM(daily.day_wq_events_f)
  )
  COMMENT = 'Synthetic Vietnam aquaculture water quality analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.WATER_QUALITY_AGENT
  COMMENT = 'Water quality assistant over a synthetic Vietnam aquaculture farm network'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give farm IDs and numbers with units."
  orchestration: "Use water_quality_analyst for in-band probe readings, water quality events, parameter alarms, reading volume, farms, regions, risk and root causes. Use sop_search for water quality response procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: water_quality_analyst
      description: "In-band probe readings, water quality events, alarms per 1,000 parameter checks, probe-reading volume, aeration uptime, root causes and event-risk scores per farm"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic water quality response SOPs by farm type and cause"
tool_resources:
  water_quality_analyst:
    semantic_view: __DEMO_DB__.APP.WATER_QUALITY_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.FARM_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-telemetry alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), FARM_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMMONIA_MG_L FLOAT, AERATOR_LOAD_PCT FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION VN_AQUACULTURE_WATER_QUALITY_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALARMS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (FARM_ID, EVENT_TS, AMMONIA_MG_L, AERATOR_LOAD_PCT, SOP_HINT)
    SELECT t.FARM_ID, t.EVENT_TS, t.AMMONIA_MG_L, t.AERATOR_LOAD_PCT,
           'Check ' || h.CATEGORY || ' SOPs; current risk band ' || COALESCE(r.RISK_BAND, 'n/a')
    FROM RAW.LIVE_TELEMETRY t
    JOIN RAW.FARMS h ON h.ID = t.FARM_ID
    LEFT JOIN ML.WQ_EVENT_RISK_SCORES r ON r.ENTITY_ID = t.FARM_ID
    WHERE t.STATUS = 'ALARM'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.FARM_ID = t.FARM_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('VN_AQUACULTURE_WATER_QUALITY_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Vietnam aquaculture farm water quality alarm',
      'New live-telemetry alarms logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_ALARM_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_TELEMETRY t
    WHERE t.STATUS = 'ALARM'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.FARM_ID = t.FARM_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALARMS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.WQ_EVENT_CAUSES REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.WQ_EVENT_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.WQ_EVENT_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.WQ_EVENT_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'AGE_YEARS', AGE_YEARS, 'AMMONIA_MG_L', AMMONIA_MG_L,
             'AERATOR_LOAD_PCT', AERATOR_LOAD_PCT, 'AMMONIA_7D', AMMONIA_7D, 'WQ_EVENTS_30D', WQ_EVENTS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:WQ_EVENT::FLOAT, 4) AS WQ_EVENT_PROB_7D,
         CASE WHEN PRED:probability:WQ_EVENT::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:WQ_EVENT::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
