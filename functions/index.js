// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");
const cors = require("cors")({ origin: true });
require("dotenv").config();

const { computeFireRisk } = require("./FireRiskEngine");

// The Firebase Admin SDK to access Firestore.
admin.initializeApp();
const db = admin.firestore();

const BATCH_SIZE = 400; // Firestore max is 500; stay under for safety

// ─── 1. Core: Fetch fires from NASA FIRMS and write to Firestore ──────────────
async function fetchAndStoreFires() {
  const mapKey = process.env.NASA_FIRMS_API_KEY;
  if (!mapKey) {
    logger.error("NASA_FIRMS_API_KEY not set in environment.");
    return;
  }

  const sourceSatellite = "VIIRS_SNPP_NRT";
  const bBox = "68,6,97,37"; // India bounding box
  const dayRange = "3";
  const url = `https://firms.modaps.eosdis.nasa.gov/api/area/csv/${mapKey}/${sourceSatellite}/${bBox}/${dayRange}`;

  let response;
  try {
    response = await axios.get(url, { timeout: 30000 });
  } catch (err) {
    logger.error("NASA FIRMS request failed", { msg: err.message });
    return;
  }

  const rows = response.data.split("\n");
  if (rows.length < 2) {
    logger.info("No fire rows returned from NASA FIRMS.");
    return;
  }

  const headers = rows[0].split(",").map((h) => h.trim());

  // Build all fire docs first, then write in batches (no per-row read — doc ID
  // is unique per observation so overwrites are idempotent and safe)
  let batch = db.batch();
  let count = 0;
  let total = 0;

  for (let i = 1; i < rows.length; i++) {
    const cols = rows[i].split(",");
    if (cols.length !== headers.length) continue;

    const fire = {};
    headers.forEach((h, j) => { fire[h] = cols[j]; });

    // Parse acquisition time (HHMM UTC) + date into a Firestore Timestamp
    const timeStr = (fire.acq_time || "0000").trim().padStart(4, "0");
    const hours = timeStr.slice(0, 2);
    const mins = timeStr.slice(2, 4);
    const detectedAt = new Date(`${fire.acq_date}T${hours}:${mins}:00Z`);

    const lat = parseFloat(fire.latitude);
    const lng = parseFloat(fire.longitude);
    const frp = parseFloat(fire.frp);

    if (isNaN(lat) || isNaN(lng) || isNaN(frp)) continue;

    const docId = `${fire.latitude.trim()}_${fire.longitude.trim()}_${fire.acq_date}_${timeStr}`;
    const docRef = db.collection("fires").doc(docId);

    batch.set(docRef, {
      lat,
      lng,
      frp,
      detectedAt: admin.firestore.Timestamp.fromDate(detectedAt),
      source: "NASA_FIRMS",
    });

    count++;
    total++;

    if (count === BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }

  if (count > 0) await batch.commit();

  logger.info(`fetchAndStoreFires complete — wrote ${total} hotspots.`);
}

// ─── 2. Scheduled fetch (every 6 hours) ──────────────────────────────────────
exports.scheduledFetchFires = onSchedule({ schedule: "every 6 hours" }, async () => {
  await fetchAndStoreFires();
});

// ─── 3. Manual HTTP trigger (for testing in browser / Postman) ────────────────
// Requires x-admin-secret header matching ADMIN_SECRET env var.
exports.fetchFiresManual = onRequest({ timeoutSeconds: 540 }, async (req, res) => {
  const secret = process.env.ADMIN_SECRET;
  if (!secret || req.headers["x-admin-secret"] !== secret) {
    res.status(401).send("Unauthorized");
    return;
  }
  try {
    await fetchAndStoreFires();
    res.send("✅ Fire data fetched and stored successfully.");
  } catch (err) {
    logger.error("fetchFiresManual error", err);
    res.status(500).send("❌ Fetch failed — check function logs.");
  }
});

// ─── 4. Cleanup: delete fires older than 3 days ───────────────────────────────
async function cleanupOldFires() {
  // Firestore Timestamp comparison: fires where detectedAt < 3 days ago
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 3);
  const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

  const snapshot = await db.collection("fires")
    .where("detectedAt", "<", cutoffTs)
    .get();

  if (snapshot.empty) {
    logger.info("cleanupOldFires: nothing to delete.");
    return;
  }

  // Batch deletes (max 500 per batch)
  const BATCH_SIZE = 400;
  let batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    count++;
    if (count % BATCH_SIZE === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  if (count % BATCH_SIZE !== 0) await batch.commit();

  logger.info(`cleanupOldFires: deleted ${count} old fire documents.`);
}

// ─── 5. Scheduled cleanup (every 6 hours) ────────────────────────────────────
exports.scheduledCleanupFires = onSchedule({ schedule: "every 6 hours" }, async () => {
  await cleanupOldFires();
});

// ─── 6. Register user with farm location (used by test-register.html) ─────────
// Requires a valid Firebase ID token. The token UID must match the `id` field
// in the request body — prevents one user from overwriting another's document.
exports.registerUser = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      // Verify Firebase ID token
      const authHeader = req.headers.authorization || "";
      const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
      if (!idToken) {
        res.status(401).send("Missing Authorization header");
        return;
      }

      let decodedToken;
      try {
        decodedToken = await admin.auth().verifyIdToken(idToken);
      } catch {
        res.status(401).send("Invalid or expired ID token");
        return;
      }

      const { id, name, email, lat, lng, radius } = req.body;

      if (!id || !name || !email || lat == null || lng == null || radius == null) {
        res.status(400).send("Missing required fields: id, name, email, lat, lng, radius");
        return;
      }

      // Token UID must match the requested user document ID
      if (decodedToken.uid !== id) {
        res.status(403).send("Forbidden: token UID does not match id");
        return;
      }

      await db.collection("users").doc(id).set({
        name,
        email,
        farmLocation: {
          latitude: parseFloat(lat),
          longitude: parseFloat(lng),
        },
        radiusInKm: parseFloat(radius),
        createdAt: new Date().toISOString(),
      });

      res.status(201).send("User registered successfully.");
    } catch (err) {
      logger.error("registerUser error", err);
      res.status(500).send("Internal server error.");
    }
  });
});

