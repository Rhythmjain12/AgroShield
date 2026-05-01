const axios = require("axios");
const logger = require("firebase-functions/logger");
require("dotenv").config();

// ─── Static vegetation flammability scores by Indian state code ───────────────
// Higher = more flammable. Default 60 for unknown states.
const _vegetationScores = {
  MH: 65, MP: 70, CG: 80, OD: 75, JH: 72, RJ: 55, GJ: 50,
  UP: 60, HR: 55, PB: 58, UK: 78, HP: 76, BR: 58, WB: 68,
  AP: 65, TG: 65, KA: 70, TN: 62, KL: 75, GA: 80,
};

function _getVegetationScore(stateCode) {
  return _vegetationScores[stateCode] ?? 60;
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
 * @returns {{ customFireIndex: number, vegetationScore: number } | null}
 */
async function computeFireRisk(lat, lon, stateCode) {
  const weather = await fetchWeatherData(lat, lon);
  if (!weather) return null;

  const fireIndex = calculateCustomFireIndex(
    weather.temperatureC,
    weather.humidity,
    weather.windKmh
  );

  const vegetationScore = _getVegetationScore(stateCode);

  return {
    customFireIndex: fireIndex,
    vegetationScore,
  };
}

module.exports = {
  computeFireRisk,
};
