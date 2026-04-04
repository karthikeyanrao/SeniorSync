const jwt = require('jsonwebtoken');

const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  // DEBUG LOG
  console.log(`[AUTH-CHECK] Path: ${req.path} | Headers: ${authHeader ? 'Token Present' : 'No Token'}`);

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: No token provided' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET || 'seniorsync_emergency_key_2024');
    req.user = payload;
    next();
  } catch (error) {
    console.error(`[AUTH] 401: ${error.message} (Secret used: ${process.env.JWT_SECRET ? 'Env Var' : 'Fallback'})`);
    return res.status(401).json({ error: `Unauthorized: ${error.message}` });
  }
};

module.exports = requireAuth;
