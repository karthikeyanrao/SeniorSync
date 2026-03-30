const jwt = require('jsonwebtoken');

const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: No token provided' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const defaultSecret = 'fallback_secret_for_development'; // Needs to match jwt.sign
    const payload = jwt.verify(token, process.env.JWT_SECRET || defaultSecret);
    req.user = payload;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

module.exports = requireAuth;
