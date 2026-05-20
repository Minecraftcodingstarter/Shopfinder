const { query } = require('../config/database');
const { verifyFirebaseToken } = require('../middleware/auth');

async function getMe(req, res, next) {
  try {
    const result = await query(
      'SELECT id, firebase_uid, email, display_name, phone_number, created_at FROM users WHERE id = $1',
      [req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: true, message: 'Benutzer nicht gefunden' });
    }
    const u = result.rows[0];
    res.json({
      id: u.id,
      firebaseUid: u.firebase_uid,
      email: u.email,
      displayName: u.display_name,
      phoneNumber: u.phone_number,
      createdAt: u.created_at,
    });
  } catch (err) {
    next(err);
  }
}

module.exports = { verifyFirebaseToken, getMe };
