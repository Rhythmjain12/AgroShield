// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");
const { onSchedule } = require("firebase-functions/scheduler");
const cors = require("cors")({ origin: true });
require('dotenv').config();
const { computeFireRisk } = require("./FireRiskEngine");



// The Firebase Admin SDK to access Firestore.
admin.initializeApp();
const db = admin.firestore();

//1. Making the cloud function fetch fires
async function fetchAndStoreFires()
{
  const mapKey = process.env.NASA_FIRMS_API_KEY;
  const sourceSatellite = "VIIRS_SNPP_NRT";
  const bBox = "68,6,97,37"; // for India
  const dayRange = "3"; // changed from "1" to "3"
  const baseUrl = `https://firms.modaps.eosdis.nasa.gov/api/area/csv/${mapKey}/${sourceSatellite}/${bBox}/${dayRange}`;

  try 
  {
    const response = await axios.get(baseUrl); // fetching NASA CSV data
    const rows = response.data.split("\n");
    const headers = rows[0].split(",");

    for (let i = 1; i < rows.length; i++)
    {
      const row = rows[i].split(",");
      if (row.length !== headers.length) continue;

      const fire = {};
      for (let j = 0; j < headers.length; j++)
      {
        fire[headers[j]] = row[j];
      }

      console.log("🔥 Raw fire row:", fire);

      const fireData = 
      {
        latitude: parseFloat(fire.latitude),
        longitude: parseFloat(fire.longitude),
        brightness: parseFloat(fire.bright_ti4),
        date: fire.acq_date,
        time: fire.acq_time.trim(), // trim to avoid \r issues
        frp: parseFloat(fire.frp),
        daynight: fire.daynight,
      };

      console.log("🧾 Parsed fireData:", fireData);

      const docId = `${fire.latitude}_${fire.longitude}_${fire.acq_date}_${fire.acq_time.trim()}`;
      console.log("🆔 Checking document ID:", docId);

      const docRef = db.collection("fires").doc(docId);
      const docSnap = await docRef.get();

      console.log("📄 Exists already?", docSnap.exists);

      if (!docSnap.exists)
      {
        console.log("✅ Writing new fire to Firestore...");
        await docRef.set(fireData);
      } else
      {
        console.log("⚠️ Duplicate fire skipped.");
      }
    }
  }
  catch (err) {
    console.error("❌ Error inside fetchAndStoreFires:", err.message);
  }
};

//2.Scheduled fetch function
exports.scheduledFetchFire = onSchedule({ schedule:"every 6 hours"}, async () => {
  await fetchAndStoreFires();
});

//3. Manual fetch function (for testing in browser/Postman)
exports.fetchFiresManual = onRequest(async (req, res) => {
  try {
    await fetchAndStoreFires();
    res.send("Fire data fetched, parsed, and stored successfully.");
  } catch (err) {
    console.error("❌ Error in manual fetch:", err.message);
    res.status(500).send("NASA API request failed.");
  }
});

//Cleanup fucntion for deleting data older than 3 day
async function cleanupOldFires()
{
  const cutoffDateObj = new Date(); // made a date type object
  cutoffDateObj.setDate(cutoffDateObj.getDate() - 3); // got todays date, subtracted 3 days and set it to the object
  const cutoffDate = cutoffDateObj.toISOString().slice(0, 10); //using ISOS instead of string() to convert from date type to string type with correct formating
  // using slice to keep only first 10 digits which is the date and not the time mentioned later when using getdate()
  const snapshot = await db.collection("fires")
  .where("date", "<", cutoffDate)
  .get();
  if (snapshot.empty) {
    console.log("No old documents to delete.");
    return;
  }
  
  for (const doc of snapshot.docs) {
    await doc.ref.delete();
    console.log(`🔥 Deleted old fire: ${doc.id}`);
  }  
};

//Scheduled cleanup function
exports.scheduledCleanupFires = onSchedule({ schedule:"every 6 hours"}, async () => {
  await cleanupOldFires();
});

// 🚀 4. Register user with farm location and radius
exports.registerUser = onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { id, name, email, lat, lng, radius } = req.body;

      if (!id || !name || !email || !lat || !lng || !radius) {
        res.status(400).send("Missing required fields.");
        return;
      }

      const userRef = db.collection("users").doc(id);

      const userData = {
        name,
        email,
        farmLocation: {
          latitude: parseFloat(lat),
          longitude: parseFloat(lng),
        },
        radiusInKm: parseFloat(radius),
        createdAt: new Date().toISOString(),
      };

      await userRef.set(userData);

      res.status(201).send("User registered successfully.");
    } catch (err) {
      console.error("❌ Error in registerUser:", err.message);
      res.status(500).send("Internal server error.");
    }
  });
});