// ─── 7. Notify devices when a new fire document is created ────────────────────
// Self-contained haversine — same formula as geo_utils.dart
function _haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371.0;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

exports.notifyDevicesOnNewFire = onDocumentCreated("fires/{fireId}", async (event) => {
  const fireId = event.params.fireId;
  const data = event.data?.data();

  if (!data) {
    logger.warn("notifyDevicesOnNewFire: empty fire doc", { fireId });
    return;
  }

  const { lat, lng } = data;
  if (lat == null || lng == null) {
    logger.warn("notifyDevicesOnNewFire: missing lat/lng", { fireId });
    return;
  }

  const devicesSnapshot = await db.collection("devices").get();
  if (devicesSnapshot.empty) {
    logger.info("notifyDevicesOnNewFire: no registered devices");
    return;
  }

  // Step 1: filter by validity + distance — pure in-memory, no I/O
  const candidates = [];
  for (const deviceDoc of devicesSnapshot.docs) {
    const device = deviceDoc.data();
    const { deviceId, fcmToken, farmLat, farmLng, radiusInKm } = device;
    if (!fcmToken || farmLat == null || farmLng == null || !deviceId) continue;
    const distKm = _haversineKm(farmLat, farmLng, lat, lng);
    if (distKm > (radiusInKm ?? 50)) continue;
    candidates.push({ ...device, distKm });
  }

  if (candidates.length === 0) {
    logger.info(`notifyDevicesOnNewFire: no devices in radius for ${fireId}`);
    return;
  }

  // Step 2: parallel dedup check — all reads fired at once, not sequentially
  const notifiedRefs = candidates.map((d) =>
    db.collection("fires").doc(fireId).collection("notifiedDevices").doc(d.deviceId)
  );
  const dedupSnaps = await Promise.all(notifiedRefs.map((r) => r.get()));

  // Step 3: send to non-deduped candidates
  const messaging = admin.messaging();
  const sends = [];

  for (let i = 0; i < candidates.length; i++) {
    if (dedupSnaps[i].exists) continue;

    const device = candidates[i];
    const distLabel = device.distKm.toFixed(1);

    const sendAndRecord = messaging.send({
      token: device.fcmToken,
      notification: {
        title: "🔥 Fire Alert",
        body: `Fire detected ${distLabel} km from your farm — tap to view`,
      },
      data: {
        type: "fire_alert",
        fireId,
        fireLat: String(lat),
        fireLng: String(lng),
      },
    })
      .then(() =>
        notifiedRefs[i].set({ notifiedAt: admin.firestore.FieldValue.serverTimestamp() })
      )
      .then(() => {
        logger.info(`Notified ${device.deviceId} for fire ${fireId} (${distLabel} km)`);
      })
      .catch((err) => {
        logger.error(`FCM failed for ${device.deviceId}`, { msg: err.message });
      });

    sends.push(sendAndRecord);
  }

  await Promise.all(sends);
  logger.info(`notifyDevicesOnNewFire done — ${sends.length} device(s) notified for ${fireId}`);
});

