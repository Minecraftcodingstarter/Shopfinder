const { Router } = require('express');
const { authenticate } = require('../middleware/auth');
const controller = require('../controllers/reviewController');

const router = Router();

router.get('/companies/:id/reviews', controller.listCompanyReviews);
router.post('/companies/:id/reviews', authenticate, controller.createCompanyReview);
router.put('/companies/:companyId/reviews/:reviewId', authenticate, controller.updateCompanyReview);
router.get('/services/:id/reviews', controller.listServiceReviews);
router.post('/services/:id/reviews', authenticate, controller.createServiceReview);

module.exports = router;
