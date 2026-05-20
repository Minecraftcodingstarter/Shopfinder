const { Router } = require('express');
const { authenticate } = require('../middleware/auth');
const controller = require('../controllers/proxyController');

const router = Router();

router.post('/gemini', authenticate, controller.proxyGemini);
router.post('/grok', authenticate, controller.proxyGrok);
router.post('/places', authenticate, controller.proxyPlaces);
router.post('/places/details', authenticate, controller.proxyPlacesDetails);
router.post('/nominatim', controller.proxyNominatim);

module.exports = router;
