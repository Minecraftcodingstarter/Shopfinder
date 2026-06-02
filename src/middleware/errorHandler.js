function errorHandler(err, req, res, _next) {
  console.error('Unhandled error:', err);

  const statusCode = err.statusCode || 500;
  const message = err.expose || statusCode < 500
    ? err.message
    : 'Interner Serverfehler';

  res.status(statusCode).json({
    error: true,
    message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
}

function createError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  err.expose = true;
  return err;
}

module.exports = { errorHandler, createError };
