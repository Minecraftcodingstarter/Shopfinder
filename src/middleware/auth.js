const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { query, supabase } = require('../config/database');

async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: true, message: 'Kein Token vorhanden' });
    }

    const token = authHeader.split(' ')[1];

    let decoded;
    try {
      decoded = jwt.verify(token, env.jwtSecret);
    } catch {
      return res.status(401).json({ error: true, message: 'Ungültiges oder abgelaufenes Token' });
    }

    const result = await query('SELECT id, firebase_uid, email, display_name, phone_number, created_at FROM users WHERE id = $1', [decoded.userId]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: true, message: 'Benutzer nicht gefunden' });
    }

    req.user = result.rows[0];
    next();
  } catch (err) {
    next(err);
  }
}

async function verifyFirebaseToken(req, res, next) {
  try {
    // Token aus Authorization: Bearer <token> (vom Flutter-Client gesendet)
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: true, message: 'Kein Token vorhanden' });
    }
    const token = authHeader.split(' ')[1];

    // Supabase JWT verifizieren
    const { data: { user: supabaseUser }, error } = await supabase.auth.getUser(token);
    if (error || !supabaseUser) {
      return res.status(401).json({ error: true, message: 'Ungültiges Supabase-Token' });
    }

    const uid = supabaseUser.id;
    const email = supabaseUser.email || `user_${uid}@shopfinder.local`;
    const displayName = supabaseUser.user_metadata?.display_name || supabaseUser.email || uid;

    // In lokaler users-Tabelle suchen oder anlegen
    let result = await query('SELECT * FROM users WHERE firebase_uid = $1', [uid]);

    if (result.rows.length === 0) {
      result = await query(
        `INSERT INTO users (firebase_uid, email, display_name, phone_number)
         VALUES ($1, $2, $3, $4)
         RETURNING id, firebase_uid, email, display_name, phone_number, created_at`,
        [uid, email, displayName, supabaseUser.phone || '']
      );
    } else {
      result = await query(
        `UPDATE users SET email = $1, display_name = COALESCE(NULLIF($2, ''), display_name), phone_number = COALESCE(NULLIF($3, ''), phone_number), updated_at = NOW()
         WHERE firebase_uid = $4
         RETURNING id, firebase_uid, email, display_name, phone_number, created_at`,
        [email, displayName, supabaseUser.phone || '', uid]
      );
    }

    const user = result.rows[0];
    const jwtToken = jwt.sign(
      { userId: user.id, firebaseUid: user.firebase_uid },
      env.jwtSecret,
      { expiresIn: '30d' }
    );

    res.json({
      token: jwtToken,
      user: {
        id: user.id,
        firebaseUid: user.firebase_uid,
        email: user.email,
        displayName: user.display_name,
        phoneNumber: user.phone_number,
        createdAt: user.created_at,
      },
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { authenticate, verifyFirebaseToken };
