const env = require('../config/env');
const { createError } = require('../middleware/errorHandler');

async function proxyGemini(req, res, next) {
  try {
    const { model, contents, generationConfig } = req.body;

    if (!contents || !Array.isArray(contents)) {
      throw createError(400, '"contents" Array ist erforderlich');
    }

    const modelName = model || 'gemini-2.0-flash';

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${env.geminiApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents,
          generationConfig: generationConfig || { temperature: 0.7, maxOutputTokens: 800 },
        }),
      }
    );

    const data = await response.json();

    if (!response.ok) {
      console.error('Gemini API error:', data);
      throw createError(response.status, data.error?.message || 'Gemini API Fehler');
    }

    res.json(data);
  } catch (err) {
    next(err);
  }
}

async function proxyPlaces(req, res, next) {
  try {
    const { input, inputtype, fields } = req.body;

    if (!input) {
      throw createError(400, '"input" ist erforderlich');
    }

    const response = await fetch(
      `https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${encodeURIComponent(input)}&inputtype=${inputtype || 'textquery'}&fields=${encodeURIComponent(fields || 'place_id,name,rating,user_ratings_total,price_level,formatted_address,geometry')}&key=${env.googleMapsApiKey}`
    );

    const data = await response.json();

    if (!response.ok) {
      console.error('Google Places API error:', data);
      throw createError(response.status, data.error_message || 'Google Places API Fehler');
    }

    res.json(data);
  } catch (err) {
    next(err);
  }
}

async function proxyPlacesDetails(req, res, next) {
  try {
    const { place_id, fields } = req.body;

    if (!place_id) {
      throw createError(400, '"place_id" ist erforderlich');
    }

    const response = await fetch(
      `https://maps.googleapis.com/maps/api/place/details/json?place_id=${encodeURIComponent(place_id)}&fields=${encodeURIComponent(fields || 'rating,user_ratings_total,price_level,formatted_address,geometry,website,international_phone_number')}&key=${env.googleMapsApiKey}`
    );

    const data = await response.json();

    if (!response.ok) {
      console.error('Google Places Details API error:', data);
      throw createError(response.status, data.error_message || 'Google Places Details API Fehler');
    }

    res.json(data);
  } catch (err) {
    next(err);
  }
}

async function proxyNominatim(req, res, next) {
  try {
    const { q, format, limit, viewbox, bounded, addressdetails, extratags } = req.body;

    if (!q) {
      throw createError(400, '"q" (query) ist erforderlich');
    }

    const params = new URLSearchParams({
      q,
      format: format || 'jsonv2',
      limit: String(limit || 20),
      addressdetails: String(addressdetails !== undefined ? addressdetails : 1),
      extratags: String(extratags !== undefined ? extratags : 1),
    });

    if (viewbox) params.set('viewbox', viewbox);
    if (bounded) params.set('bounded', '1');

    const response = await fetch(
      `https://nominatim.openstreetmap.org/search?${params.toString()}`,
      {
        headers: {
          'User-Agent': 'ShopFinder/1.0',
          'Accept-Language': 'de',
        },
      }
    );

    const data = await response.json();

    if (!response.ok) {
      throw createError(response.status, 'Nominatim API Fehler');
    }

    res.json(data);
  } catch (err) {
    next(err);
  }
}

async function proxyGrok(req, res, next) {
  try {
    const { model, input, temperature, maxOutputTokens } = req.body;

    if (!input) {
      throw createError(400, '"input" ist erforderlich');
    }

    const modelName = model || 'grok-mini';

    const response = await fetch('https://api.openai.com/v1/responses', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.grokApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: modelName,
        input,
        temperature: temperature || 0.2,
        max_output_tokens: maxOutputTokens || 400,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('Grok API error:', data);
      throw createError(response.status, data.error?.message || 'Grok API Fehler');
    }

    res.json(data);
  } catch (err) {
    next(err);
  }
}

module.exports = { proxyGemini, proxyPlaces, proxyPlacesDetails, proxyNominatim, proxyGrok };
