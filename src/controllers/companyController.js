const path = require('path');
const { query, getClient, supabase } = require('../config/database');
const { createError } = require('../middleware/errorHandler');

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function isValidUUID(str) {
  return typeof str === 'string' && UUID_REGEX.test(str);
}

const MIME_TO_EXT = {
  'image/jpeg': '.jpg', 'image/jpg': '.jpg', 'image/png': '.png',
  'image/gif': '.gif', 'image/webp': '.webp', 'image/bmp': '.bmp',
  'image/svg+xml': '.svg', 'image/svg': '.svg', 'image/tiff': '.tiff',
  'image/tif': '.tiff', 'image/avif': '.avif', 'image/heic': '.heic',
  'image/heif': '.heif', 'image/ico': '.ico', 'image/x-icon': '.ico',
};

const STORAGE_BUCKET = 'company-images';

function mimeToExt(mimeType) {
  if (MIME_TO_EXT[mimeType]) return MIME_TO_EXT[mimeType];
  const sub = mimeType.split('/')[1];
  if (sub) {
    const clean = sub.split('+')[0];
    if (clean) return '.' + clean;
  }
  return null;
}

async function uploadToSupabase(buffer, mimeType, ext) {
  const filename = `company_${Date.now()}_${Math.round(Math.random() * 1E9)}${ext}`;
  const { data, error } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(filename, buffer, {
      contentType: mimeType,
      upsert: false,
    });
  if (error) throw error;
  const { data: { publicUrl } } = supabase.storage
    .from(STORAGE_BUCKET)
    .getPublicUrl(filename);
  return publicUrl;
}

async function saveBase64Image(dataUrl) {
  if (!dataUrl || typeof dataUrl !== 'string') return null;
  if (dataUrl.startsWith('/uploads/')) return dataUrl;
  if (dataUrl.startsWith('http://') || dataUrl.startsWith('https://')) return dataUrl;

  const match = dataUrl.match(/^data:(image\/[\w+.-]+);base64,(.+)$/);
  if (!match) {
    throw createError(400, 'Ungültiges Bildformat');
  }

  const mimeType = match[1];
  const base64Data = match[2];
  const ext = mimeToExt(mimeType);
  if (!ext) {
    throw createError(400, `Nicht unterstütztes Bildformat: ${mimeType}`);
  }

  const buffer = Buffer.from(base64Data, 'base64');
  return await uploadToSupabase(buffer, mimeType, ext);
}

async function list(req, res, next) {
  try {
    const { lat, lng, radius, category, search, ownerId } = req.query;
    const params = [];
    const conditions = [];
    let paramIndex = 1;

    if (ownerId) {
      conditions.push(`c.owner_id = $${paramIndex++}`);
      params.push(ownerId);
    }

    if (category && category !== 'Alle') {
      conditions.push(`EXISTS (SELECT 1 FROM company_categories cc
        JOIN categories cat2 ON cc.category_id = cat2.id
        WHERE cc.company_id = c.id AND cat2.name = $${paramIndex++})`);
      params.push(category);
    }

    if (search) {
      conditions.push(`(c.name ILIKE $${paramIndex} OR c.description ILIKE $${paramIndex})`);
      params.push(`%${search}%`);
      paramIndex++;
    }

    let geoJoin = '';
    let orderBy = 'c.created_at DESC';

    if (lat && lng && radius) {
      const radiusMeters = parseFloat(radius);
      geoJoin = `
        INNER JOIN (SELECT ST_MakePoint($${paramIndex}, $${paramIndex + 1})::geography AS ref_point) AS gp ON true
      `;
      conditions.push(`(c.service_radius_km < 0 OR ST_DWithin(c.location, gp.ref_point, $${paramIndex + 2}))`);
      params.push(parseFloat(lng), parseFloat(lat), radiusMeters);
      orderBy = `CASE WHEN c.service_radius_km < 0 THEN 0 ELSE ST_Distance(c.location, gp.ref_point) END ASC`;
      paramIndex += 3;
    }

    const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const sql = `
      SELECT
        c.id, c.name, c.description, c.address, c.phone_number, c.email,
        c.website, c.latitude, c.longitude, c.service_radius_km, c.price_level,
        c.view_count, c.average_rating, c.review_count, c.created_at, c.updated_at,
        c.hide_address, c.has_whatsapp, c.wants_advertising, c.logo_url,
        u.id AS owner_id, u.display_name AS owner_name
        ${lat && lng ? `, CASE WHEN c.service_radius_km < 0 THEN 0 ELSE ST_Distance(c.location, gp.ref_point) END AS distance_m` : ''}
      FROM companies c
      ${geoJoin}
      LEFT JOIN users u ON c.owner_id = u.id
      ${where}
      ORDER BY ${orderBy}
      LIMIT 50
    `;

    const result = await query(sql, params);
    const rows = result.rows;

    const companyIds = rows.map(r => r.id);
    let categoriesMap = {};
    let imagesMap = {};

    if (companyIds.length > 0) {
      const catResult = await query(
        `SELECT cc.company_id, cat.name
         FROM company_categories cc
         JOIN categories cat ON cc.category_id = cat.id
         WHERE cc.company_id = ANY($1)`,
        [companyIds]
      );
      for (const row of catResult.rows) {
        if (!categoriesMap[row.company_id]) categoriesMap[row.company_id] = [];
        categoriesMap[row.company_id].push(row.name);
      }

      const imgResult = await query(
        `SELECT company_id, image_url, sort_order FROM company_images
         WHERE company_id = ANY($1) ORDER BY sort_order ASC`,
        [companyIds]
      );
      for (const row of imgResult.rows) {
        if (!imagesMap[row.company_id]) imagesMap[row.company_id] = [];
        imagesMap[row.company_id].push(row.image_url);
      }
    }

    res.json(rows.map(r => mapCompany(r, categoriesMap[r.id], imagesMap[r.id])));
  } catch (err) {
    next(err);
  }
}

