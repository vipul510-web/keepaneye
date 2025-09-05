"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.EncryptionService = void 0;
const crypto_1 = __importDefault(require("crypto"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'default-32-char-encryption-key-here';
const ENCRYPTION_IV = process.env.ENCRYPTION_IV || 'default-16-char-iv';
class EncryptionService {
    /**
     * Encrypt data before sending to server
     */
    static encrypt(text) {
        try {
            const cipher = crypto_1.default.createCipher(this.algorithm, this.key);
            let encrypted = cipher.update(text, 'utf8', 'hex');
            encrypted += cipher.final('hex');
            return encrypted;
        }
        catch (error) {
            console.error('Encryption failed:', error);
            throw new Error('Failed to encrypt data');
        }
    }
    /**
     * Decrypt data received from server
     */
    static decrypt(encryptedText) {
        try {
            const decipher = crypto_1.default.createDecipher(this.algorithm, this.key);
            let decrypted = decipher.update(encryptedText, 'hex', 'utf8');
            decrypted += decipher.final('utf8');
            return decrypted;
        }
        catch (error) {
            console.error('Decryption failed:', error);
            throw new Error('Failed to decrypt data');
        }
    }
    /**
     * Encrypt object by converting to JSON first
     */
    static encryptObject(obj) {
        const jsonString = JSON.stringify(obj);
        return this.encrypt(jsonString);
    }
    /**
     * Decrypt object and parse JSON
     */
    static decryptObject(encryptedData) {
        const decryptedString = this.decrypt(encryptedData);
        return JSON.parse(decryptedString);
    }
    /**
     * Generate a secure random key for encryption
     */
    static generateKey() {
        return crypto_1.default.randomBytes(32).toString('hex');
    }
    /**
     * Generate a secure random IV
     */
    static generateIV() {
        return crypto_1.default.randomBytes(16).toString('hex');
    }
    /**
     * Hash sensitive data (one-way encryption)
     */
    static hash(data) {
        return crypto_1.default.createHash('sha256').update(data).digest('hex');
    }
    /**
     * Generate a secure random token
     */
    static generateToken() {
        return crypto_1.default.randomBytes(32).toString('hex');
    }
}
exports.EncryptionService = EncryptionService;
EncryptionService.algorithm = 'aes-256-cbc';
EncryptionService.key = Buffer.from(ENCRYPTION_KEY, 'utf8');
EncryptionService.iv = Buffer.from(ENCRYPTION_IV, 'utf8');
exports.default = EncryptionService;
