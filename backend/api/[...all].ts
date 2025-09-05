import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';

// Import routes
import authRoutes from '../src/routes/auth';
import userRoutes from '../src/routes/users';
import childRoutes from '../src/routes/children';
import scheduleRoutes from '../src/routes/schedules';
import feedRoutes from '../src/routes/feed';
import syncRoutes from '../src/routes/sync';
import scheduleTemplateRoutes from '../src/routes/scheduleTemplates';

// Import middleware
import { errorHandler } from '../src/middleware/errorHandler';
import { authMiddleware } from '../src/middleware/auth';

// Import database connection
import { initializeDatabase } from '../src/config/database';
import { initializeFirebase } from '../src/config/firebase';

// Load environment variables
dotenv.config();

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.NODE_ENV === 'production' ? false : true,
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'), // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

// Apply rate limiting to all routes except schedules and health
app.use((req, res, next) => {
  // Skip rate limiting for schedules and health endpoints
  if (req.path.startsWith('/api/schedules') || req.path === '/health') {
    return next();
  }

  // In production, allow auth and sync to pass more freely if needed later
  return limiter(req, res, next);
});

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files
app.use('/uploads', express.static('uploads'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV 
  });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', authMiddleware, userRoutes);
app.use('/api/children', authMiddleware, childRoutes);
app.use('/api/schedules', authMiddleware, scheduleRoutes);
app.use('/api/schedule-templates', authMiddleware, scheduleTemplateRoutes);
app.use('/api/feed', authMiddleware, feedRoutes);
app.use('/api/sync', authMiddleware, syncRoutes);

// Error handling middleware
app.use(errorHandler);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Initialize services
let isInitialized = false;
async function ensureInitialized() {
  if (!isInitialized) {
    try {
      // Initialize database
      await initializeDatabase();
      console.log('✅ Database connected successfully');
      
      // Initialize Firebase
      try {
        await initializeFirebase();
        console.log('✅ Firebase initialized successfully');
      } catch (error) {
        console.log('⚠️ Firebase initialization skipped (not required for core functionality)');
      }
      
      isInitialized = true;
    } catch (error) {
      console.error('❌ Failed to initialize services:', error);
      throw error;
    }
  }
}

// Export the Express app for Vercel serverless functions
export default async function handler(req: any, res: any) {
  await ensureInitialized();
  
  // Handle the request using the Express app
  return app(req, res);
}
