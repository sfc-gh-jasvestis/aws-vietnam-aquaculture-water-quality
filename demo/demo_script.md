# Vietnam Aquaculture Water Quality Monitor

**Vietnam - Aquaculture Pond Water Quality**
Use case: In-band probe readings, pond traceability and water quality event risk

> Water quality monitoring for a fictional aquaculture group's network of 30 farms across 6 Vietnam cities (intensive shrimp ponds, super-intensive shrimp raceways, pangasius ponds, shrimp hatcheries and recirculating nurseries): dynamic tables, a holdout-evaluated event-risk classifier, a probe-reading volume forecast and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile in-band probe readings, alarm checks and aeration uptime from RAW farm data, with checks in `run_core.py`
- **Event-risk classification** gives a holdout-evaluated next-7-day water quality event probability per farm
- **Probe-reading volume forecast** projects 14 days of network-wide probe readings with prediction intervals
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live telemetry**: a native simulator (Snowflake only) or IoT Core, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.FARMS` (30 rows) |
| Fact table | `RAW.FARM_DAILY` (2,700 farm-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `WQ_EVENT_CAUSES`, `TREND_ANALYSIS` |
| ML | `ML.WQ_EVENT_RISK_SCORES`, `ML.WQ_EVENT_RISK_HOLDOUT_METRICS`, `ML.VOLUME_FORECAST`, `ML.AMMONIA_ANOMALIES` |

Cities: Can Tho, Ca Mau, Bac Lieu, Soc Trang, Ben Tre, Rach Gia.
Farm types: Intensive Shrimp Pond, Super-Intensive Shrimp Raceway, Pangasius Pond, Shrimp Hatchery, Recirculating Nursery.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| In-Band Probe Readings | 90.1% |
| Water Quality Events | 395 |
| Alarms per 1k Parameter Checks | 18.82 |
| Probe Readings | 987,152 |
| Aeration Uptime | 98.2% |
| Aquaculture Farms | 30 |
| Aeration Equipment Readiness | 81.0% |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily in-band probe readings, out-of-band readings by event cause, farm table
2. Predictive: holdout metrics, risk bands, 14-day probe-reading volume forecast, total ammonia anomalies
3. Farm Health: aeration uptime, aeration equipment readiness, PM compliance against in-band probe readings, then generate the action memo
4. Live IoT: run `CALL APP.SIMULATE_TELEMETRY(20)` (Snowflake only) or `python aws/publish_telemetry.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_ALARM_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- Per-farm in-band rate ranges from 87.7% to 92.4%. Soc Trang is the lowest city, at 89.4%.
- Aerator motor failure pushes the most readings out of band of the 14 event causes.
- The risk model is evaluated on a time-based holdout: precision 0.62 and recall 0.61 at 0.5, against a 0.55 base rate. Present it as triage, not a guarantee.
- The Ben Tre saline intrusion and the Ca Mau grid power outage are excluded from event labels, because they are city-wide events, not farm-driven.
- Pond traceability: SOPs require logging the affected pond IDs and confirming probe values with a handheld meter, and each farm-day records in-band readings and feed uptake.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
