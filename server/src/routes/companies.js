const { Router } = require('express');
const multer = require('multer');
const path = require('path');
const { authenticate } = require('../middleware/auth');
const controller = require('../controllers/companyController');

const router = Router();

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, path.join(__dirname, '..', '..', 'uploads'));
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `company_${Date.now()}_${Math.round(Math.random() * 1E9)}${ext}`);
  },
});

const upload = multer({
  storage,
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
