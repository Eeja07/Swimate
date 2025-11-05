require("dotenv").config();
const jwt = require('jsonwebtoken');

const authenticateUser = (req, res, next) => {
  const token = req.header('Authorization');  
  console.log(token)
  if (!token) {
    return res.status(401).json({ message: 'Authorization denied. No token found.' });
  }

  try {
    const decoded = jwt.verify(token.replace('Bearer ', ''), process.env.JWT_SECRET);
    console.log('ini yang di decode', decoded);
    req.user = decoded;
    next();  
  } catch (error) {
    console.error('Token verification failed', error);
    res.status(401).json({ message: 'Invalid token. Authorization denied.' });
  }
};

module.exports = authenticateUser;
