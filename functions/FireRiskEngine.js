const axios = require("axios");
require("dotenv").config();

/**
 * Fetch core weather data (temperature, humidity, wind) from Tomorrow.io
 */
async function fetchWeatherData(lat, lon) {
  const apiKey = process.env.TOMORROW_API_KEY;
  const url = `https://api.tomorrow.io/v4/weather/forecast?location=${lat},${lon}&apikey=${apiKey}&fields=temperature,humidity,windSpeed&timesteps=current`;

  try {
    const response = await axios.get(url);
    const data = response.data.timelines[0].intervals[0].values;

    return {
      temperatureC: data.temperature,
      humidity: data.humidity,
      windKmh: data.windSpeed,
    };
  } catch (error) {
    console.error("Failed to fetch weather data:", error.message);
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

  EMC = Math.max(0, EMC); // Clamp to prevent negatives

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
 * Placeholder for Vegetation Score (to be implemented with vegetation API)
 */
async function fetchVegetationType(lat, lon) {
  // TODO: Replace with real API URL and key
  const vegetationApiKey = process.env.VEGETATION_API_KEY;
  const vegetationUrl = `https://your-vegetation-api.com/query?lat=${lat}&lon=${lon}&key=${vegetationApiKey}`;

  try {
    const response = await axios.get(vegetationUrl);
    const vegetationType = response.data.type;

    // Sample scoring logic — you can improve this
    const scores = {
      grassland: 100,
      forest: 80,
      shrubland: 70,
      cropland: 60,
      wetland: 10,
      urban: 0,
    };

    return scores[vegetationType.toLowerCase()] || 50;
  } catch (error) {
    console.error("Failed to fetch vegetation type:", error.message);
    return 50; // default
  }
}

/**
 * Public function to export for other modules
 */
async function computeFireRisk(lat, lon) {
  const weather = await fetchWeatherData(lat, lon);
  if (!weather) return null;

  const fireIndex = calculateCustomFireIndex(
    weather.temperatureC,
    weather.humidity,
    weather.windKmh
  );

  const vegetationScore = await fetchVegetationType(lat, lon);

  return {
    customFireIndex: fireIndex,
    vegetationScore: vegetationScore,
  };
}

module.exports = {
  computeFireRisk,
};