// ─── 8. State code lookup — rough bounding boxes for Indian states ─────────────
// Used by scoreFireRelevance so we never call an external vegetation API.
function _getStateCode(lat, lng) {
  // Ordered from smallest/most-distinct to largest to reduce false matches.
  const states = [
    { code: "GA", latMin: 14.9, latMax: 15.8, lngMin: 73.7, lngMax: 74.3 },
    { code: "JH", latMin: 21.9, latMax: 25.3, lngMin: 83.3, lngMax: 87.5 },
    { code: "CG", latMin: 17.8, latMax: 24.1, lngMin: 80.2, lngMax: 84.4 },
    { code: "OD", latMin: 17.8, latMax: 22.6, lngMin: 81.4, lngMax: 87.5 },
    { code: "WB", latMin: 21.6, latMax: 27.2, lngMin: 85.8, lngMax: 89.9 },
    { code: "TG", latMin: 15.8, latMax: 19.9, lngMin: 77.2, lngMax: 81.3 },
    { code: "KA", latMin: 11.6, latMax: 18.4, lngMin: 74.1, lngMax: 78.6 },
    { code: "AP", latMin: 12.6, latMax: 19.9, lngMin: 77.1, lngMax: 84.8 },
    { code: "TN", latMin: 8.1,  latMax: 13.6, lngMin: 76.2, lngMax: 80.3 },
    { code: "KL", latMin: 8.3,  latMax: 12.8, lngMin: 74.9, lngMax: 77.4 },
    { code: "GJ", latMin: 20.1, latMax: 24.7, lngMin: 68.2, lngMax: 74.5 },
    { code: "MP", latMin: 21.1, latMax: 26.9, lngMin: 74.0, lngMax: 82.8 },
    { code: "MH", latMin: 15.6, latMax: 22.0, lngMin: 72.6, lngMax: 80.9 },
    { code: "RJ", latMin: 23.0, latMax: 30.2, lngMin: 69.5, lngMax: 78.2 },
    { code: "UP", latMin: 23.9, latMax: 30.4, lngMin: 77.1, lngMax: 84.6 },
    { code: "HR", latMin: 27.6, latMax: 30.9, lngMin: 74.5, lngMax: 77.6 },
    { code: "PB", latMin: 29.5, latMax: 32.5, lngMin: 73.9, lngMax: 76.9 },
    { code: "HP", latMin: 30.4, latMax: 33.2, lngMin: 75.6, lngMax: 79.0 },
    { code: "UK", latMin: 28.7, latMax: 31.5, lngMin: 77.6, lngMax: 81.0 },
    { code: "BR", latMin: 24.3, latMax: 27.5, lngMin: 83.3, lngMax: 88.2 },
  ];

  for (const s of states) {
    if (lat >= s.latMin && lat <= s.latMax && lng >= s.lngMin && lng <= s.lngMax) {
      return s.code;
    }
  }
  return "MH"; // default — Maharashtra is the primary target region
}

