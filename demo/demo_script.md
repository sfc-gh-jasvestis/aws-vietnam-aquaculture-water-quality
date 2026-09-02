# Water Quality Monitoring

**Vietnam - Aquaculture & Seafood**
Use case: Water Quality Monitoring

> Water Quality Monitoring for Vietnam - ML.FORECAST and Dynamic Tables power real-time water quality monitoring intelligence for aquaculture & seafood in Can Tho & Ca Mau.

## Why Snowflake

Snowflake delivers water quality monitoring intelligence for Vietnamese aquaculture & seafood - Dynamic Tables maintain real-time dashboards, ML.FORECAST projects key metrics, and Cortex AI generates recommendations

- **ML.FORECAST for water quality monitoring** - Only demo for Vietnamese aquaculture & seafood
- **ML.ANOMALY_DETECTION early warning** - Detects deviations before impact
- **AI recommendations** - Cortex AI actionable guidance
- **Vietnamese context** - Local names, VND economics

## What is deployed

| | |
|---|---|
| Database | `VIETNAM_AQUACULTURE_WATER_QUALITY` |
| Service | `VIETNAM_AQUACULTURE_WATER_QUALITY_APP` |
| Compute pool | `SEA_DEMOS_VIETNAM_POOL` |
| Dimension table | `RAW.DOCUMENTS` (20 rows) |
| Fact table | `RAW.METRICS` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | VND (₫) |

Regions in play: Ho Chi Minh City, Hanoi, Binh Duong, Dong Nai, Can Tho
Segments: Intake Canal, Grow-Out Pond, Settlement Pond, Discharge

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh VIETNAM_AQUACULTURE_WATER_QUALITY
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Water Quality Index | `7.4/10` | average per event |
| Dissolved Oxygen (Avg) | `5.2 mg/L` | average per event |
| Disease Alerts | `8` | total across Documents |
| Ponds Monitored | `14,200` | total across Documents |
| pH (Avg) | `7.8` | average per event |
| Ammonia Level | `0.04 mg/L` | average per event |
| Temperature | `28.4°C` | average per event |


## Demo flow

1. Overview
2. Analytics
3. AI Intelligence
4. Ask AI
5. Architecture

## Talking points

- **100K operations** - tracked in Can Tho & Ca Mau
- **500K metrics** - time-series data points
- **5K assets** - monitored
- **100 docs** - searchable

## Business impact

- Vietnam aquaculture & seafood sector growing rapidly (GSO Vietnam)
- AI improves outcomes 15-30% (McKinsey)
- Vietnam FDI strong in this sector (MPI)
- Real-time analytics reduces response 60-80% (Gartner)

---
Generated from `generator/demo_specs/aws-vietnam-aquaculture-water-quality.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-vietnam-aquaculture-water-quality` instead.
