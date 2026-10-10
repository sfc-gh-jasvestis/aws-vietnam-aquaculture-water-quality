"""Publish simulated aquaculture pond probe telemetry to AWS IoT Core (topic vn/aquaculture-water-quality/telemetry).

The IoT rule lands each message in S3; Snowpipe loads it into RAW.LIVE_TELEMETRY.
Farm IDs come from RAW.FARMS (WQ-0000..WQ-0029). Values are seeded random.
"""
import argparse
import json
import random
from datetime import datetime, timezone

TOPIC = 'vn/aquaculture-water-quality/telemetry'


def build_message(rng, now=None):
    """One synthetic reading: total ammonia nitrogen (mg/L) and aerator load (%)."""
    now = now or datetime.now(timezone.utc)
    alarm = rng.random() < 0.1
    return {'farm_id': f'WQ-{rng.randint(0, 29):04d}',
            'event_ts': now.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'ammonia_mg_l': round(max(0.05, rng.gauss(1.65 if alarm else 0.62, 0.12)), 3),
            'aerator_load_pct': round(min(100.0, rng.gauss(95 if alarm else 71, 3)), 1),
            'status': 'ALARM' if alarm else 'NORMAL'}


def publish_request(message):
    """Keyword arguments for the iot-data Publish call."""
    return {'topic': TOPIC, 'qos': 1, 'payload': json.dumps(message).encode('utf-8')}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    iot = boto3.client('iot', region_name=args.region)
    endpoint = iot.describe_endpoint(endpointType='iot:Data-ATS')['endpointAddress']
    data = boto3.client('iot-data', region_name=args.region, endpoint_url=f'https://{endpoint}')
    rng = random.Random(args.seed)
    for _ in range(args.count):
        data.publish(**publish_request(build_message(rng)))
    print(f'published {args.count} messages to {TOPIC} via {endpoint}')


if __name__ == '__main__':
    main()
