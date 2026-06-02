// server/src/config/database.js
// Datenbankverbindung über pg.Pool (direktes PostgreSQL, kein exec_sql RPC mehr)

const { Pool } = require('pg');
const { createClient } = require('@supabase/supabase-js');
const env = require('./env');

// Supabase-Client (nur noch für Storage + Auth-Verifikation)
const supabase = createClient(env.supabaseUrl, env.supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

// PostgreSQL Pool (für alle SQL-Queries)
const pool = new Pool({
  connectionString: env.databaseUrl,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  console.error('[DB] pg.Pool unerwarteter Fehler:', err);
});

/**
 * SQL Query ausführen (direkt über pg.Pool)
 */
async function query(text, params) {
  const result = await pool.query(text, params);
  return { rows: result.rows, rowCount: result.rowCount };
}

/**
 * Pool-Client für Transaktionen holen (BEGIN/COMMIT/ROLLBACK)
 */
async function getClient() {
  return pool.connect();
}

/**
 * Nutzerprofil aus public.users holen
 */
async function getUserById(userId) {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();
  if (error) return null;
  return data;
}

/**
 * Supabase JWT verifizieren und User-Daten holen
 */
async function verifyToken(token) {
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user;
}

/**
 * Migration: Tabellen in Supabase anlegen (falls nicht vorhanden)
 * Wird beim Server-Start aufgerufen.
 */
async function migrate() {
  console.log('[DB] PostgreSQL Pool verbunden – Tabellen müssen in Supabase existieren.');
  try {
    await pool.query('SELECT 1');
    console.log('[DB] Verbindung zu PostgreSQL erfolgreich.');
  } catch (err) {
    console.error('[DB] Verbindung fehlgeschlagen:', err.message);
  }
}

// Direktaufruf: node src/config/database.js migrate
if (require.main === module && process.argv[2] === 'migrate') {
  migrate().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });
}

module.exports = { supabase, query, getClient, getUserById, verifyToken, migrate };