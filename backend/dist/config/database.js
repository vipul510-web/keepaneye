"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.db = void 0;
exports.initializeDatabase = initializeDatabase;
exports.closeDatabase = closeDatabase;
const knex_1 = __importDefault(require("knex"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const dbConfig = {
    client: 'pg',
    connection: process.env.DATABASE_URL || {
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        user: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || '',
        database: process.env.DB_NAME || 'keepaneye',
    },
    pool: {
        min: 2,
        max: 10,
        acquireTimeoutMillis: 30000,
        createTimeoutMillis: 30000,
        destroyTimeoutMillis: 5000,
        idleTimeoutMillis: 30000,
        reapIntervalMillis: 1000,
        createRetryIntervalMillis: 100,
    },
    migrations: {
        directory: './src/database/migrations',
        tableName: 'knex_migrations',
    },
    seeds: {
        directory: './src/database/seeds',
    },
    debug: process.env.NODE_ENV === 'development',
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
};
exports.db = (0, knex_1.default)(dbConfig);
async function initializeDatabase() {
    try {
        // Test the connection
        await exports.db.raw('SELECT 1');
        console.log('✅ Database connection successful');
        // Run migrations
        await exports.db.migrate.latest();
        console.log('✅ Database migrations completed');
    }
    catch (error) {
        console.error('❌ Database connection failed:', error);
        throw error;
    }
}
async function closeDatabase() {
    try {
        await exports.db.destroy();
        console.log('✅ Database connection closed');
    }
    catch (error) {
        console.error('❌ Error closing database connection:', error);
    }
}
exports.default = exports.db;
