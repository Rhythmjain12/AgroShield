// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");
const cors = require("cors")({ origin: true });
require("dotenv").config();

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
exports.fetchFiresManual = onRequest({ timeoutSeconds: 540 }, async (req, res) => {
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
exports.registerUser = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { id, name, email, lat, lng, radius } = req.body;

      if (!id || !name || !email || lat == null || lng == null || radius == null) {
        res.status(400).send("Missing required fields: id, name, email, lat, lng, radius");
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

  const messaging = admin.messaging();
  const sends = [];

  for (const deviceDoc of devicesSnapshot.docs) {
    const device = deviceDoc.data();
    const { deviceId, fcmToken, farmLat, farmLng, radiusInKm } = device;

    if (!fcmToken || farmLat == null || farmLng == null) continue;

    const distKm = _haversineKm(farmLat, farmLng, lat, lng);
    const radius = radiusInKm ?? 50;
    if (distKm > radius) continue;

    // Deduplication: skip if this device was already notified for this fire
    const notifiedRef = db
      .collection("fires").doc(fireId)
      .collection("notifiedDevices").doc(deviceId);
    const alreadyNotified = await notifiedRef.get();
    if (alreadyNotified.exists) continue;

    const distLabel = distKm.toFixed(1);

    const sendAndRecord = messaging.send({
      token: fcmToken,
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
        notifiedRef.set({ notifiedAt: admin.firestore.FieldValue.serverTimestamp() })
      )
      .then(() => {
        logger.info(`Notified ${deviceId} for fire ${fireId} (${distLabel} km)`);
      })
      .catch((err) => {
        logger.error(`FCM failed for ${deviceId}`, { msg: err.message });
      });

    sends.push(sendAndRecord);
  }

  await Promise.all(sends);
  logger.info(`notifyDevicesOnNewFire done — ${sends.length} device(s) in radius for ${fireId}`);
});
