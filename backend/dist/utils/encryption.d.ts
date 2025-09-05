export declare class EncryptionService {
    private static algorithm;
    private static key;
    private static iv;
    /**
     * Encrypt data before sending to server
     */
    static encrypt(text: string): string;
    /**
     * Decrypt data received from server
     */
    static decrypt(encryptedText: string): string;
    /**
     * Encrypt object by converting to JSON first
     */
    static encryptObject(obj: any): string;
    /**
     * Decrypt object and parse JSON
     */
    static decryptObject(encryptedData: string): any;
    /**
     * Generate a secure random key for encryption
     */
    static generateKey(): string;
    /**
     * Generate a secure random IV
     */
    static generateIV(): string;
    /**
     * Hash sensitive data (one-way encryption)
     */
    static hash(data: string): string;
    /**
     * Generate a secure random token
     */
    static generateToken(): string;
}
export default EncryptionService;
//# sourceMappingURL=encryption.d.ts.map