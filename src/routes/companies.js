const { Router } = require('express');
const multer = require('multer');
const { authenticate } = require('../middleware/auth');
const controller = require('../controllers/companyController');

const router = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) return cb(null, true);
    cb(new Error(`Nicht unterstütztes Bildformat: ${file.mimetype}`));
  },
});

router.get('/', controller.list);
router.get('/:id', controller.getById);
router.post('/', authenticate, controller.create);
router.put('/:id', authenticate, controller.update);
router.delete('/:id', authenticate, controller.remove);
router.post('/:id/view', controller.addView);
router.post('/upload-image', authenticate, upload.array('images', 10), controller.uploadImage);

module.exports = router;
