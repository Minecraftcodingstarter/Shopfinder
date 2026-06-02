const { Router } = require('express');
const { authenticate } = require('../middleware/auth');
const controller = require('../controllers/serviceController');

const router = Router();

router.get('/', controller.list);
router.get('/:id', controller.getById);
router.post('/', authenticate, controller.create);
router.put('/:id', authenticate, controller.update);
router.delete('/:id', authenticate, controller.remove);

module.exports = router;
