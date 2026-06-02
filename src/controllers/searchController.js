const { query } = require('../config/database');
const { createError } = require('../middleware/errorHandler');

async function searchShops(req, res, next) {
  try {
    const { q, lat, lng, radius, category, source } = req.query;

    if (!lat || !lng) {
      throw createError(400, 'lat und lng sind erforderlich');
    }

    const results = [];

    const params = [];
    let paramIndex = 1;

    const radiusMeters = parseFloat(radius || '5000');
    const userLat = parseFloat(lat);
    const userLng = parseFloat(lng);

    const includeCompanies = !source || source === 'all' || source === 'companies';

    if (includeCompanies) {
      const companyConditions = [
        `(c.service_radius_km IS NULL OR c.service_radius_km < 0 OR ST_DWithin(c.location, ST_MakePoint($${paramIndex}, $${paramIndex + 1})::geography, $${paramIndex + 2}))`,
      ];
      const companyParams = [userLng, userLat, radiusMeters];
      let companyParamIndex = 4;

      if (q) {
        companyConditions.push(`(c.name ILIKE $${companyParamIndex} OR c.description ILIKE $${companyParamIndex})`);
        companyParams.push(`%${q}%`);
      }

      if (category && category !== 'Alle') {
        companyConditions.push(`cat.name = $${companyParamIndex + 1}`);
        companyParams.push(category);
      }

      const companySql = `
        SELECT
          c.id, c.name, c.description, c.address, c.latitude, c.longitude,
          c.phone_number, c.email, c.website, c.price_level, c.average_rating,
          c.review_count, c.view_count, c.created_at,
          cat.name AS category,
          'company' AS source_type,
          ST_Distance(c.location, ST_MakePoint($1, $2)::geography) AS distance_m
        FROM companies c
        LEFT JOIN categories cat ON c.category_id = cat.id
        WHERE ${companyConditions.join(' AND ')}
        ORDER BY distance_m ASC
        LIMIT 50
      `;

      const companyResult = await query(companySql, [...companyParams.slice(0, 3), ...companyParams.slice(3)]);
      results.push(...companyResult.rows.map((r) => ({
        id: r.id,
        name: r.name,
        description: r.description,
        address: r.address,
        latitude: parseFloat(r.latitude),
        longitude: parseFloat(r.longitude),
        phoneNumber: r.phone_number,
        email: r.email,
        website: r.website,
        priceLevel: r.price_level,
        rating: r.average_rating ? parseFloat(r.average_rating) : null,
        reviewCount: r.review_count,
        viewCount: r.view_count,
        category: r.category,
        sourceType: r.source_type,
        distanceM: Math.round(parseFloat(r.distance_m)),
      })));
    }

    res.json(results);
  } catch (err) {
    next(err);
  }
}

module.exports = { searchShops };
