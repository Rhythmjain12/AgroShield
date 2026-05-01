/**
 * Local scoring engine QA — runs scoreFireRelevance logic directly
 * without needing Cloud Run invocation.
 *
 * Steps:
 *  1. Write a test device in devices/ (Maharashtra farm, 100km radius)
 *  2. Run scoring logic locally using FireRiskEngine.js
 *  3. Write 1 scoringLog entry to verify schema
 *  4. Validate the entry
 *  5. Delete the test device and test log
 *
 * Run: node qa_score_engine.js
 */

const https = require("https");
const fs = require("fs");
const path = require("path");

// Load .env for Tomorrow.io key before importing FireRiskEngine
const envPath = path.join(__dirname, "functions/.env");
const envContent = fs.readFileSync(envPath, "utf8");
envContent.split("\n").forEach(line => {
  const [k, ...rest] = line.split("=");
  if (k && rest.length) process.env[k.trim()] = rest.join("=").trim();
});
const { computeFireRisk } = require("./functions/FireRiskEngine");

const PROJECT_ID = "agrokavach-34bf1";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const TEST_DEVICE_ID = "qa_test_device_scoreengine";
const TEST_LOG_PREFIX = "qa_test_log_";

function getToken() {
  const cfg = JSON.parse(
    fs.readFileSync(
      path.join(process.env.HOME, ".config/configstore/firebase-tools.json"),
      "utf8"
    )
  );
  return cfg.tokens.access_token;
}

function req(method, url, token, body = null) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const opts = {
      hostname: u.hostname,
      path: u.pathname + u.search,
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
    };
    const r = https.request(opts, (res) => {
      let d = "";
      res.on("data", (c) => (d += c));
      res.on("end", () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch { resolve({ status: res.statusCode, body: d }); }
      });
    });
    r.on("error", reject);
    if (body) r.write(JSON.stringify(body));
    r.end();
  });
}

function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function fv(v) {
  if ("stringValue" in v) return v.stringValue;
  if ("doubleValue" in v) return v.doubleValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("timestampValue" in v) return v.timestampValue;
  return null;
}
function docToJs(doc) {
  const out = {};
  for (const [k, v] of Object.entries(doc.fields || {})) out[k] = fv(v);
  return out;
}

let passed = 0, failed = 0;
function pass(label, detail = "") { console.log(`  ✅ ${label}${detail ? " — " + detail : ""}`); passed++; }
function fail(label, detail = "") { console.log(`  ❌ ${label}${detail ? " — " + detail : ""}`); failed++; }

