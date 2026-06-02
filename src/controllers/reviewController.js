const { query } = require('../config/database');
const { createError } = require('../middleware/errorHandler');

async function listCompanyReviews(req, res, next) {
  try {
    const { id: companyId } = req.params;
    const result = await query(
      `SELECT r.id, r.rating, r.comment, r.created_at,
              u.id AS user_id, u.display_name AS user_name
       FROM reviews r
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.company_id = $1
       ORDER BY r.created_at DESC`,
      [companyId]
    );
    res.json(result.rows.map(mapReview));
  } catch (err) {
    next(err);
  }
}

async function createCompanyReview(req, res, next) {
  try {
    const { id: companyId } = req.params;
    const { rating, comment } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      throw createError(400, 'Rating muss zwischen 1 und 5 liegen');
    }

    const company = await query('SELECT id FROM companies WHERE id = $1', [companyId]);
    if (company.rows.length === 0) {
      throw createError(404, 'Firma nicht gefunden');
    }

    const existing = await query(
      'SELECT id FROM reviews WHERE user_id = $1 AND company_id = $2',
      [req.user.id, companyId]
    );
    if (existing.rows.length > 0) {
      throw createError(409, 'Du hast diese Firma bereits bewertet');
    }

    const result = await query(
      `INSERT INTO reviews (user_id, company_id, rating, comment)
       VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [req.user.id, companyId, rating, comment || null]
    );

    await _updateCompanyRating(companyId);

    const review = await query(
      `SELECT r.id, r.rating, r.comment, r.created_at,
              u.id AS user_id, u.display_name AS user_name
       FROM reviews r
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.id = $1`,
      [result.rows[0].id]
    );

    res.status(201).json(mapReview(review.rows[0]));
  } catch (err) {
    next(err);
  }
}

async function updateCompanyReview(req, res, next) {
  try {
    const { companyId, reviewId } = req.params;
    const { rating, comment } = req.body;

    const existing = await query(
      'SELECT id, user_id FROM reviews WHERE id = $1 AND company_id = $2',
      [reviewId, companyId]
    );
    if (existing.rows.length === 0) {
      throw createError(404, 'Bewertung nicht gefunden');
    }
    if (existing.rows[0].user_id !== req.user.id) {
      throw createError(403, 'Nur der Autor kann diese Bewertung bearbeiten');
    }

    const updates = [];
    const params = [];
    let paramIndex = 1;

    if (rating !== undefined) {
      if (rating < 1 || rating > 5) {
        throw createError(400, 'Rating muss zwischen 1 und 5 liegen');
      }
      updates.push(`rating = $${paramIndex++}`);
      params.push(rating);
    }

    if (comment !== undefined) {
      updates.push(`comment = $${paramIndex++}`);
      params.push(comment || null);
    }

    if (updates.length === 0) {
      throw createError(400, 'Keine Felder zum Aktualisieren');
    }

    updates.push(`updated_at = NOW()`);
    params.push(reviewId);
    params.push(companyId);

    await query(
      `UPDATE reviews SET ${updates.join(', ')} WHERE id = $${paramIndex++} AND company_id = $${paramIndex}`,
      params
    );

    await _updateCompanyRating(companyId);

    const review = await query(
      `SELECT r.id, r.rating, r.comment, r.created_at, r.updated_at,
              u.id AS user_id, u.display_name AS user_name
       FROM reviews r
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.id = $1`,
      [reviewId]
    );

    res.json(mapReview(review.rows[0]));
  } catch (err) {
    next(err);
  }
}

async function _updateCompanyRating(companyId) {
  await query(
    `UPDATE companies SET
       average_rating = (SELECT COALESCE(AVG(rating), 0) FROM reviews WHERE company_id = $1),
       review_count = (SELECT COUNT(*) FROM reviews WHERE company_id = $1)
     WHERE id = $1`,
    [companyId]
  );
}

async function listServiceReviews(req, res, next) {
  try {
    const { id: serviceId } = req.params;
    const result = await query(
      `SELECT r.id, r.rating, r.comment, r.created_at,
              u.id AS user_id, u.display_name AS user_name
       FROM service_reviews r
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.service_id = $1
       ORDER BY r.created_at DESC`,
      [serviceId]
    );
    res.json(result.rows.map(mapReview));
  } catch (err) {
    next(err);
  }
}

async function createServiceReview(req, res, next) {
  try {
    const { id: serviceId } = req.params;
    const { rating, comment } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      throw createError(400, 'Rating muss zwischen 1 und 5 liegen');
    }

    const service = await query('SELECT id FROM services WHERE id = $1', [serviceId]);
    if (service.rows.length === 0) {
      throw createError(404, 'Service nicht gefunden');
    }

    const existing = await query(
      'SELECT id FROM service_reviews WHERE user_id = $1 AND service_id = $2',
      [req.user.id, serviceId]
    );
    if (existing.rows.length > 0) {
      throw createError(409, 'Du hast diesen Service bereits bewertet');
    }

    const result = await query(
      `INSERT INTO service_reviews (user_id, service_id, rating, comment)
       VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [req.user.id, serviceId, rating, comment || null]
    );

    await _updateServiceRating(serviceId);

    const review = await query(
      `SELECT r.id, r.rating, r.comment, r.created_at,
              u.id AS user_id, u.display_name AS user_name
       FROM service_reviews r
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.id = $1`,
      [result.rows[0].id]
    );

    res.status(201).json(mapReview(review.rows[0]));
  } catch (err) {
    next(err);
  }
}

async function _updateServiceRating(serviceId) {
  await query(
    `UPDATE services SET
       average_rating = (SELECT COALESCE(AVG(rating), 0) FROM service_reviews WHERE service_id = $1),
       review_count = (SELECT COUNT(*) FROM service_reviews WHERE service_id = $1)
     WHERE id = $1`,
    [serviceId]
  );
}

function mapReview(row) {
  return {
    id: row.id,
    userId: row.user_id,
    userName: row.user_name,
    rating: row.rating,
    comment: row.comment,
    createdAt: row.created_at,
    updatedAt: row.updated_at || row.created_at,
  };
}

module.exports = {
  listCompanyReviews, createCompanyReview, updateCompanyReview,
  listServiceReviews, createServiceReview,
};
