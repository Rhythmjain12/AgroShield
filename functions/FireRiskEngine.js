const axios = require("axios");
require('dotenv').config();

//Fetching Frosberg Index
async function FetchFrosberg(lat,lon)
{
    const FrosbergKEY = process.env.TOMORROW_API_KEY;
    const FrosbergData  = await axios.get("");
};