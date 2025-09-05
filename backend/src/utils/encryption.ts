import crypto from 'crypto';
import dotenv from 'dotenv';

dotenv.config();

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'default-32-char-encryption-key-here';
const ENCRYPTION_IV = process.env.ENCRYPTION_IV || 'default-16-char-iv';

export class EncryptionService {
  private static algorithm = 'aes-256-cbc';
  private static key = Buffer.from(ENCRYPTION_KEY, 'utf8');
  private static iv = Buffer.from(ENCRYPTION_IV, 'utf8');

  /**
   * Encrypt data before sending to server
   */
  static encrypt(text: string): string {
    try {
      const cipher = crypto.createCipher(this.algorithm, this.key);
      let encrypted = cipher.update(text, 'utf8', 'hex');
      encrypted += cipher.final('hex');
      return encrypted;
    } catch (error) {
      console.error('Encryption failed:', error);
      throw new Error('Failed to encrypt data');
    }
  }

  /**
   * Decrypt data received from server
   */
  static decrypt(encryptedText: string): string {
    try {
      const decipher = crypto.createDecipher(this.algorithm, this.key);
      let decrypted = decipher.update(encryptedText, 'hex', 'utf8');
      decrypted += decipher.final('utf8');
      return decrypted;
    } catch (error) {
      console.error('Decryption failed:', error);
      throw new Error('Failed to decrypt data');
    }
  }

  /**
   * Encrypt object by converting to JSON first
   */
  static encryptObject(obj: any): string {
    const jsonString = JSON.stringify(obj);
    return this.encrypt(jsonString);
  }

  /**
   * Decrypt object and parse JSON
   */
  static decryptObject(encryptedData: string): any {
    const decryptedString = this.decrypt(encryptedData);
    return JSON.parse(decryptedString);
  }

  /**
   * Generate a secure random key for encryption
   */
  static generateKey(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  /**
   * Generate a secure random IV
   */
  static generateIV(): string {
    return crypto.randomBytes(16).toString('hex');
  }

  /**
   * Hash sensitive data (one-way encryption)
   */
  static hash(data: string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  /**
   * Generate a secure random token
   */
  static generateToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }
}

export default EncryptionService; 