-- Synthetic farm-day water quality observations for a fictional Vietnam aquaculture group.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild is
-- reproducible: per-farm probe fleet size, pond infrastructure age and event propensity,
-- probe-reading volume from a weekly pond-cleaning day and a new-crop stocking peak, wear
-- between preventive-maintenance (PM) visits, farm-type-weighted water quality event
-- causes, and two regional events.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.FARMS AS
WITH farms AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS FARM_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 30))
), draws AS (
  SELECT FARM_INDEX,
         MOD(ABS(HASH(FARM_INDEX, 'vnaqwq-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(FARM_INDEX, 'vnaqwq-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(FARM_INDEX, 'vnaqwq-pm')), 1000000) / 1e6 AS U_PM,
         MOD(ABS(HASH(FARM_INDEX, 'vnaqwq-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(FARM_INDEX, 'vnaqwq-capacity')), 1000000) / 1e6 AS U_CAPACITY
  FROM farms
)
SELECT 'WQ-' || LPAD(FARM_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic aquaculture farm ' || LPAD(FARM_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (7 and 5 are coprime): every city and farm type is
       -- present, with Can Tho the largest farming hub.
       CASE MOD(FARM_INDEX, 7) WHEN 0 THEN 'Can Tho' WHEN 1 THEN 'Can Tho' WHEN 2 THEN 'Ca Mau'
            WHEN 3 THEN 'Bac Lieu' WHEN 4 THEN 'Soc Trang' WHEN 5 THEN 'Ben Tre'
            ELSE 'Rach Gia' END AS REGION,
       CASE MOD(FARM_INDEX, 5) WHEN 0 THEN 'Intensive Shrimp Pond' WHEN 1 THEN 'Super-Intensive Shrimp Raceway'
            WHEN 2 THEN 'Pangasius Pond' WHEN 3 THEN 'Shrimp Hatchery' ELSE 'Recirculating Nursery' END AS CATEGORY,
       FARM_INDEX,
       ROUND(1 + U_AGE * 14, 1) AS AGE_YEARS,
       -- Base daily event probability 0.7%-3.3%; ~15% of farms are chronic (x3).
       (0.007 + U_RATE * 0.026) * IFF(U_RATE > 0.85, 3, 1) AS BASE_WQ_EVENT_RATE,
       7 * (1 + FLOOR(U_PM * 3)) AS PM_INTERVAL_DAYS,
       0.52 + U_DISCIPLINE * 0.46 AS PM_COMPLETION_PROB,
       ROUND(CASE MOD(FARM_INDEX, 5) WHEN 0 THEN 540 WHEN 1 THEN 720 WHEN 2 THEN 390
                  WHEN 3 THEN 280 ELSE 330 END * (0.8 + U_CAPACITY * 0.4)) AS DAILY_CAPACITY,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.FARM_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), regional_events AS (
  -- Two city-wide events in the window.
  SELECT * FROM VALUES (24, 'Ben Tre', 'Saline intrusion', 8.0),
                       (58, 'Ca Mau', 'Grid power outage', 7.0)
    AS o(DAY_INDEX, REGION, EVENT_CAUSE, HOURS)
), base AS (
  SELECT h.ID AS ENTITY_ID, h.FARM_INDEX, h.CATEGORY, h.REGION, h.AGE_YEARS,
         h.BASE_WQ_EVENT_RATE, h.PM_INTERVAL_DAYS, h.PM_COMPLETION_PROB, h.DAILY_CAPACITY,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         24.0 AS PLANNED_HOURS,
         MOD(d.DAY_INDEX + h.FARM_INDEX * 3, h.PM_INTERVAL_DAYS) AS DAYS_SINCE_PM,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnaqwq-evt')), 1000000) / 1e6 AS U_EVT,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnaqwq-down')), 1000000) / 1e6 + 1e-6 AS U_DOWN,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnaqwq-cause')), 1000000) / 1e6 AS U_CAUSE,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnaqwq-pmdone')), 1000000) / 1e6 AS U_PMDONE,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnaqwq-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnaqwq-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(h.ID, d.DAY_INDEX, 'vnaqwq-hit')), 1000000) / 1e6 AS U_HIT,
         e.EVENT_CAUSE, e.HOURS AS EVENT_HOURS
  FROM RAW.FARMS h CROSS JOIN days d
  LEFT JOIN regional_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = h.REGION
), loaded AS (
  SELECT *,
         IFF(DAYS_SINCE_PM = 0, 1, 0) AS PM_DUE,
         IFF(DAYS_SINCE_PM = 0 AND U_PMDONE < PM_COMPLETION_PROB, 1, 0) AS PM_COMPLETED,
         -- Aerator and probe wear rises between PM visits; weak PM discipline carries wear over.
         DAYS_SINCE_PM / PM_INTERVAL_DAYS + (1 - PM_COMPLETION_PROB) AS WEAR,
         -- Hot-weather stratification episode: 7 of every 23 days per farm (staggered).
         IFF(MOD(DAY_INDEX + FARM_INDEX * 5, 23) < 7, 1, 0) AS STRESS,
         -- Volume: a weekly pond-cleaning day takes probes offline, and a new-crop stocking
         -- peak on day 47 (+36%) eases over 3 days.
         ROUND(DAILY_CAPACITY * (0.68 + 0.27 * U_VOLUME)
               * IFF(MOD(DAY_INDEX, 7) = 3, 0.78, 1.0)
               * CASE DAY_INDEX - 47 WHEN 0 THEN 1.36 WHEN 1 THEN 1.22 WHEN 2 THEN 1.09 ELSE 1.0 END) AS PROBE_READINGS
  FROM base
), events AS (
  SELECT *, PROBE_READINGS / DAILY_CAPACITY AS LOAD_RATIO,
         LEAST(0.5, BASE_WQ_EVENT_RATE * (0.4 + 1.6 * WEAR) * (0.3 + PROBE_READINGS / DAILY_CAPACITY)
                    * (1 + AGE_YEARS / 22) * (1 + 3.2 * STRESS)) AS P_EVT
  FROM loaded
), counted AS (
  SELECT *,
         CASE WHEN EVENT_HOURS IS NOT NULL THEN 1
              WHEN U_EVT < P_EVT / 4 THEN 2
              WHEN U_EVT < P_EVT THEN 1
              ELSE 0 END AS WQ_EVENT_COUNT
  FROM events
), timed AS (
  SELECT *,
         -- Aeration downtime: exponential, mean depends on farm type.
         CASE WHEN WQ_EVENT_COUNT = 0 THEN 0.0
              WHEN EVENT_HOURS IS NOT NULL THEN EVENT_HOURS
              ELSE LEAST(20.0, ROUND(WQ_EVENT_COUNT * (0.5 - LN(U_DOWN) *
                   CASE CATEGORY WHEN 'Intensive Shrimp Pond' THEN 2.8 WHEN 'Super-Intensive Shrimp Raceway' THEN 2.3
                                 WHEN 'Pangasius Pond' THEN 1.9 WHEN 'Shrimp Hatchery' THEN 3.0 ELSE 2.2 END), 1))
         END AS DOWNTIME_HOURS,
         -- In-band rate (probe readings with dissolved oxygen, pH, temperature, salinity and
         -- ammonia all inside the farm-type band): base by farm type, minus wear and overload,
         -- minus the event hit.
         LEAST(0.995, GREATEST(0.50,
           CASE CATEGORY WHEN 'Intensive Shrimp Pond' THEN 0.951 WHEN 'Super-Intensive Shrimp Raceway' THEN 0.943
                         WHEN 'Pangasius Pond' THEN 0.958 WHEN 'Shrimp Hatchery' THEN 0.966 ELSE 0.947 END
             - 0.031 * WEAR - 0.05 * GREATEST(0, LOAD_RATIO - 0.9) - 0.011 * U_NOISE
             - WQ_EVENT_COUNT * (0.07 + 0.13 * U_HIT))) AS IN_BAND_RATE
  FROM counted
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE, PLANNED_HOURS, DOWNTIME_HOURS,
       PLANNED_HOURS - DOWNTIME_HOURS AS OPERATING_HOURS,
       WQ_EVENT_COUNT,
       CASE WHEN WQ_EVENT_COUNT = 0 THEN 'None'
            WHEN EVENT_CAUSE IS NOT NULL THEN EVENT_CAUSE
            WHEN CATEGORY = 'Intensive Shrimp Pond' THEN IFF(U_CAUSE < 0.45, 'Dawn dissolved oxygen sag', IFF(U_CAUSE < 0.75, 'Algae bloom crash', 'Ammonia build-up'))
            WHEN CATEGORY = 'Super-Intensive Shrimp Raceway' THEN IFF(U_CAUSE < 0.5, 'Aerator motor failure', IFF(U_CAUSE < 0.8, 'Nitrite spike', 'Blower power trip'))
            WHEN CATEGORY = 'Pangasius Pond' THEN IFF(U_CAUSE < 0.55, 'Heavy rain pH drop', 'Sludge build-up')
            WHEN CATEGORY = 'Shrimp Hatchery' THEN IFF(U_CAUSE < 0.6, 'Water heater fault', 'Seawater intake turbidity')
            ELSE IFF(U_CAUSE < 0.55, 'Biofilter failure', 'Probe calibration drift') END AS ROOT_CAUSE,
       PM_DUE, PM_COMPLETED,
       PROBE_READINGS,
       FLOOR(PROBE_READINGS * IN_BAND_RATE) AS IN_BAND_READINGS,
       ROUND(PROBE_READINGS * (4.0 + U_VOLUME * 1.5)) AS PARAMETER_CHECKS,
       ROUND(PROBE_READINGS * (4.0 + U_VOLUME * 1.5) * (0.005 + 0.012 * WEAR + 0.022 * WQ_EVENT_COUNT + 0.004 * U_NOISE)) AS ALARM_CHECKS,
       -- Total ammonia nitrogen (mg/L): rises with wear, overload, stratification and events.
       ROUND(0.38 + 0.31 * WEAR + 0.40 * GREATEST(0, LOAD_RATIO - 0.8) + 0.34 * STRESS + 0.45 * WQ_EVENT_COUNT + U_NOISE * 0.12, 3) AS AMMONIA_MG_L,
       ROUND(LEAST(100, 100 * LOAD_RATIO * (0.80 + 0.13 * U_NOISE) + 8 * STRESS + 6 * WQ_EVENT_COUNT), 1) AS AERATOR_LOAD_PCT,
       ROUND(84.0 + 13.0 * IN_BAND_RATE + 1.6 * U_NOISE, 1) AS FEED_UPTAKE_PCT,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM timed;

-- Aeration and monitoring equipment readiness per farm (snapshot): units required versus on hand.
CREATE TABLE RAW.EQUIPMENT_READINESS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Intensive Shrimp Pond' THEN 'Paddlewheel aerator' WHEN 'Super-Intensive Shrimp Raceway' THEN 'Air blower'
                     WHEN 'Pangasius Pond' THEN 'Water pump' WHEN 'Shrimp Hatchery' THEN 'Backup generator'
                     ELSE 'Dissolved oxygen probe' END AS EQUIPMENT_TYPE,
       5 + MOD(ABS(HASH(ID, 'vnaqwq-req')), 21) AS REQUIRED_QTY,
       FLOOR((5 + MOD(ABS(HASH(ID, 'vnaqwq-req')), 21)) * (0.68 + MOD(ABS(HASH(ID, 'vnaqwq-avail')), 1000) / 1000 * 0.36)) AS ON_HAND_QTY,
       MOD(ABS(HASH(ID, 'vnaqwq-order')), 4) AS ON_ORDER_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.FARMS;
