import { check, sleep } from 'k6';
import loki from 'k6/x/loki';
import { Counter } from 'k6/metrics';

/**
 * OTel Collector batch optimization test
 * Sends logs via xk6-loki to OTel Collector's Loki receiver to test batch processing
 */

const TENANT_ID = __ENV.TENANT_ID || 'foo';
const OTEL_COLLECTOR = `http://${TENANT_ID}@localhost:3101`;

const totalLogsSent = new Counter('logs_sent_total');

// Label cardinality - controls number of unique streams
const labelCardinality = {
  "app": 1,      // Reduce to 1 stream for max throughput
  "env": 1,
  "scenario": 1,
};

const KB = 1024;

export const options = {
  scenarios: {
    low_volume: {
      executor: 'constant-vus',
      exec: 'lowVolume',
      vus: 1,
      duration: '30s',
      startTime: '0s',
    },
    high_volume: {
      executor: 'constant-vus',
      exec: 'highVolume',
      vus: 12,
      duration: '90s',
      startTime: '35s',
    },
    burst: {
      executor: 'ramping-vus',
      exec: 'burst',
      startVUs: 10,
      stages: [
        { duration: '5s', target: 18 },
        { duration: '40s', target: 18 },
        { duration: '5s', target: 1 },
      ],
      startTime: '2m10s',
    },
  },
  thresholds: {
    'http_req_failed': ['rate<0.05'],
    'http_req_duration': ['p(95)<2000'],
  },
};

/**
 * Low volume - tests timeout-based batching (200ms)
 * Sends small batches slowly
 */
export function lowVolume() {
  const conf = new loki.Config(OTEL_COLLECTOR, 10000, 0.8, labelCardinality);
  const client = new loki.Client(conf);
  
  // Send 20-30 KB every 500ms
  let res = client.pushParameterized(1, 20 * KB, 30 * KB);
  totalLogsSent.add(1);
  
  check(res, {
    'low_volume success': (r) => r.status === 204,
  });
  
  if (res.status !== 204) {
    console.log(`[LOW_VOLUME] Failed: ${res.status}`);
  }
  
  sleep(0.5);
}

/**
 * High volume - tests size-based batching (128 logs)
 * Sends larger batches quickly
 */
export function highVolume() {
  const conf = new loki.Config(OTEL_COLLECTOR, 10000, 0.8, labelCardinality);
  const client = new loki.Client(conf);
  
  // Send 100-150 KB every 100ms
  let res = client.pushParameterized(2, 100 * KB, 150 * KB);
  totalLogsSent.add(2);
  
  check(res, {
    'high_volume success': (r) => r.status === 204,
  });
  
  if (res.status !== 204) {
    console.log(`[HIGH_VOLUME] Failed: ${res.status}`);
  }
  
  sleep(0.1);
}

/**
 * Burst - tests max batch size (128)
 * Sends large batches rapidly
 */
export function burst() {
  const conf = new loki.Config(OTEL_COLLECTOR, 10000, 0.8, labelCardinality);
  const client = new loki.Client(conf);
  
  // Send 150-200 KB rapidly
  let res = client.pushParameterized(3, 150 * KB, 200 * KB);
  totalLogsSent.add(3);
  
  check(res, {
    'burst success': (r) => r.status === 204,
  });
  
  if (res.status !== 204) {
    console.log(`[BURST] Failed: ${res.status}`);
  }
  
  sleep(0.05);
}

/**
 * Summary function to analyze results
 */
export function handleSummary(data) {
  console.log('\n=== OTel Batch Test Results (via xk6-loki) ===\n');
  
  const totalReqs = data.metrics['http_reqs']?.values.count || 0;
  const successRate = ((1 - (data.metrics.http_req_failed?.values.rate || 0)) * 100).toFixed(2);
  
  console.log(`Total HTTP requests: ${totalReqs}`);
  console.log(`Success rate: ${successRate}%`);
  console.log(`Average latency: ${data.metrics['http_req_duration']?.values.avg.toFixed(2)}ms`);
  
  console.log('\n=== Analyze OTel Collector Batching ===');
  console.log('Run: kubectl logs -n observability-lab deploy/otel-collector --tail=200 | grep -E "Exporting|batch"');
  console.log('\nLook for:');
  console.log('  - "Exporting X items" from logs pipeline to Loki');
  console.log('  - Batch sizes vs send_batch_size (128) and timeout (200ms)');
  
  console.log('\n=== xk6-loki Generated Data ===');
  console.log('xk6-loki auto-generates log streams with random labels based on cardinality:');
  console.log(`  - app: ${labelCardinality.app} variants`);
  console.log(`  - env: ${labelCardinality.env} variant(s)`);
  console.log(`  - scenario: ${labelCardinality.scenario} variant(s)`);
  console.log(`  Total unique streams: ~${labelCardinality.app * labelCardinality.env * labelCardinality.scenario}`);
  
  return {
    'stdout': JSON.stringify(data, null, 2),
  };
}
