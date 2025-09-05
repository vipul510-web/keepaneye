import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

// Extend Express Request interface to include user
declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string;
        email: string;
        role: string;
      };
    }
  }
}

export const authMiddleware = (req: Request, res: Response, next: NextFunction) => {
  try {
    const authHeader = req.headers.authorization;
    
    console.log('🔐 Auth middleware - URL:', req.url);
    console.log('🔐 Auth middleware - Authorization header:', authHeader);
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('❌ Auth middleware - No Bearer token found');
      return res.status(401).json({ error: 'Access token required' });
    }
    
    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    console.log('🔐 Auth middleware - Token (first 20 chars):', token.substring(0, 20) + '...');
    
    if (!process.env.JWT_SECRET) {
      console.error('JWT_SECRET not configured');
      return res.status(500).json({ error: 'Server configuration error' });
    }
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET) as any;
    console.log('🔐 Auth middleware - Decoded token:', { userId: decoded.userId, email: decoded.email, role: decoded.role });
    
    if (!decoded.userId || !decoded.email || !decoded.role) {
      console.log('❌ Auth middleware - Invalid token format');
      return res.status(401).json({ error: 'Invalid token format' });
    }
    
    req.user = {
      userId: decoded.userId,
      email: decoded.email,
      role: decoded.role
    };
    
    console.log('✅ Auth middleware - Authentication successful');
    next();
  } catch (error) {
    console.log('❌ Auth middleware - Error:', error);
    if (error instanceof jwt.JsonWebTokenError) {
      return res.status(401).json({ error: 'Invalid token' });
    }
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired' });
    }
    
    console.error('Auth middleware error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
};

// Optional auth middleware for routes that can work with or without authentication
export const optionalAuthMiddleware = (req: Request, res: Response, next: NextFunction) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next(); // Continue without user info
    }
    
    const token = authHeader.substring(7);
    
    if (!process.env.JWT_SECRET) {
      return next(); // Continue without user info
    }
    
    const decoded = jwt.verify(token, process.env.JWT_SECRET) as any;
    
    if (decoded.userId && decoded.email && decoded.role) {
      req.user = {
        userId: decoded.userId,
        email: decoded.email,
        role: decoded.role
      };
    }
    
    next();
  } catch (error) {
    // Continue without user info on any error
    next();
  }
};

// Role-based access control middleware
export const requireRole = (allowedRoles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    
    next();
  };
};

// Parent-only access middleware
export const requireParent = requireRole(['parent']);

// Caregiver-only access middleware
export const requireCaregiver = requireRole(['caregiver']);

// Any authenticated user middleware
export const requireAuth = (req: Request, res: Response, next: NextFunction) => {
  if (!req.user) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  next();
}; 