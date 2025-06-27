// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");

// The Firebase Admin SDK to access Firestore.
admin.initializeApp();
const db = admin.firestore();

// Making the cloud function fetch fires
exports.fetchFires = onRequest(async (req, res) => {
  const mapKey = "604c0818df784c6f267406aabbc7ee06";
  const sourceSatellite = "VIIRS_SNPP_NRT";
  const bBox = "68,6,97,37"; // for India
  const dayRange = "3"; // changed from "1" to "3"
  const baseUrl = `https://firms.modaps.eosdis.nasa.gov/api/area/csv/${mapKey}/${sourceSatellite}/${bBox}/${dayRange}`;

  try {
    const response = await axios.get(baseUrl); // fetching NASA CSV data
    const rows = response.data.split("\n");
    const headers = rows[0].split(",");

    for (let i = 1; i < rows.length; i++) {
      const row = rows[i].split(",");
      if (row.length !== headers.length) continue;

      const fire = {};
      for (let j = 0; j < headers.length; j++) {
        fire[headers[j]] = row[j];
      }

      console.log("🔥 Raw fire row:", fire);

      const fireData = {
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

      if (!docSnap.exists) {
        console.log("✅ Writing new fire to Firestore...");
        await docRef.set(fireData);
      } else {
        console.log("⚠️ Duplicate fire skipped.");
      }
    }

    res.send("Fire data fetched, parsed, and stored successfully.");
  } catch (err) {
    console.error("❌ Error fetching from NASA:", err.message);
    res.status(500).send("NASA API request failed.");
  }
});



/* Tried writing a code where you enter a text and it gets uploaded to firestore
exports.addMessage = onRequest(async(req,res) => {
  // Grab the text parameter.
  const original = req.query.text;
  // Push the new message into Firestore using the Firebase Admin SDK.
  const writeResult = await getFirestore()
  .collection("messages")
  .add({original: original});
  // Send back a message that we've successfully written the message
  res.json({result:`Message with ID: ${writeResult.id} added.`});
});
*/