async function getById(req, res, next) {
  try {
    const { id } = req.params;
    if (!isValidUUID(id)) {
      throw createError(400, 'Ungültige Firmen-ID');
    }
    const result = await query(
      `SELECT c.*, u.id AS owner_id, u.display_name AS owner_name
      FROM companies c
      LEFT JOIN users u ON c.owner_id = u.id
      WHERE c.id = $1`,
      [id]
    );
    if (result.rows.length === 0) {
      throw createError(404, 'Firma nicht gefunden');
    }

    const catResult = await query(
      `SELECT cat.name FROM company_categories cc
       JOIN categories cat ON cc.category_id = cat.id
       WHERE cc.company_id = $1`,
      [id]
    );
    const categories = catResult.rows.map(r => r.name);

    const imgResult = await query(
      `SELECT image_url FROM company_images WHERE company_id = $1 ORDER BY sort_order ASC`,
      [id]
    );
    const images = imgResult.rows.map(r => r.image_url);

    const reviewResult = await query(
      `SELECT r.id, r.rating, r.comment, r.created_at,
              u.id AS user_id, u.display_name AS user_name
       FROM reviews r
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.company_id = $1
       ORDER BY r.created_at DESC`,
      [id]
    );
    const reviews = reviewResult.rows.map(r => ({
      id: r.id,
      companyId: id,
      userId: r.user_id,
      userName: r.user_name,
      rating: r.rating,
      comment: r.comment,
      timestamp: r.created_at,
    }));

    res.json(mapCompany(result.rows[0], categories, images, reviews));
  } catch (err) {
    next(err);
  }
}