// ─── 9. Cleanup: delete scoringLogs older than 7 days ────────────────────────
exports.scheduledCleanupScoringLogs = onSchedule({ schedule: "every 6 hours" }, async () => {
  try {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 7);
    const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);

    const snapshot = await db.collection("scoringLogs")
      .where("scoredAt", "<", cutoffTs)
      .get();

    if (snapshot.empty) {
      logger.info("scheduledCleanupScoringLogs: nothing to delete.");
      return;
    }

    let batch = db.batch();
    let count = 0;

    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      count++;
      if (count % BATCH_SIZE === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    if (count % BATCH_SIZE !== 0) await batch.commit();

    logger.info(`scheduledCleanupScoringLogs: deleted ${count} old scoringLog documents.`);
  } catch (err) {
    logger.error("scheduledCleanupScoringLogs: error", { msg: err.message });
    // Never throws — failure must not affect other functions
  }
});

// ─── 10. Score fire relevance for all (fire, device) pairs ────────────────────
// Runs every 6 hours. Writes to scoringLogs/{autoId}.
// Score = (customFireIndex × 0.5) + (vegetationScore × 0.3) + (normFrp × 0.2)
// Engine failures are caught and logged — never affect other functions.
exports.scoreFireRelevance = onSchedule({ schedule: "every 6 hours", timeoutSeconds: 540 }, async () => {
  try {
    const [firesSnap, devicesSnap] = await Promise.all([
      db.collection("fires").get(),
      db.collection("devices").get(),
    ]);

    if (firesSnap.empty || devicesSnap.empty) {
      logger.info("scoreFireRelevance: no fires or devices — nothing to score");
      return;
    }

    const fires = firesSnap.docs.map((d) => ({ _docId: d.id, ...d.data() }));
    const devices = devicesSnap.docs.map((d) => ({ _docId: d.id, ...d.data() }));

    const logs = [];
    let weatherCalls = 0; // counts actual Tomorrow.io fetches (one per in-radius fire)

    for (const fire of fires) {
      if (fire.lat == null || fire.lng == null) continue;

      const stateCode = _getStateCode(fire.lat, fire.lng);
      let fireRisk = null; // computed once per fire, reused across devices

      for (const device of devices) {
        try {
          const { farmLat, farmLng, radiusInKm } = device;
          if (farmLat == null || farmLng == null) continue;

          const distKm = _haversineKm(farmLat, farmLng, fire.lat, fire.lng);
          if (distKm > (radiusInKm ?? 50)) continue;

          // Lazy-compute fire risk — calls Tomorrow.io once per fire coordinate
          if (!fireRisk) {
            weatherCalls++;
            fireRisk = await computeFireRisk(fire.lat, fire.lng, stateCode);
            if (!fireRisk) continue; // Tomorrow.io failed — skip all devices for this fire
          }

          const frpNorm = Math.min((fire.frp ?? 0) / 100, 1) * 100;
          const score =
            fireRisk.customFireIndex * 0.5 +
            fireRisk.vegetationScore * 0.3 +
            frpNorm * 0.2;

          logs.push({
            fireId: fire._docId,
            deviceId: device.deviceId ?? device._docId,
            distKm,
            frp: fire.frp ?? 0,
            customFireIndex: fireRisk.customFireIndex,
            vegetationScore: fireRisk.vegetationScore,
            score,
            scoredAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (pairErr) {
          logger.error("scoreFireRelevance: pair error", {
            fireId: fire._docId,
            msg: pairErr.message,
          });
          // Continue to next pair — one failure must not abort the run
        }
      }
    }

    // Batch-write all scoring log documents
    let batch = db.batch();
    let count = 0;
    for (const log of logs) {
      batch.set(db.collection("scoringLogs").doc(), log);
      count++;
      if (count === BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();

    logger.info(`scoreFireRelevance: wrote ${logs.length} log entries for ${fires.length} fires / ${devices.length} devices (Tomorrow.io calls: ${weatherCalls})`);
  } catch (err) {
    logger.error("scoreFireRelevance: top-level failure", { msg: err.message });
    // Never throw — failure must not affect scheduledFetchFires or notifyDevicesOnNewFire
  }
});
