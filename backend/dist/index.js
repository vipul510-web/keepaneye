"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.io = void 0;
exports.default = handler;
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const dotenv_1 = __importDefault(require("dotenv"));
const http_1 = require("http");
const socket_io_1 = require("socket.io");
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
// Import routes
const auth_1 = __importDefault(require("./routes/auth"));
const users_1 = __importDefault(require("./routes/users"));
const children_1 = __importDefault(require("./routes/children"));
const schedules_1 = __importDefault(require("./routes/schedules"));
const feed_1 = __importDefault(require("./routes/feed"));
const sync_1 = __importDefault(require("./routes/sync"));
const scheduleTemplates_1 = __importDefault(require("./routes/scheduleTemplates"));
// Import middleware
const errorHandler_1 = require("./middleware/errorHandler");
const auth_2 = require("./middleware/auth");
// Import database connection
const database_1 = require("./config/database");
const firebase_1 = require("./config/firebase");
// Load environment variables
dotenv_1.default.config();
const app = (0, express_1.default)();
const server = (0, http_1.createServer)(app);
const io = new socket_io_1.Server(server, {
    cors: {
        origin: process.env.NODE_ENV === 'production' ? false : true,
        methods: ['GET', 'POST']
    }
});
exports.io = io;
const PORT = process.env.PORT || 3000;
// Security middleware
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)({
    origin: process.env.NODE_ENV === 'production' ? false : true,
    credentials: true
}));
// Rate limiting
const limiter = (0, express_rate_limit_1.default)({
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'),
    max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '1000'),
    message: 'Too many requests from this IP, please try again later.'
});
app.use((req, res, next) => {
    // Always skip rate limiting for schedules routes and health checks
    if (req.path.startsWith('/api/schedules') || req.path === '/health') {
        return next();
    }
    // In development, disable rate limiting entirely
    if (process.env.NODE_ENV !== 'production') {
        return next();
    }
    // In production, allow auth and sync to pass more freely if needed later
    return limiter(req, res, next);
});
// Body parsing middleware
app.use(express_1.default.json({ limit: '10mb' }));
app.use(express_1.default.urlencoded({ extended: true, limit: '10mb' }));
// Static files
app.use('/uploads', express_1.default.static('uploads'));
// Health check endpoint
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV
    });
});
// API routes
app.use('/api/auth', auth_1.default);
app.use('/api/users', auth_2.authMiddleware, users_1.default);
app.use('/api/children', auth_2.authMiddleware, children_1.default);
app.use('/api/schedules', auth_2.authMiddleware, schedules_1.default);
app.use('/api/schedule-templates', auth_2.authMiddleware, scheduleTemplates_1.default);
app.use('/api/feed', auth_2.authMiddleware, feed_1.default);
app.use('/api/sync', auth_2.authMiddleware, sync_1.default);
// Socket.IO connection handling
io.on('connection', (socket) => {
    console.log('Client connected:', socket.id);
    socket.on('join-room', (roomId) => {
        socket.join(roomId);
        console.log(`Client ${socket.id} joined room: ${roomId}`);
    });
    socket.on('disconnect', () => {
        console.log('Client disconnected:', socket.id);
    });
});
// Error handling middleware
app.use(errorHandler_1.errorHandler);
// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({ error: 'Route not found' });
});
// Initialize services and start server
async function startServer() {
    try {
        // Initialize database
        await (0, database_1.initializeDatabase)();
        console.log('✅ Database connected successfully');
        // Initialize Firebase
        try {
            await (0, firebase_1.initializeFirebase)();
            console.log('✅ Firebase initialized successfully');
        }
        catch (error) {
            console.log('⚠️ Firebase initialization skipped (not required for core functionality)');
        }
    }
    catch (error) {
        console.error('❌ Failed to initialize services:', error);
        throw error;
    }
}
// Initialize services when the module loads
let isInitialized = false;
async function ensureInitialized() {
    if (!isInitialized) {
        await startServer();
        isInitialized = true;
    }
}
// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    server.close(() => {
        console.log('Process terminated');
    });
});
process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    server.close(() => {
        console.log('Process terminated');
    });
});
// Export the Express app for Vercel serverless functions
async function handler(req, res) {
    await ensureInitialized();
    // Handle the request using the Express app
    return app(req, res);
}
