/**
 * AgroShield Firebase QA Script — Chat 10 Pre-Chat 11 verification
 * Uses Firebase CLI OAuth token + Firestore REST API (no service account needed).
 * Run: node qa_firebase.js
 */

const https = require("https");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "agrokavach-34bf1";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const MANUAL_FETCH_URL = "https://fetchfiresmanual-3o5ditkc5q-uc.a.run.app";

// Load ADMIN_SECRET from functions/.env so the QA script can call fetchFiresManual
const envContent = fs.readFileSync(path.join(__dirname, "functions/.env"), "utf8");
let ADMIN_SECRET = "";
for (const line of envContent.split("\n")) {
  const [k, ...rest] = line.split("=");
  if (k && k.trim() === "ADMIN_SECRET") { ADMIN_SECRET = rest.join("=").trim(); break; }
}

// ── Load access token from firebase CLI cache ─────────────────────────────────
function getAccessToken() {
  const configPath = path.join(
    process.env.HOME,
    ".config/configstore/firebase-tools.json"
  );
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  return config.tokens.access_token;
}

// ── Generic HTTPS request helper ──────────────────────────────────────────────
function request(method, urlStr, token, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const opts = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
    };
    const req = https.request(opts, (res) => {
      let data = "";
      res.on("data", (c) => (data += c));
      res.on("end", () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on("error", reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ── Firestore helpers ─────────────────────────────────────────────────────────
async function listDocs(collection, token, pageSize = 20) {
  const url = `${FIRESTORE_BASE}/${collection}?pageSize=${pageSize}`;
  const res = await request("GET", url, token);
  return res;
}

async function getDoc(path_, token) {
  const url = `${FIRESTORE_BASE}/${path_}`;
  return request("GET", url, token);
}

async function writeDoc(collection, docId, fields, token) {
  const url = `${FIRESTORE_BASE}/${collection}/${docId}`;
  return request("PATCH", url, token, { fields });
}

async function deleteDoc(path_, token) {
  const url = `${FIRESTORE_BASE}/${path_}`;
  return request("DELETE", url, token);
}

// Convert Firestore value object → JS
function fv(v) {
  if (!v) return null;
  if ("stringValue" in v) return v.stringValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("nullValue" in v) return null;
  if ("mapValue" in v) {
    const out = {};
    for (const [k, val] of Object.entries(v.mapValue.fields || {}))
      out[k] = fv(val);
    return out;
  }
  return JSON.stringify(v);
}

function docToJs(doc) {
  const out = {};
  for (const [k, v] of Object.entries(doc.fields || {})) out[k] = fv(v);
  return out;
}

// ── QA Checks ─────────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;
let warned = 0;

function pass(label, detail = "") {
  console.log(`  ✅ ${label}${detail ? " — " + detail : ""}`);
  passed++;
}

function fail(label, detail = "") {
  console.log(`  ❌ ${label}${detail ? " — " + detail : ""}`);
  failed++;
}

function warn(label, detail = "") {
  console.log(`  ⚠️  ${label}${detail ? " — " + detail : ""}`);
  warned++;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log("╔════════════════════════════════════════════════════════╗");
  console.log("║   AgroShield Firebase QA — Pre-Chat 11 Verification   ║");
  console.log("╚════════════════════════════════════════════════════════╝\n");

  const token = getAccessToken();
  console.log("🔑 OAuth token loaded from Firebase CLI cache.\n");

  // ─── 1. fires/ collection ─────────────────────────────────────────────────
  console.log("─── 1. fires/ collection ───────────────────────────────");
  const firesRes = await listDocs("fires", token, 20);
  if (firesRes.status !== 200) {
    fail("fires/ readable", `HTTP ${firesRes.status}`);
  } else {
    const fireDocs = firesRes.body.documents || [];
    if (fireDocs.length === 0) {
      warn("fires/ has documents", "Collection is empty — will trigger fetchFiresManual");
    } else {
      pass("fires/ readable", `${fireDocs.length} docs (page of 20)`);
      const sample = docToJs(fireDocs[0]);
      const hasLat = "lat" in sample;
      const hasLng = "lng" in sample;
      const hasFrp = "frp" in sample;
      const hasTs = "detectedAt" in sample;
      const hasSource = "source" in sample;
      if (hasLat && hasLng && hasFrp && hasTs && hasSource) {
        pass("fires/ schema correct", "lat, lng, frp, detectedAt, source all present");
      } else {
        fail(
          "fires/ schema",
          `Missing: ${[!hasLat && "lat", !hasLng && "lng", !hasFrp && "frp", !hasTs && "detectedAt", !hasSource && "source"].filter(Boolean).join(", ")}`
        );
      }
    }
  }

  // ─── 2. devices/ collection ───────────────────────────────────────────────
  console.log("\n─── 2. devices/ collection ─────────────────────────────");
  const devRes = await listDocs("devices", token, 10);
  if (devRes.status !== 200) {
    fail("devices/ readable", `HTTP ${devRes.status}`);
  } else {
    const devDocs = devRes.body.documents || [];
    if (devDocs.length === 0) {
      warn("devices/ has documents", "No registered devices — notifications cannot fire until a device completes onboarding");
    } else {
      pass("devices/ readable", `${devDocs.length} registered device(s)`);
      const sample = docToJs(devDocs[0]);
      const requiredFields = ["deviceId", "fcmToken", "farmLat", "farmLng", "radiusInKm"];
      const missing = requiredFields.filter((f) => !(f in sample));
      if (missing.length === 0) {
        pass("devices/ schema correct", requiredFields.join(", ") + " all present");
      } else {
        fail("devices/ schema", `Missing: ${missing.join(", ")}`);
      }
      if (sample.farmLat && sample.farmLng) {
        pass("devices/ has valid farm location", `${sample.farmLat}, ${sample.farmLng}`);
      }
    }
  }

  // ─── 3. scoringLogs/ collection ───────────────────────────────────────────
  console.log("\n─── 3. scoringLogs/ collection ─────────────────────────");
  const logsRes = await listDocs("scoringLogs", token, 20);
  if (logsRes.status !== 200) {
    fail("scoringLogs/ readable", `HTTP ${logsRes.status}`);
  } else {
    const logDocs = logsRes.body.documents || [];
    if (logDocs.length === 0) {
      warn(
        "scoringLogs/ has documents",
        "Collection empty — scoreFireRelevance runs every 6h. Trigger manually or wait for next run."
      );
    } else {
      pass("scoringLogs/ readable", `${logDocs.length} docs (page of 20)`);
      const sample = docToJs(logDocs[0]);
      const requiredFields = [
        "fireId", "deviceId", "distKm", "frp",
        "customFireIndex", "vegetationScore", "score", "scoredAt",
      ];
      const missing = requiredFields.filter((f) => !(f in sample));
      if (missing.length === 0) {
        pass("scoringLogs/ schema correct", requiredFields.join(", ") + " all present");
        // Spot-check score ranges
        if (sample.score >= 0 && sample.score <= 100) {
          pass("scoringLogs/ score in range [0, 100]", `sample score: ${sample.score.toFixed(2)}`);
        } else {
          fail("scoringLogs/ score out of range", `sample score: ${sample.score}`);
        }
        if (sample.customFireIndex >= 0 && sample.customFireIndex <= 100) {
          pass("scoringLogs/ customFireIndex in range [0, 100]", `${sample.customFireIndex.toFixed(2)}`);
        } else {
          warn("scoringLogs/ customFireIndex", `sample: ${sample.customFireIndex}`);
        }
      } else {
        fail("scoringLogs/ schema", `Missing: ${missing.join(", ")}`);
      }
    }
  }

  // ─── 4. users/ collection ─────────────────────────────────────────────────
  console.log("\n─── 4. users/ collection ───────────────────────────────");
  const usersRes = await listDocs("users", token, 10);
  if (usersRes.status !== 200) {
    warn("users/ readable", `HTTP ${usersRes.status} — may need auth`);
  } else {
    const userDocs = usersRes.body.documents || [];
    if (userDocs.length === 0) {
      warn("users/ has documents", "No signed-in users yet");
    } else {
      pass("users/ readable", `${userDocs.length} user doc(s)`);
      // Check farmData/profile subcollection for first user
      const firstUserId = userDocs[0].name.split("/").pop();
      const profileRes = await getDoc(`users/${firstUserId}/farmData/profile`, token);
      if (profileRes.status === 200) {
        const profile = docToJs(profileRes.body);
        pass("users/{uid}/farmData/profile exists", `keys: ${Object.keys(profile).join(", ")}`);
      } else if (profileRes.status === 404) {
        warn("users/{uid}/farmData/profile", "Not found — user has not completed onboarding farm data step");
      } else {
        warn("users/{uid}/farmData/profile", `HTTP ${profileRes.status}`);
      }
    }
  }

  // ─── 5. Write test fire + check notifiedDevices dedup structure ───────────
  console.log("\n─── 5. Test fire write + dedup structure check ─────────");
  const testFireId = `qa_test_fire_${Date.now()}`;
  const nowIso = new Date().toISOString();
  const writeRes = await writeDoc(
    "fires",
    testFireId,
    {
      lat: { doubleValue: 20.9 },
      lng: { doubleValue: 77.7 },
      frp: { doubleValue: 42.5 },
      detectedAt: { timestampValue: nowIso },
      source: { stringValue: "QA_TEST" },
    },
    token
  );

  if (writeRes.status === 200) {
    pass("Test fire written to fires/", `fires/${testFireId}`);
    console.log("     Waiting 12s for notifyDevicesOnNewFire to trigger...");
    await new Promise((r) => setTimeout(r, 12000));

    // Check notifiedDevices subcollection
    const notifiedRes = await listDocs(`fires/${testFireId}/notifiedDevices`, token, 10);
    if (notifiedRes.status === 200) {
      const notifiedDocs = notifiedRes.body.documents || [];
      if (notifiedDocs.length > 0) {
        pass(
          "notifyDevicesOnNewFire fired",
          `fires/${testFireId}/notifiedDevices has ${notifiedDocs.length} entry(ies)`
        );
        const n = docToJs(notifiedDocs[0]);
        if ("notifiedAt" in n) {
          pass("notifiedDevices/{deviceId} has notifiedAt field");
        } else {
          fail("notifiedDevices/{deviceId} missing notifiedAt");
        }
      } else {
        warn(
          "notifyDevicesOnNewFire — no notifiedDevices entries",
          "Either no devices in radius, FCM token stale, or function cold-starting. Check Cloud Logging."
        );
      }
    }

    // Clean up test document
    const delRes = await deleteDoc(`fires/${testFireId}`, token);
    if (delRes.status === 200) {
      pass("Test fire cleaned up", `fires/${testFireId} deleted`);
    } else {
      warn("Test fire cleanup", `HTTP ${delRes.status} — delete manually if needed`);
    }
  } else {
    fail("Test fire write failed", `HTTP ${writeRes.status}: ${JSON.stringify(writeRes.body).slice(0, 100)}`);
  }

  // ─── 6. Trigger fetchFiresManual ──────────────────────────────────────────
  console.log("\n─── 6. fetchFiresManual HTTP trigger ───────────────────");
  console.log("     Calling fetchFiresManual (may take up to 30s)...");
  try {
    const fetchRes = await new Promise((resolve, reject) => {
      const url = new URL(MANUAL_FETCH_URL);
      const req = https.request(
        { hostname: url.hostname, path: url.pathname, method: "GET", headers: { Authorization: `Bearer ${token}`, "x-admin-secret": ADMIN_SECRET } },
        (res) => {
          let d = "";
          res.on("data", (c) => (d += c));
          res.on("end", () => resolve({ status: res.statusCode, body: d }));
        }
      );
      req.setTimeout(60000, () => { req.destroy(); reject(new Error("timeout")); });
      req.on("error", reject);
      req.end();
    });
    if (fetchRes.status === 200) {
      pass("fetchFiresManual succeeded", fetchRes.body.trim());
    } else {
      warn("fetchFiresManual", `HTTP ${fetchRes.status}: ${fetchRes.body.slice(0, 80)}`);
    }
  } catch (err) {
    warn("fetchFiresManual", `Error: ${err.message} — may need unauthenticated access`);
  }

  // ─── 7. Re-check fires/ after fetch ──────────────────────────────────────
  console.log("\n─── 7. fires/ count after fetchFiresManual ─────────────");
  const fires2 = await listDocs("fires", token, 100);
  if (fires2.status === 200) {
    const count = (fires2.body.documents || []).length;
    if (count > 0) {
      pass("fires/ populated after fetch", `${count}+ docs (page of 100)`);
    } else {
      warn("fires/ still empty after fetch", "fetchFiresManual may have returned 0 hotspots (no active fires in NASA FIRMS for India at this time)");
    }
  }

  // ─── Summary ──────────────────────────────────────────────────────────────
  console.log("\n╔════════════════════════════════════════════════════════╗");
  console.log("║                      QA Summary                       ║");
  console.log("╚════════════════════════════════════════════════════════╝");
  console.log(`  ✅ Passed:  ${passed}`);
  console.log(`  ❌ Failed:  ${failed}`);
  console.log(`  ⚠️  Warned:  ${warned}`);
  console.log("");
  if (failed === 0) {
    console.log("  🎉 All checks passed or warned — no hard failures.");
  } else {
    console.log("  🔥 Some checks failed — review above and fix before Chat 11.");
  }
}

main().catch((err) => {
  console.error("QA script crashed:", err);
  process.exit(1);
});
