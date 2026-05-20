const { Router } = require('express');
const controller = require('../controllers/searchController');

const router = Router();

router.get('/', controller.searchShops);

module.exports = router;
