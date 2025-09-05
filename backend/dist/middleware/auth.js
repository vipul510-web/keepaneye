"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = exports.requireCaregiver = exports.requireParent = exports.requireRole = exports.optionalAuthMiddleware = exports.authMiddleware = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const authMiddleware = (req, res, next) => {
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
        const decoded = jsonwebtoken_1.default.verify(token, process.env.JWT_SECRET);
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
    }
    catch (error) {
        console.log('❌ Auth middleware - Error:', error);
        if (error instanceof jsonwebtoken_1.default.JsonWebTokenError) {
            return res.status(401).json({ error: 'Invalid token' });
        }
        if (error instanceof jsonwebtoken_1.default.TokenExpiredError) {
            return res.status(401).json({ error: 'Token expired' });
        }
        console.error('Auth middleware error:', error);
        return res.status(500).json({ error: 'Internal server error' });
    }
};
exports.authMiddleware = authMiddleware;
// Optional auth middleware for routes that can work with or without authentication
const optionalAuthMiddleware = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return next(); // Continue without user info
        }
        const token = authHeader.substring(7);
        if (!process.env.JWT_SECRET) {
            return next(); // Continue without user info
        }
        const decoded = jsonwebtoken_1.default.verify(token, process.env.JWT_SECRET);
        if (decoded.userId && decoded.email && decoded.role) {
            req.user = {
                userId: decoded.userId,
                email: decoded.email,
                role: decoded.role
            };
        }
        next();
    }
    catch (error) {
        // Continue without user info on any error
        next();
    }
};
exports.optionalAuthMiddleware = optionalAuthMiddleware;
// Role-based access control middleware
const requireRole = (allowedRoles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Authentication required' });
        }
        if (!allowedRoles.includes(req.user.role)) {
            return res.status(403).json({ error: 'Insufficient permissions' });
        }
        next();
    };
};
exports.requireRole = requireRole;
// Parent-only access middleware
exports.requireParent = (0, exports.requireRole)(['parent']);
// Caregiver-only access middleware
exports.requireCaregiver = (0, exports.requireRole)(['caregiver']);
// Any authenticated user middleware
const requireAuth = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
    }
    next();
};
exports.requireAuth = requireAuth;
