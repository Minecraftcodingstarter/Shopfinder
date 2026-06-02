const express = require('express');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const env = require('./config/env');
const { migrate } = require('./config/database');
const { errorHandler } = require('./middleware/errorHandler');

const authRoutes = require('./routes/auth');
const companyRoutes = require('./routes/companies');
const reviewRoutes = require('./routes/reviews');
const serviceRoutes = require('./routes/services');
const proxyRoutes = require('./routes/proxy');
const searchRoutes = require('./routes/search');
const reportRoutes = require('./routes/reports');

const app = express();

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(cors({
  origin: true,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
}));
app.use(morgan('dev'));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/companies', companyRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/services', serviceRoutes);
app.use('/api/proxy', proxyRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/reports', reportRoutes);

app.use(errorHandler);

async function start() {
  try {
    await migrate();
    app.listen(env.port, () => {
      console.log(`Server läuft auf Port ${env.port} (${env.nodeEnv})`);
    });
  } catch (err) {
    console.error('Startup-Fehler:', err);
    process.exit(1);
  }
}

start();
