/**
 * One-time cleanup: delete fires/ documents that use the old raw CSV schema
 * (fields: latitude, longitude, date, time, brightness, daynight)
 * instead of the current schema (fields: lat, lng, frp, detectedAt, source).
 *
 * These were written by an early dev version of fetchAndStoreFires before Chat 6.
 * They are harmless to app logic (silently skipped) but pollute Firestore
 * and cause the schema QA check to fail.
 *
 * Safe to run multiple times (idempotent).
 * Run: node cleanup_old_fires.js
 */

const https = require("https");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "agrokavach-34bf1";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

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
    const r = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method,
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      },
      (res) => {
        let d = "";
        res.on("data", (c) => (d += c));
        res.on("end", () => {
          try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
          catch { resolve({ status: res.statusCode, body: d }); }
        });
      }
    );
    r.on("error", reject);
    if (body) r.write(JSON.stringify(body));
    r.end();
  });
}

async function getAllOldFireIds(token) {
  let pageToken = null;
  const oldIds = [];
  let pageCount = 0;

  while (true) {
    let url = `${FIRESTORE_BASE}/fires?pageSize=300`;
    if (pageToken) url += `&pageToken=${pageToken}`;
    const res = await req("GET", url, token);
    if (res.status !== 200) {
      console.error("Failed to list fires:", res.status, JSON.stringify(res.body).slice(0, 200));
      break;
    }
    const docs = res.body.documents || [];
    pageCount++;
    for (const doc of docs) {
      const fields = doc.fields || {};
      // Old schema: has 'latitude' but not 'lat'
      if ("latitude" in fields && !("lat" in fields)) {
        oldIds.push(doc.name); // full resource name for DELETE
      }
    }
    if (!res.body.nextPageToken) break;
    pageToken = res.body.nextPageToken;
  }

  return { oldIds, pageCount };
}

async function main() {
  console.log("🧹 AgroShield — Cleanup old-schema fires/\n");
  const token = getToken();

  console.log("Scanning fires/ collection for old-format documents...");
  const { oldIds, pageCount } = await getAllOldFireIds(token);
  console.log(`Scanned ${pageCount} page(s). Found ${oldIds.length} old-format documents.\n`);

  if (oldIds.length === 0) {
    console.log("✅ Nothing to clean up — all fires/ documents use the current schema.");
    return;
  }

  console.log(`Deleting ${oldIds.length} old documents...`);
  let deleted = 0;
  let errored = 0;

  // Firestore REST DELETE is one document at a time. Batch for speed.
  const CHUNK = 10;
  for (let i = 0; i < oldIds.length; i += CHUNK) {
    const chunk = oldIds.slice(i, i + CHUNK);
    await Promise.all(
      chunk.map(async (name) => {
        // The full resource name from the list response is the DELETE URL
        const delUrl = `https://firestore.googleapis.com/v1/${name}`;
        const r = await req("DELETE", delUrl, token);
        if (r.status === 200) {
          deleted++;
        } else {
          console.error(`  ❌ Failed to delete ${name.split("/").pop()}: HTTP ${r.status}`);
          errored++;
        }
      })
    );
    process.stdout.write(`  Progress: ${Math.min(i + CHUNK, oldIds.length)}/${oldIds.length}\r`);
  }

  console.log(`\n✅ Deleted ${deleted} old-format documents.`);
  if (errored > 0) console.log(`❌ ${errored} deletions failed — retry if needed.`);
}

main().catch((e) => { console.error("Script error:", e); process.exit(1); });
