# Demo Script: Water Quality Monitoring
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake delivers water quality monitoring intelligence for Vietnamese aquaculture & seafood - Dynamic Tables maintain real-time dashboards, ML.FORECAST projects key metrics, and Cortex AI generates recommendations"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Dr. Tran Van Hai** | Chief Aquaculture Officer | React App (SPCS) | Water Quality Monitoring strategy, KPI tracking, operational decisions |
| **Pham Thi Loan** | Farm Manager | Amazon QuickSight | Water Quality Monitoring operations, analysis, reporting |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 5 tables | OPERATIONS (100000), METRICS (500000), ASSETS (5000), EVENTS (200000), DOCUMENTS (100) |
| **CURATED** | 4 Dynamic Tables | PERFORMANCE_DASHBOARD, TREND_ANALYTICS, FORECAST_INPUT, OPERATIONAL_RISK |
| **ML** | ML.FORECAST + ML.ANOMALY_DETECTION | Forecasting + anomaly detection |
| **AI** | COMPLETE, SUMMARIZE, AI_CLASSIFY | Classification + extraction |
| **Search** | Cortex Search | 100 documents indexed |
| **Agent** | AQUACULTURE_WATER_AGENT | Semantic View + Search tools |


---

## The Story

Vietnam aquaculture & seafood faces increasing complexity in water quality monitoring. Decision-makers in Can Tho & Ca Mau need real-time intelligence and ML-powered recommendations.

---

## Script

### [0:00–0:45] OVERVIEW

**Show**: Overview tab

> "Comprehensive water quality monitoring monitoring in Can Tho & Ca Mau."

**Action**: Primary KPI dashboard

### [0:45–1:30] ANALYTICS

**Show**: Analytics tab

> "Detailed trend analysis across parameters."

**Action**: Trend charts

### [1:30–2:15] AI INTELLIGENCE

**Show**: AI Intelligence tab

> "Cortex AI generates actionable recommendations."

**Action**: AI recommendations

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Dr. Tran Van Hai asks questions in natural language."

**Action**: Type question

### [3:00–3:45] ARCHITECTURE

**Show**: Architecture tab

> "Six Snowflake + six AWS services."

**Action**: Architecture diagram


---

## Key Demo Differentiators

1. **ML.FORECAST for water quality monitoring** — Only demo for Vietnamese aquaculture & seafood
2. **ML.ANOMALY_DETECTION early warning** — Detects deviations before impact
3. **AI recommendations** — Cortex AI actionable guidance
4. **Vietnamese context** — Local names, VND economics


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM AQUACULTURE_WATER.RAW.OPERATIONS` → 100000
- [ ] `SELECT COUNT(*) FROM AQUACULTURE_WATER.RAW.METRICS` → 500000

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM AQUACULTURE_WATER.ML.AQUACULTURE_WATER_FORECAST_RESULTS` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM AQUACULTURE_WATER.AI.EVENT_CLASSIFICATION` → >0