/*
forecastCloudFunction.js
-----------------------
Firebase Cloud Function that fetches **hourly + daily** forecasts from
Tomorrow.io for a user‑supplied GPS point and stores them in Firestore
under `forecasts/{userId}/hourly/{timestamp}` and
`forecasts/{userId}/daily/{timestamp}`.

Deployment steps (once):
```bash
# 1 Set your Tomorrow.io API key in function config (safer than env var):
firebase functions:config:set tomorrow.key="YOUR_TOMORROW_API_KEY"

# 2 Deploy
firebase deploy --only functions
```

HTTP usage (body JSON):
```json
{
  "lat": 28.6139,
  "lon": 77.2090,
  "userId": "abc123"
}
```
Returns `200 OK` when forecasts are written/updated.
*/


action: "https://api.tomorrow.io/v4/weather/forecast";

// Grab API key from Functions config (set via `firebase functions:config:set`)
const TOMORROW_API_KEY = process.env.TOMORROW_API_KEY ||
  (process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG).tomorrow?.key : null) ||
  null;

if (!TOMORROW_API_KEY) {
  logger.warn("Tomorrow.io API key not found. Set with `firebase functions:config:set tomorrow.key=...`");
}

// Common forecast params
const TIMESTEPS = "1h,1d"; // hourly & daily in one request
const UNITS = "metric";    // °C, m/s, mm, hPa
const FIELDS = [
  "temperature",
  "temperatureApparent",
  "precipitationIntensity",
  "precipitationType",
  "snowAccumulation",
  "humidity",
  "windSpeed",
  "windDirection",
  "cloudCover",
  "pressureSeaLevel",
  "visibility",
  "uvIndex",
  "weatherCode",
].join(",");

/**
 * Fetch forecast from Tomorrow.io and write to Firestore.
 * @param {number} lat  Latitude
 * @param {number} lon  Longitude
 * @param {string} userId  UID / custom identifier
 */
async function fetchAndStoreWeather(lat, lon, userId) {
  const qs = new URLSearchParams({
    location: `${lat},${lon}`,
    timesteps: TIMESTEPS,
    units: UNITS,
    fields: FIELDS,
    apikey: TOMORROW_API_KEY,
  });

  const url = `https://api.tomorrow.io/v4/weather/forecast?${qs.toString()}`;

  let data;
  try {
    const { data: resp } = await axios.get(url, { timeout: 10000 });
    data = resp;
  } catch (err) {
    logger.error("Tomorrow.io request failed", { msg: err.message });
    throw new Error("Failed to fetch weather");
  }

  if (!data?.timelines) {
    throw new Error("Unexpected Tomorrow.io response format");
  }

  const batch = db.batch();
  const userRef = db.collection("forecasts").doc(userId);

  // Helper: write each entry
  const writeEntries = (entries, sub) => {
    for (const e of entries) {
      const ts = e.time; // ISO8601
      const docRef = userRef.collection(sub).doc(ts);
      batch.set(docRef, e.values, { merge: true });
    }
  };

  writeEntries(data.timelines.hourly || [], "hourly");
  writeEntries(data.timelines.daily || [], "daily");

  await batch.commit();
}

exports.fetchWeatherForecast = onRequest(async (req, res) => {
  const { lat, lon, userId } = req.body || {};

  if (
    typeof lat !== "number" ||
    typeof lon !== "number" ||
    !userId ||
    !TOMORROW_API_KEY
  ) {
    res.status(400).send("Missing lat, lon, userId, or API key");
    return;
  }

  try {
    await fetchAndStoreWeather(lat, lon, userId);
    res.send("Forecast stored / updated");
  } catch (err) {
    logger.error("fetchWeatherForecast error", err);
    res.status(500).send("Internal error");
  }
});

/* ============================================================
 * OPTIONAL CLEANUP: delete forecasts older than now (keeps docs
 * only for timestamps in the future). Uncomment if desired.
 *
const { onSchedule } = require("firebase-functions/scheduler");

async function cleanupOldForecasts() {
  const nowIso = new Date().toISOString();
  const users = await db.collection("forecasts").listDocuments();
  for (const userRef of users) {
    for (const col of ["hourly", "daily"]) {
      const snap = await userRef.collection(col).where(admin.firestore.FieldPath.documentId(), "<", nowIso).get();
      snap.forEach((doc) => doc.ref.delete());
    }
  }
}

exports.scheduledCleanupForecasts = onSchedule({ schedule: "every 24 hours" }, cleanupOldForecasts);
*/

