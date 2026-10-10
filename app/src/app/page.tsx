'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface WaterQualityData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; value: number | null }[];
  categories: { category: string; count: number | null }[];
  entities: Record<string, string | number | null>[];
  pmInBand: { name: string; compliance: number; inBand: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; alarms: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<WaterQualityData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="In-Band Probe Readings" value={kpiVal('In-Band Probe Readings')} status="neutral" />
        <KPICard title="Water Quality Events" value={kpiVal('Water Quality Events')} status="neutral" />
        <KPICard title="Alarms per 1k Parameter Checks" value={kpiVal('Alarms per 1k Parameter Checks')} status="neutral" />
        <KPICard title="Probe Readings" value={kpiVal('Probe Readings')} status="neutral" />
      </div>
      <p className="text-sm text-slate-600">In-band probe readings = readings with dissolved oxygen, pH, temperature, salinity and total ammonia all inside the band for the farm type / all probe readings. Alarms per 1k parameter checks = individual parameter checks outside the band per 1,000 checks. A water quality event is a farm-day event, such as a dawn oxygen sag or an aerator failure, that pushed pond conditions out of band. All observations in the snapshot are included.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period" yKeys={[{ key: 'value', name: 'In-band %' }]} title="Daily In-Band Probe Readings" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category" yKeys={[{ key: 'count', name: 'Out-of-band readings' }]} title="Out-of-Band Readings on Event Days by Root Cause" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Farm' }, { key: 'name', header: 'Name' }, { key: 'region', header: 'City' },
        { key: 'category', header: 'Farm type' }, { key: 'inBand', header: 'In-band (%)' },
        { key: 'alarmsPer1k', header: 'Alarms per 1k checks' }, { key: 'uptime', header: 'Aeration uptime (%)' },
        { key: 'wqEvents', header: 'Water quality events' },
      ]} data={data?.entities ?? []} title="Farm observations" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day water quality event risk and probe-reading volume forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a farm has a water quality event in the next 7 days,
        from total ammonia, aerator load, recent events, pond infrastructure age and farm type.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} farm-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base event rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Farm' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(event in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Water quality event risk by farm" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Network-wide probe-reading volume forecast, next 14 days (readings per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Farm' }, { key: 'date', header: 'Date' }, { key: 'ammonia', header: 'Total ammonia (mg/L)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Total ammonia anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live telemetry: AWS IoT Core to S3 to Snowpipe' : 'Live telemetry: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated pond probes publish to the IoT Core topic vn/aquaculture-water-quality/telemetry (aws/publish_telemetry.py). An IoT rule writes each message to S3, and Snowpipe auto-ingest loads it into RAW.LIVE_TELEMETRY.'
          : 'CALL APP.SIMULATE_TELEMETRY(n) inserts simulated pond probe readings directly into RAW.LIVE_TELEMETRY (or resume APP.TASK_SIMULATE_TELEMETRY for a feed every minute). This simulates a sensor feed; it is not Snowpipe Streaming.'}
        {' '}The alert APP.LIVE_ALARM_ALERT logs ALARM readings and emails the on-call farm shift technician.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Messages loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="ALARM readings" value={String(data?.liveSummary?.alarms ?? 'n/a')} />
        <KPICard title={isAws ? 'Median IoT to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Farm' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'ammonia', header: 'Total ammonia (mg/L)' },
        { key: 'load', header: 'Aerator load (%)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 telemetry messages" />
      <DataTable columns={[
        { key: 'id', header: 'Farm' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'ammonia', header: 'Total ammonia (mg/L)' },
        { key: 'load', header: 'Aerator load (%)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <KPICard title="Aeration Uptime" value={kpiVal('Aeration Uptime')} />
        <KPICard title="Aeration Equipment Readiness" value={kpiVal('Aeration Equipment Readiness')} />
      </div>
      <Chart data={data?.pmInBand ?? []} type="scatter" xKey="compliance" xName="PM compliance" yKeys={[{ key: 'inBand', name: 'In-band (%)' }]} title="Preventive-maintenance compliance (%) vs in-band probe readings (%) by farm" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that preventive maintenance caused better water quality.</p>
      <ActionMemo persona={{ name: 'Nguyen Thi Thu Ha', role: 'Farm Operations Director (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft farm network water quality actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, water quality event, root-cause and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.WATER_QUALITY_AGENT. It uses Cortex Analyst over the semantic view APP.WATER_QUALITY_ANALYTICS for metrics, and Cortex Search over synthetic water quality response SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the water quality agent" mode="advisor" sampleQuestions={['Which 3 farms have the lowest in-band rate?', 'Which farms are high event risk this week and what SOP applies?', 'What is the in-band rate by city?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: synthetic intensive shrimp ponds, super-intensive shrimp raceways, pangasius ponds, shrimp hatcheries and recirculating nurseries, daily farm water quality observations and aeration equipment readiness. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION water quality event-risk model evaluated on a time-based holdout, plus a 14-day probe-reading volume FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags total ammonia outliers per farm over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: IoT Core topic rule to S3 to Snowpipe auto-ingest (SQS) into RAW.LIVE_TELEMETRY, with a Snowflake alert and email on ALARM readings.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (water quality events by farm, daily in-band probe readings) through a PAT-only service user, with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_TELEMETRY inserts simulated readings into RAW.LIVE_TELEMETRY, with a Snowflake alert and email on ALARM readings. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Farm Health', icon: '', content: planning },
    { id: 'live', label: 'Live IoT', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data. On-demand snapshots are not live farm operations.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No farm observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Vietnam Aquaculture Water Quality Monitor" tabs={tabs} />;
}
