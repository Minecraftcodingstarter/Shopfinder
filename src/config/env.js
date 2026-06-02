// server/src/config/env.js
require('dotenv').config();

module.exports = {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',

  // Supabase (für Storage und Auth-Verifikation)
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseServiceKey: process.env.SUPABASE_SERVICE_KEY,

  // Direkte PostgreSQL-Verbindung (für pg.Pool – ersetzt exec_sql RPC)
  databaseUrl: process.env.DATABASE_URL,

  // JWT Secret für benutzerdefinierte Tokens
  jwtSecret: process.env.JWT_SECRET,

  // Firebase Project ID (falls noch genutzt)
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID,

  // Google APIs
  googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY,
  geminiApiKey: process.env.GEMINI_API_KEY,
};