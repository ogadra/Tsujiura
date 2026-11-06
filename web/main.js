const DOMAIN = "tsujiura.ogadra.net";
const TOKEN_COUNT = 10;
// Provisional until the log delivery delays in #1 are measured.
const POLL_INTERVAL_MS = 2000;
const POLL_TIMEOUT_MS = 60000;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Only the name resolution matters, so the image is allowed to fail.
function resolveToken(token) {
  new Image().src = `https://${token}.${DOMAIN}/`;
}

async function fetchResult(token) {
  const response = await fetch(`/api/result?token=${token}`);
  return { status: response.status, body: await response.json() };
}

// Polls until a provider has a record, the API answers with an error, or the deadline passes.
async function pollToken(token, deadline) {
  for (;;) {
    const result = await fetchResult(token);
    const recorded = result.body.route53 || result.body.cloudDns;
    if (result.status !== 200 || recorded || Date.now() + POLL_INTERVAL_MS >= deadline) {
      return { token, ...result };
    }
    await sleep(POLL_INTERVAL_MS);
  }
}

async function measure() {
  const tokens = Array.from({ length: TOKEN_COUNT }, () => crypto.randomUUID());
  tokens.forEach(resolveToken);
  const deadline = Date.now() + POLL_TIMEOUT_MS;
  return Promise.all(tokens.map((token) => pollToken(token, deadline)));
}

measure();
