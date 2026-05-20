const { query } = require('../config/database');
const { createError } = require('../middleware/errorHandler');

async function list(req, res, next) {
  try {
    const { category, search, lat, lng } = req.query;
    const params = [];
    const conditions = [];
    let paramIndex = 1;

    if (category && category !== 'Alle') {
      conditions.push(`cat.name = $${paramIndex++}`);
      params.push(category);
    }

    if (search) {
      conditions.push(`(s.title ILIKE $${paramIndex} OR s.description ILIKE $${paramIndex})`);
      params.push(`%${search}%`);
      paramIndex++;
    }

    const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const sql = `
      SELECT
        s.id, s.title, s.description, s.price, s.price_unit,
        s.location, s.latitude, s.longitude,
        s.average_rating, s.review_count, s.created_at,
        cat.name AS category,
        u.id AS provider_id, u.display_name AS provider_name
      FROM services s
      LEFT JOIN categories cat ON s.category_id = cat.id
      LEFT JOIN users u ON s.provider_id = u.id
      ${where}
      ORDER BY s.created_at DESC
      LIMIT 50
    `;

    const result = await query(sql, params);
    res.json(result.rows.map(mapService));
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const { id } = req.params;
    const result = await query(
      `SELECT
        s.*, cat.name AS category,
        u.id AS provider_id, u.display_name AS provider_name
      FROM services s
      LEFT JOIN categories cat ON s.category_id = cat.id
      LEFT JOIN users u ON s.provider_id = u.id
      WHERE s.id = $1`,
      [id]
    );
    if (result.rows.length === 0) {
      throw createError(404, 'Service nicht gefunden');
    }
    res.json(mapService(result.rows[0]));
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  try {
    const {
      title, description, category, price, priceUnit,
      location, latitude, longitude, tags,
    } = req.body;

    if (!title || !description || !category || price === undefined || !location) {
      throw createError(400, 'title, description, category, price und location sind erforderlich');
    }

    const catResult = await query('SELECT id FROM categories WHERE name = $1', [category]);
    if (catResult.rows.length === 0) {
      throw createError(400, `Ungültige Kategorie: ${category}`);
    }
    const categoryId = catResult.rows[0].id;

    let locationSql = 'NULL';
    const params = [
      req.user.id, title, description, categoryId, price,
      priceUnit || '€', location, latitude || null, longitude || null,
      tags ? JSON.stringify(tags) : null,
    ];

    if (latitude && longitude) {
      locationSql = 'ST_MakePoint($10, $11)::geography';
      params.push(parseFloat(longitude), parseFloat(latitude));
    }

    const result = await query(
      `INSERT INTO services
        (provider_id, title, description, category_id, price, price_unit,
         location, latitude, longitude, location_geo)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, ${locationSql})
       RETURNING id`,
      params
    );

    const service = await query(
      `SELECT s.*, cat.name AS category, u.id AS provider_id, u.display_name AS provider_name
       FROM services s
       LEFT JOIN categories cat ON s.category_id = cat.id
       LEFT JOIN users u ON s.provider_id = u.id
       WHERE s.id = $1`,
      [result.rows[0].id]
    );

    res.status(201).json(mapService(service.rows[0]));
  } catch (err) {
    next(err);
  }
}

async function update(req, res, next) {
  try {
    const { id } = req.params;
    const existing = await query('SELECT * FROM services WHERE id = $1', [id]);
    if (existing.rows.length === 0) {
      throw createError(404, 'Service nicht gefunden');
    }
    if (existing.rows[0].provider_id !== req.user.id) {
      throw createError(403, 'Nur der Anbieter kann den Service bearbeiten');
    }

    const fields = ['title', 'description', 'price', 'price_unit', 'location', 'latitude', 'longitude'];
    const updates = [];
    const params = [];
    let paramIndex = 1;

    for (const field of fields) {
      const camelField = field.replace(/_[a-z]/g, (m) => m[1].toUpperCase());
      if (req.body[camelField] !== undefined) {
        updates.push(`${field} = $${paramIndex++}`);
        params.push(req.body[camelField]);
      }
    }

    if (req.body.category) {
      const catResult = await query('SELECT id FROM categories WHERE name = $1', [req.body.category]);
      if (catResult.rows.length === 0) {
        throw createError(400, `Ungültige Kategorie: ${req.body.category}`);
      }
      updates.push(`category_id = $${paramIndex++}`);
      params.push(catResult.rows[0].id);
    }

    if (req.body.latitude && req.body.longitude) {
      updates.push(`location_geo = ST_MakePoint($${paramIndex}, $${paramIndex + 1})::geography`);
      params.push(parseFloat(req.body.longitude), parseFloat(req.body.latitude));
      paramIndex += 2;
    }

    if (updates.length > 0) {
      updates.push('updated_at = NOW()');
      params.push(id);
      await query(
        `UPDATE services SET ${updates.join(', ')} WHERE id = $${paramIndex}`,
        params
      );
    }

    const result = await query(
      `SELECT s.*, cat.name AS category, u.id AS provider_id, u.display_name AS provider_name
       FROM services s
       LEFT JOIN categories cat ON s.category_id = cat.id
       LEFT JOIN users u ON s.provider_id = u.id
       WHERE s.id = $1`,
      [id]
    );

    res.json(mapService(result.rows[0]));
  } catch (err) {
    next(err);
  }
}

async function remove(req, res, next) {
  try {
    const { id } = req.params;
    const existing = await query('SELECT * FROM services WHERE id = $1', [id]);
    if (existing.rows.length === 0) {
      throw createError(404, 'Service nicht gefunden');
    }
    if (existing.rows[0].provider_id !== req.user.id) {
      throw createError(403, 'Nur der Anbieter kann den Service löschen');
    }

    await query('DELETE FROM services WHERE id = $1', [id]);
    res.json({ message: 'Service gelöscht' });
  } catch (err) {
    next(err);
  }
}

function mapService(row) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    category: row.category,
    price: parseFloat(row.price),
    priceUnit: row.price_unit,
    location: row.location,
    latitude: row.latitude ? parseFloat(row.latitude) : null,
    longitude: row.longitude ? parseFloat(row.longitude) : null,
    averageRating: row.average_rating ? parseFloat(row.average_rating) : 0,
    reviewCount: row.review_count,
    providerId: row.provider_id,
    providerName: row.provider_name,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

module.exports = { list, getById, create, update, remove };
