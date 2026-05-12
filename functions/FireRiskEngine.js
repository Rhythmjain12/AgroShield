const axios = require("axios");
const logger = require("firebase-functions/logger");
require("dotenv").config();

// ─── Static vegetation flammability fallback by Indian state code ─────────────
// Used when SoilGrids API is unavailable. Higher = more flammable.
const _vegetationScores = {
  MH: 65, MP: 70, CG: 80, OD: 75, JH: 72, RJ: 55, GJ: 50,
  UP: 60, HR: 55, PB: 58, UK: 78, HP: 76, BR: 58, WB: 68,
  AP: 65, TG: 65, KA: 70, TN: 62, KL: 75, GA: 80,
};

function _getStaticVegetationScore(stateCode) {
  return _vegetationScores[stateCode] ?? 60;
}

/**
 * Fetch soil composition from SoilGrids (ISRIC) for a coordinate.
 * Returns a fire-spread risk score (0–100): sandy + organic soil = high risk.
 * Falls back to null on any error so the caller can use the static lookup.
 *
 * SoilGrids units: clay g/kg, sand g/kg, soc dg/kg (soil organic carbon)
 */
async function getSoilScore(lat, lon) {
  const url =
    `https://rest.isric.org/soilgrids/v2.0/properties/query` +
    `?lon=${lon}&lat=${lat}` +
    `&property=clay&property=sand&property=soc` +
    `&depth=0-5cm&value=mean`;

  try {
    const response = await axios.get(url, { timeout: 8000 });
    const layers = response.data?.properties?.layers ?? [];

    const clayLayer = layers.find((l) => l.name === "clay");
    const sandLayer = layers.find((l) => l.name === "sand");
    const socLayer  = layers.find((l) => l.name === "soc");

    const clay = clayLayer?.depths?.[0]?.values?.mean ?? null; // g/kg
    const sand = sandLayer?.depths?.[0]?.values?.mean ?? null; // g/kg
    const soc  = socLayer?.depths?.[0]?.values?.mean  ?? 0;   // dg/kg

    if (clay === null || sand === null) return null;

    // Sandy soils dry out quickly and spread fire easily.
    // Clay soils retain moisture and resist fire spread.
    // Organic carbon provides fuel but also indicates vegetated/moist land —
    // moderate contribution, capped so it doesn't dominate.
    const sandFrac = Math.min(sand / 1000, 1);         // 0–1
    const clayFrac = Math.min(clay / 1000, 1);         // 0–1
    const socPct   = Math.min((soc / 100) / 5, 1);     // normalise: 5 % OC = max

    const score = Math.round(
      sandFrac          * 50 +  // 50 pts: sand = dry = high fire spread
      (1 - clayFrac)    * 30 +  // 30 pts: low clay = poor moisture retention
      socPct            * 20    // 20 pts: organic carbon = fuel availability
    );

    return Math.max(0, Math.min(score, 100));
  } catch (err) {
    logger.warn("FireRiskEngine: SoilGrids unavailable — using static fallback", {
      msg: err.message,
    });
    return null;
  }
}

/**
 * Fetch core weather data (temperature, humidity, wind) from Tomorrow.io.
 * Uses the /v4/weather/realtime endpoint (timesteps=current was removed from forecast).
 * windSpeed is returned in m/s; converted to km/h here for calculateCustomFireIndex.
 */
async function fetchWeatherData(lat, lon) {
  const apiKey = process.env.TOMORROW_API_KEY;
  const url = `https://api.tomorrow.io/v4/weather/realtime?location=${lat},${lon}&apikey=${apiKey}&fields=temperature,humidity,windSpeed&units=metric`;

  try {
    const response = await axios.get(url);
    const values = response.data.data.values;

    return {
      temperatureC: values.temperature,
      humidity: values.humidity,
      windKmh: values.windSpeed * 3.6, // m/s → km/h
    };
  } catch (error) {
    logger.error("FireRiskEngine: failed to fetch weather data", { msg: error.message });
    return null;
  }
}

/**
 * Calculate Custom Fire Index (simplified Fosberg)
 */
function calculateCustomFireIndex(tempC, humidity, windKmh) {
  const tempF = tempC * 9 / 5 + 32;
  const windMph = windKmh / 1.609;

  let EMC = 0;
  if (humidity < 10) {
    EMC = 0.03229 + 0.281073 * humidity - 0.000578 * humidity * tempF;
  } else if (humidity <= 50) {
    EMC = 2.22749 + 0.160107 * humidity - 0.014784 * tempF;
  } else {
    EMC = 21.0606 + 0.005565 * humidity ** 2 - 0.00035 * humidity * tempF - 0.483199 * humidity;
  }

  EMC = Math.max(0, EMC);

  const eta =
    1 -
    2 * (EMC / 30) +
    1.5 * Math.pow(EMC / 30, 2) -
    0.5 * Math.pow(EMC / 30, 3);

  const ffwi = eta * (Math.sqrt(1 + Math.pow(windMph, 2)) / 0.3002);
  const fireIndex = Math.max(0, Math.min(ffwi, 100));

  return fireIndex;
}

/**
 * Compute fire risk for a coordinate.
 * @param {number} lat
 * @param {number} lon
 * @param {string} stateCode - 2-letter ISO state code (e.g. "MH")
 * @returns {{ customFireIndex: number, vegetationScore: number, soilSource: string } | null}
 */
async function computeFireRisk(lat, lon, stateCode) {
  // Weather and soil can be fetched in parallel — neither depends on the other.
  const [weather, soilScore] = await Promise.all([
    fetchWeatherData(lat, lon),
    getSoilScore(lat, lon),
  ]);

  if (!weather) return null;

  const fireIndex = calculateCustomFireIndex(
    weather.temperatureC,
    weather.humidity,
    weather.windKmh
  );

  // Use live SoilGrids score if available; fall back to static state-level lookup.
  const vegetationScore = soilScore ?? _getStaticVegetationScore(stateCode);
  const soilSource = soilScore !== null ? "soilgrids" : "static";

  return {
    customFireIndex: fireIndex,
    vegetationScore,
    soilSource, // logged to scoringLogs for validation tracking
  };
}

module.exports = {
  computeFireRisk,
};