async function create(req, res, next) {
  const client = await getClient();
  try {
    await client.query('BEGIN');

    const {
      name, description, address, phoneNumber, email, website,
      categories, latitude, longitude, serviceRadiusKm, priceLevel, images,
    } = req.body;

    if (!name || !address || !categories || !Array.isArray(categories) || categories.length === 0) {
      throw createError(400, 'name, address und categories (Array) sind erforderlich');
    }

    const catIds = [];
    for (const cat of categories) {
      const catResult = await client.query('SELECT id FROM categories WHERE name = $1', [cat]);
      if (catResult.rows.length === 0) {
        throw createError(400, `Ungültige Kategorie: ${cat}`);
      }
      catIds.push(catResult.rows[0].id);
    }

    let logoUrl = req.body.logoUrl || '';
    if (logoUrl && typeof logoUrl === 'string' && logoUrl.startsWith('data:image')) {
      const saved = await saveBase64Image(logoUrl);
      if (saved) logoUrl = saved;
    }

    let locationSql = 'NULL';
    const params = [
      req.user.id, name, description || '', address, phoneNumber || '',
      email || '', website || null,
      latitude || null, longitude || null,
      serviceRadiusKm !== undefined ? serviceRadiusKm : null, priceLevel || null,
    ];

    if (latitude && longitude) {
      locationSql = 'ST_MakePoint($16, $17)::geography';
      params.push(
        req.body.hideAddress ?? false, req.body.hasWhatsapp ?? false,
        req.body.wantsAdvertising ?? false, logoUrl,
        parseFloat(longitude), parseFloat(latitude)
      );
    } else {
      params.push(req.body.hideAddress ?? false, req.body.hasWhatsapp ?? false,
                  req.body.wantsAdvertising ?? false, logoUrl);
    }

    const insertResult = await client.query(
      `INSERT INTO companies
        (owner_id, name, description, address, phone_number, email, website,
         latitude, longitude, location, service_radius_km, price_level,
         hide_address, has_whatsapp, wants_advertising, logo_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, ${locationSql}, $10, $11,
         $12, $13, $14, $15)
       RETURNING id`,
      params
    );
    const companyId = insertResult.rows[0].id;

    for (const catId of catIds) {
      await client.query(
        'INSERT INTO company_categories (company_id, category_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [companyId, catId]
      );
    }

    if (images && Array.isArray(images)) {
      for (let i = 0; i < images.length; i++) {
        const imageUrl = await saveBase64Image(images[i]);
        if (imageUrl) {
          await client.query(
            'INSERT INTO company_images (company_id, image_url, sort_order) VALUES ($1, $2, $3)',
            [companyId, imageUrl, i]
          );
        }
      }
    }

    await client.query('COMMIT');

    const company = await query(
      `SELECT c.*, u.id AS owner_id, u.display_name AS owner_name
       FROM companies c
       LEFT JOIN users u ON c.owner_id = u.id
       WHERE c.id = $1`,
      [companyId]
    );

    const catResult = await query(
      `SELECT cat.name FROM company_categories cc
       JOIN categories cat ON cc.category_id = cat.id
       WHERE cc.company_id = $1`,
      [companyId]
    );
    const cats = catResult.rows.map(r => r.name);

    const imgResult = await query(
      `SELECT image_url FROM company_images WHERE company_id = $1 ORDER BY sort_order ASC`,
      [companyId]
    );
    const imgs = imgResult.rows.map(r => r.image_url);

    res.status(201).json(mapCompany(company.rows[0], cats, imgs));
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
}

async function update(req, res, next) {
  const client = await getClient();
  try {
    await client.query('BEGIN');

    const { id } = req.params;
    if (!isValidUUID(id)) {
      throw createError(400, 'Ungültige Firmen-ID');
    }
    const existing = await client.query('SELECT * FROM companies WHERE id = $1', [id]);
    if (existing.rows.length === 0) {
      throw createError(404, 'Firma nicht gefunden');
    }
    if (existing.rows[0].owner_id !== req.user.id) {
      throw createError(403, 'Nur der Besitzer kann die Firma bearbeiten');
    }

    const fields = [
      'name', 'description', 'address', 'phone_number', 'email',
      'website', 'service_radius_km', 'price_level', 'latitude', 'longitude',
      'hide_address', 'has_whatsapp', 'wants_advertising',
    ];

    // Handle logo separately – save base64 if it's a data URL
    if (req.body.logo && typeof req.body.logo === 'string' && req.body.logo.startsWith('data:image')) {
      const imageUrl = await saveBase64Image(req.body.logo);
      if (imageUrl) {
        req.body.logoUrl = imageUrl;
      }
    }
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

    if (req.body.latitude && req.body.longitude) {
      updates.push(`location = ST_MakePoint($${paramIndex}, $${paramIndex + 1})::geography`);
      params.push(parseFloat(req.body.longitude), parseFloat(req.body.latitude));
      paramIndex += 2;
    }

    if (updates.length > 0) {
      updates.push('updated_at = NOW()');
      params.push(id);
      await client.query(
        `UPDATE companies SET ${updates.join(', ')} WHERE id = $${paramIndex}`,
        params
      );
    }

    if (req.body.categories && Array.isArray(req.body.categories)) {
      await client.query('DELETE FROM company_categories WHERE company_id = $1', [id]);
      for (const cat of req.body.categories) {
        const catResult = await client.query('SELECT id FROM categories WHERE name = $1', [cat]);
        if (catResult.rows.length > 0) {
          await client.query(
            'INSERT INTO company_categories (company_id, category_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [id, catResult.rows[0].id]
          );
        }
      }
    }

    if (req.body.images && Array.isArray(req.body.images)) {
      await client.query('DELETE FROM company_images WHERE company_id = $1', [id]);
      for (let i = 0; i < req.body.images.length; i++) {
        const imageUrl = await saveBase64Image(req.body.images[i]);
        if (imageUrl) {
          await client.query(
            'INSERT INTO company_images (company_id, image_url, sort_order) VALUES ($1, $2, $3)',
            [id, imageUrl, i]
          );
        }
      }
    }

    await client.query('COMMIT');

    const result = await query(
      `SELECT c.*, u.id AS owner_id, u.display_name AS owner_name
       FROM companies c
       LEFT JOIN users u ON c.owner_id = u.id
       WHERE c.id = $1`,
      [id]
    );

    const catResult = await query(
      `SELECT cat.name FROM company_categories cc
       JOIN categories cat ON cc.category_id = cat.id
       WHERE cc.company_id = $1`,
      [id]
    );
    const cats = catResult.rows.map(r => r.name);

    const imgResult = await query(
      `SELECT image_url FROM company_images WHERE company_id = $1 ORDER BY sort_order ASC`,
      [id]
    );
    const imgs = imgResult.rows.map(r => r.image_url);

    res.json(mapCompany(result.rows[0], cats, imgs));
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
}

async function remove(req, res, next) {
  try {
    const { id } = req.params;
    if (!isValidUUID(id)) {
      throw createError(400, 'Ungültige Firmen-ID');
    }
    const existing = await query('SELECT * FROM companies WHERE id = $1', [id]);
    if (existing.rows.length === 0) {
      throw createError(404, 'Firma nicht gefunden');
    }
    if (existing.rows[0].owner_id !== req.user.id) {
      throw createError(403, 'Nur der Besitzer kann die Firma löschen');
    }

    await query('DELETE FROM companies WHERE id = $1', [id]);
    res.json({ message: 'Firma gelöscht' });
  } catch (err) {
    next(err);
  }
}

async function addView(req, res, next) {
  try {
    const { id } = req.params;
    if (!isValidUUID(id)) {
      return res.json({ viewCount: 0 });
    }
    const result = await query(
      `UPDATE companies SET view_count = view_count + 1 WHERE id = $1 RETURNING view_count`,
      [id]
    );
    if (result.rows.length === 0) {
      throw createError(404, 'Firma nicht gefunden');
    }
    res.json({ viewCount: result.rows[0].view_count });
  } catch (err) {
    next(err);
  }
}

async function uploadImage(req, res, next) {
  try {
    if (!req.files || req.files.length === 0) {
      throw createError(400, 'Keine Dateien hochgeladen');
    }
    const imageUrls = [];
    for (const file of req.files) {
      const ext = path.extname(file.originalname);
      const url = await uploadToSupabase(file.buffer, file.mimetype, ext);
      imageUrls.push(url);
    }
    res.json({ images: imageUrls });
  } catch (err) {
    next(err);
  }
}

function mapCompany(row, categories, images, reviews) {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    address: row.address,
    phoneNumber: row.phone_number,
    email: row.email,
    website: row.website,
    categories: categories || ['Sonstiges'],
    latitude: row.latitude ? parseFloat(row.latitude) : null,
    longitude: row.longitude ? parseFloat(row.longitude) : null,
    serviceRadius: row.service_radius_km ? parseFloat(row.service_radius_km) : null,
    priceLevel: row.price_level,
    viewCount: row.view_count,
    averageRating: row.average_rating ? parseFloat(row.average_rating) : 0,
    reviewCount: row.review_count,
    distanceM: row.distance_m ? Math.round(parseFloat(row.distance_m)) : null,
    ownerId: row.owner_id,
    ownerName: row.owner_name,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    hideAddress: row.hide_address ?? false,
    hasWhatsapp: row.has_whatsapp ?? false,
    wantsAdvertising: row.wants_advertising ?? false,
    logoUrl: row.logo_url || '',
    images: images || [],
    reviews: reviews || [],
  };
}

module.exports = { list, getById, create, update, remove, addView, uploadImage };
