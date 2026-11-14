const DOMAIN = "tsujiura.ogadra.net";
const TOKEN_COUNT = 10;
// Provisional until the log delivery delays in #1 are measured.
const POLL_INTERVAL_MS = 2000;
const POLL_TIMEOUT_MS = 60000;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Each provider points the token names at its own frontend, and each frontend serves provider.svg at its own width.
// The width is read instead of a response body because an image needs no CORS to be read across origins.
const PROVIDER_BY_WIDTH = { 1: "route53", 2: "cloudDns" };

// Resolves with the provider whose answer the browser connected to, or null when the image does not load by the deadline.
function probeToken(token, deadline) {
  return new Promise((resolve) => {
    const image = new Image();
    image.onload = () => resolve(PROVIDER_BY_WIDTH[image.naturalWidth] ?? null);
    image.onerror = () => resolve(null);
    setTimeout(() => resolve(null), deadline - Date.now());
    image.src = `https://${token}.${DOMAIN}/provider.svg`;
  });
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
  const deadline = Date.now() + POLL_TIMEOUT_MS;
  return Promise.all(
    tokens.map(async (token) => {
      const [answeredBy, result] = await Promise.all([probeToken(token, deadline), pollToken(token, deadline)]);
      return { answeredBy, ...result };
    }),
  );
}

measure();
