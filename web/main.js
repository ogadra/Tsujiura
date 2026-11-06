const DOMAIN = "tsujiura.ogadra.net";
const TOKEN_COUNT = 10;
// Provisional until the log delivery delays in #1 are measured.
const POLL_INTERVAL_MS = 2000;
const POLL_TIMEOUT_MS = 60000;
const MEASURE_FAILED = "結果を取得できなかったため、計測を止めました";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Only the name resolution matters, so the image is allowed to fail.
function resolveToken(token) {
  new Image().src = `https://${token}.${DOMAIN}/`;
}

async function fetchResult(token) {
  const response = await fetch(`/api/result?token=${token}`);
  return { status: response.status, body: await response.json() };
}

// Polls until a provider has a record, the deadline passes, or any token of the run stops it.
async function pollToken(token, deadline, run) {
  for (;;) {
    const result = await fetchResult(token);
    const recorded = result.body.route53 || result.body.cloudDns;
    run.stopped ||= result.status !== 200;
    if (run.stopped || recorded || Date.now() + POLL_INTERVAL_MS >= deadline) {
      return { token, ...result };
    }
    await sleep(POLL_INTERVAL_MS);
    if (run.stopped) {
      return { token, ...result };
    }
  }
}

async function measure() {
  const tokens = Array.from({ length: TOKEN_COUNT }, () => crypto.randomUUID());
  tokens.forEach(resolveToken);
  const deadline = Date.now() + POLL_TIMEOUT_MS;
  const run = { stopped: false };
  try {
    return await Promise.all(tokens.map((token) => pollToken(token, deadline, run)));
  } finally {
    run.stopped = true;
  }
}

function summarize(results) {
  const failed = results.filter((result) => result.status !== 200);
  if (failed.length > 0) {
    const databases = new Set(failed.flatMap((result) => result.body.unavailable ?? []));
    return databases.size > 0 ? `${[...databases].join("、")}を読めなかったため、計測を止めました` : MEASURE_FAILED;
  }
  const count = (provider) => results.filter((result) => result.body[provider]).length;
  const missing = results.filter((result) => !result.body.route53 && !result.body.cloudDns).length;
  return `Route53: ${count("route53")}回、Cloud DNS: ${count("cloudDns")}回、どちらにも届かなかった: ${missing}個`;
}

const output = document.getElementById("result");
try {
  output.textContent = summarize(await measure());
} catch {
  output.textContent = MEASURE_FAILED;
}
