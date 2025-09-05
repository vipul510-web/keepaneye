"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initializeFirebase = initializeFirebase;
exports.getFirebaseApp = getFirebaseApp;
exports.sendPushNotification = sendPushNotification;
exports.sendMulticastNotification = sendMulticastNotification;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
let firebaseApp;
async function initializeFirebase() {
    try {
        if (!process.env.FIREBASE_PROJECT_ID) {
            throw new Error('Firebase project ID not configured');
        }
        // Check if Firebase is already initialized
        if (firebaseApp) {
            return;
        }
        // Initialize Firebase Admin SDK
        firebaseApp = firebase_admin_1.default.initializeApp({
            credential: firebase_admin_1.default.credential.cert({
                projectId: process.env.FIREBASE_PROJECT_ID,
                privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
                clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            }),
            projectId: process.env.FIREBASE_PROJECT_ID,
        });
        console.log('✅ Firebase Admin SDK initialized successfully');
    }
    catch (error) {
        console.error('❌ Firebase initialization failed:', error);
        throw error;
    }
}
function getFirebaseApp() {
    if (!firebaseApp) {
        throw new Error('Firebase not initialized. Call initializeFirebase() first.');
    }
    return firebaseApp;
}
async function sendPushNotification(token, title, body, data) {
    try {
        const message = {
            token,
            notification: {
                title,
                body,
            },
            ...(data && { data }),
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    priority: 'high',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };
        const response = await firebase_admin_1.default.messaging().send(message);
        console.log('✅ Push notification sent successfully:', response);
        return response;
    }
    catch (error) {
        console.error('❌ Failed to send push notification:', error);
        throw error;
    }
}
async function sendMulticastNotification(tokens, title, body, data) {
    try {
        const message = {
            tokens,
            notification: {
                title,
                body,
            },
            ...(data && { data }),
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    priority: 'high',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };
        const response = await firebase_admin_1.default.messaging().sendMulticast(message);
        console.log('✅ Multicast notification sent successfully');
        console.log(`📱 Success: ${response.successCount}, Failed: ${response.failureCount}`);
        return response;
    }
    catch (error) {
        console.error('❌ Failed to send multicast notification:', error);
        throw error;
    }
}
exports.default = firebaseApp;
