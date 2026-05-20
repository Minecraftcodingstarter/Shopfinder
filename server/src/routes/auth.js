const { Router } = require('express');
const { verifyFirebaseToken, getMe } = require('../controllers/authController');
const { authenticate } = require('../middleware/auth');

const router = Router();

router.post('/verify', verifyFirebaseToken);
router.get('/me', authenticate, getMe);

module.exports = router;
