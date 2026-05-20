const { Pool } = require('pg');
const env = require('./env');

const pool = new Pool({
  connectionString: env.databaseUrl,
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
  process.exit(-1);
});

async function query(text, params) {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  if (env.nodeEnv === 'development') {
    console.log('Query:', { text: text.substring(0, 80), duration: `${duration}ms`, rows: res.rowCount });
  }
  return res;
}

async function getClient() {
  const client = await pool.connect();
  return client;
}

async function migrate() {
  const sql = `
    CREATE EXTENSION IF NOT EXISTS postgis;

    CREATE TABLE IF NOT EXISTS categories (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) UNIQUE NOT NULL
    );

    INSERT INTO categories (name) VALUES
      ('Restaurant'), ('Supermarkt'), ('Dienstleistung'),
      ('Einzelhandel'), ('Gesundheit'), ('Freizeit'), ('Sonstiges')
    ON CONFLICT (name) DO NOTHING;

    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      firebase_uid VARCHAR(128) UNIQUE NOT NULL,
      email VARCHAR(255) UNIQUE NOT NULL,
      display_name VARCHAR(255),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS companies (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
      name VARCHAR(255) NOT NULL,
      description TEXT DEFAULT '',
      address TEXT NOT NULL,
      phone_number VARCHAR(50) DEFAULT '',
      email VARCHAR(255) DEFAULT '',
      website VARCHAR(500),
      category_id INTEGER REFERENCES categories(id),
      latitude DECIMAL(10, 7),
      longitude DECIMAL(10, 7),
      location GEOGRAPHY(Point, 4326),
      service_radius_km DECIMAL(10, 2),
      price_level VARCHAR(10),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      view_count INTEGER DEFAULT 0,
      average_rating DECIMAL(3, 2) DEFAULT 0.00,
      review_count INTEGER DEFAULT 0
    );

    CREATE INDEX IF NOT EXISTS idx_companies_location ON companies USING GIST (location);
    CREATE INDEX IF NOT EXISTS idx_companies_owner ON companies(owner_id);

    CREATE TABLE IF NOT EXISTS reviews (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
      rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
      comment TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_reviews_company ON reviews(company_id);

    CREATE TABLE IF NOT EXISTS services (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      provider_id UUID REFERENCES users(id) ON DELETE CASCADE,
      title VARCHAR(255) NOT NULL,
      description TEXT NOT NULL,
      category_id INTEGER REFERENCES categories(id),
      price DECIMAL(10, 2) NOT NULL,
      price_unit VARCHAR(50) DEFAULT '€',
      location TEXT NOT NULL,
      latitude DECIMAL(10, 7),
      longitude DECIMAL(10, 7),
      location_geo GEOGRAPHY(Point, 4326),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      average_rating DECIMAL(3, 2) DEFAULT 0.00,
      review_count INTEGER DEFAULT 0
    );

    CREATE INDEX IF NOT EXISTS idx_services_location ON services USING GIST (location_geo);

    CREATE TABLE IF NOT EXISTS service_reviews (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      service_id UUID REFERENCES services(id) ON DELETE CASCADE,
      rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
      comment TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_service_reviews_service ON service_reviews(service_id);

    ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(50) DEFAULT '';

    CREATE TABLE IF NOT EXISTS company_categories (
      company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
      category_id INTEGER REFERENCES categories(id),
      PRIMARY KEY (company_id, category_id)
    );

    CREATE TABLE IF NOT EXISTS company_images (
      id SERIAL PRIMARY KEY,
      company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
      image_url TEXT NOT NULL,
      sort_order INTEGER DEFAULT 0,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_company_images_company ON company_images(company_id);

    ALTER TABLE companies ADD COLUMN IF NOT EXISTS hide_address BOOLEAN DEFAULT FALSE;
    ALTER TABLE companies ADD COLUMN IF NOT EXISTS has_whatsapp BOOLEAN DEFAULT FALSE;
    ALTER TABLE companies ADD COLUMN IF NOT EXISTS wants_advertising BOOLEAN DEFAULT FALSE;
    ALTER TABLE companies ADD COLUMN IF NOT EXISTS logo_url TEXT DEFAULT '';

    CREATE TABLE IF NOT EXISTS company_reports (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
      reporter_email VARCHAR(255) DEFAULT '',
      reason TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    INSERT INTO company_categories (company_id, category_id)
    SELECT id, category_id FROM companies WHERE category_id IS NOT NULL
    ON CONFLICT DO NOTHING;
  `;

  console.log('Running migrations...');
  await query(sql);
  console.log('Migrations complete.');
}

async function seed() {
  console.log('Seed data already inserted in migration for categories.');
  console.log('Seed complete.');
}

if (require.main === module) {
  const command = process.argv[2];
  if (command === 'migrate') {
    migrate().then(() => process.exit(0)).catch((err) => { console.error(err); process.exit(1); });
  } else if (command === 'seed') {
    seed().then(() => process.exit(0)).catch((err) => { console.error(err); process.exit(1); });
  } else {
    console.log('Usage: node src/config/database.js migrate|seed');
    process.exit(1);
  }
}

module.exports = { pool, query, getClient, migrate, seed };
