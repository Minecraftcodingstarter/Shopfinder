const { Router } = require('express');
const { query } = require('../config/database');

const router = Router();

router.post('/companies/:id/report', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { reason, reporterEmail } = req.body;
    if (!reason || reason.trim().length === 0) {
      return res.status(400).json({ error: true, message: 'Bitte geben Sie einen Grund an.' });
    }
    await query(
      'INSERT INTO company_reports (company_id, reporter_email, reason) VALUES ($1, $2, $3)',
      [id, reporterEmail || '', reason.trim()]
    );
    res.json({ message: 'Meldung eingegangen. Wir werden uns darum kümmern.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
