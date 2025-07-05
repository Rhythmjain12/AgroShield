// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");
const { onSchedule } = require("firebase-functions/scheduler");
const cors = require("cors")({ origin: true });

// The Firebase Admin SDK to access Firestore.
admin.initializeApp();
const db = admin.firestore();

//1. Making the cloud function fetch fires
async function fetchAndStoreFires()
{
  const mapKey = "604c0818df784c6f267406aabbc7ee06";
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
Tried writing a code where you enter a text and it gets uploaded to firestore
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