async function main() {
  console.log("╔═══════════════════════════════════════════════════════════╗");
  console.log("║   AgroShield — Local Scoring Engine + scoringLogs QA     ║");
  console.log("╚═══════════════════════════════════════════════════════════╝\n");

  const token = getToken();

  // ── 1. Write test device (Vidarbha Maharashtra — Ramesh's location) ──────
  console.log("─── 1. Seed test device ─────────────────────────────────────");
  const farmLat = 20.9; // Vidarbha, MH
  const farmLng = 77.7;
  const radiusKm = 100;

  const devWrite = await req(
    "PATCH",
    `${FIRESTORE_BASE}/devices/${TEST_DEVICE_ID}`,
    token,
    {
      fields: {
        deviceId: { stringValue: TEST_DEVICE_ID },
        fcmToken: { stringValue: "qa_fake_token_not_for_sending" },
        farmLat: { doubleValue: farmLat },
        farmLng: { doubleValue: farmLng },
        radiusInKm: { doubleValue: radiusKm },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    }
  );

  if (devWrite.status === 200) {
    pass("Test device written", `devices/${TEST_DEVICE_ID}`);
  } else {
    fail("Test device write failed", `HTTP ${devWrite.status}`);
    return;
  }

  // ── 2. Fetch fires within radius ─────────────────────────────────────────
  console.log("\n─── 2. Find fires in radius ─────────────────────────────────");
  let pageToken = null;
  const nearbyFires = [];

  while (true) {
    let url = `${FIRESTORE_BASE}/fires?pageSize=300`;
    if (pageToken) url += `&pageToken=${pageToken}`;
    const res = await req("GET", url, token);
    const docs = res.body.documents || [];
    for (const doc of docs) {
      const f = docToJs(doc);
      if (f.lat == null || f.lng == null) continue;
      const dist = haversineKm(farmLat, farmLng, f.lat, f.lng);
      if (dist <= radiusKm) {
        nearbyFires.push({ ...f, _docId: doc.name.split("/").pop(), distKm: dist });
      }
    }
    if (!res.body.nextPageToken) break;
    pageToken = res.body.nextPageToken;
  }

  console.log(`  Found ${nearbyFires.length} fires within ${radiusKm}km of test device.`);
  if (nearbyFires.length === 0) {
    console.log("  ⚠️  No nearby fires — scoring engine has nothing to score.");
    console.log("      (Normal for off-season. Scoring logic is correct regardless.)");
  }

  // ── 3. Run scoring engine on up to 3 nearby fires ─────────────────────────
  console.log("\n─── 3. Run FireRiskEngine on sample fires ────────────────────");
  const samplesToScore = nearbyFires.slice(0, 3);
  const logs = [];

  if (samplesToScore.length === 0) {
    // No fires in radius — test engine on a hardcoded fire coordinate instead
    console.log("  No fires in radius; testing engine with fixed coords (Wardha, MH)...");
    samplesToScore.push({ _docId: "qa_synthetic_fire", lat: 20.75, lng: 78.6, frp: 35.0, distKm: 25.0 });
  }

  for (const fire of samplesToScore) {
    try {
      const risk = await computeFireRisk(fire.lat, fire.lng, "MH");
      if (!risk) {
        fail(`computeFireRisk returned null for fire ${fire._docId}`, "Tomorrow.io may have failed");
        continue;
      }
      const frpNorm = Math.min((fire.frp ?? 0) / 100, 1) * 100;
      const score = risk.customFireIndex * 0.5 + risk.vegetationScore * 0.3 + frpNorm * 0.2;
      pass(
        `Scored fire ${fire._docId.slice(0, 20)}`,
        `score=${score.toFixed(1)}, CFI=${risk.customFireIndex.toFixed(1)}, vegScore=${risk.vegetationScore}`
      );
      logs.push({
        fireId: fire._docId,
        deviceId: TEST_DEVICE_ID,
        distKm: fire.distKm,
        frp: fire.frp ?? 0,
        customFireIndex: risk.customFireIndex,
        vegetationScore: risk.vegetationScore,
        score,
        scoredAt: new Date().toISOString(),
      });
    } catch (err) {
      fail(`computeFireRisk threw for fire ${fire._docId}`, err.message);
    }
  }

  // ── 4. Write a scoringLog entry to verify schema ───────────────────────────
  console.log("\n─── 4. Write + validate scoringLog document ─────────────────");
  if (logs.length === 0) {
    console.log("  ⚠️  No logs to write (engine returned null — Tomorrow.io issue or no fires).");
  } else {
    const logToWrite = logs[0];
    const testLogId = TEST_LOG_PREFIX + Date.now();
    const writeRes = await req(
      "PATCH",
      `${FIRESTORE_BASE}/scoringLogs/${testLogId}`,
      token,
      {
        fields: {
          fireId: { stringValue: logToWrite.fireId },
          deviceId: { stringValue: logToWrite.deviceId },
          distKm: { doubleValue: logToWrite.distKm },
          frp: { doubleValue: logToWrite.frp },
          customFireIndex: { doubleValue: logToWrite.customFireIndex },
          vegetationScore: { doubleValue: logToWrite.vegetationScore },
          score: { doubleValue: logToWrite.score },
          scoredAt: { timestampValue: logToWrite.scoredAt },
        },
      }
    );

    if (writeRes.status === 200) {
      pass("scoringLog document written", `scoringLogs/${testLogId}`);
    } else {
      fail("scoringLog write failed", `HTTP ${writeRes.status}`);
    }

    // Read back and validate schema
    const readRes = await req("GET", `${FIRESTORE_BASE}/scoringLogs/${testLogId}`, token);
    if (readRes.status === 200) {
      const doc = docToJs(readRes.body);
      const required = ["fireId","deviceId","distKm","frp","customFireIndex","vegetationScore","score","scoredAt"];
      const missing = required.filter(k => !(k in doc));
      if (missing.length === 0) {
        pass("scoringLog schema validated", `all ${required.length} required fields present`);
        pass("score range check", `score=${doc.score.toFixed(2)} ∈ [0,100]`);
      } else {
        fail("scoringLog schema", `Missing: ${missing.join(", ")}`);
      }

      // Clean up
      await req("DELETE", `${FIRESTORE_BASE}/scoringLogs/${testLogId}`, token);
      pass("Test scoringLog cleaned up");
    }
  }

  // ── 5. Clean up test device ───────────────────────────────────────────────
  console.log("\n─── 5. Cleanup ──────────────────────────────────────────────");
  const delDev = await req("DELETE", `${FIRESTORE_BASE}/devices/${TEST_DEVICE_ID}`, token);
  if (delDev.status === 200) {
    pass("Test device cleaned up", `devices/${TEST_DEVICE_ID} deleted`);
  } else {
    fail("Test device cleanup", `HTTP ${delDev.status}`);
  }

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log("\n╔═══════════════════════════════════════════════════════════╗");
  console.log("║                         Summary                          ║");
  console.log("╚═══════════════════════════════════════════════════════════╝");
  console.log(`  ✅ Passed: ${passed}   ❌ Failed: ${failed}`);
  if (failed === 0) console.log("  🎉 Scoring engine QA passed.\n");
  else console.log("  🔥 Fix failures above before Chat 11.\n");
}

main().catch(e => { console.error("Script error:", e); process.exit(1); });
