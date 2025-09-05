import admin from 'firebase-admin';
declare let firebaseApp: admin.app.App | undefined;
export declare function initializeFirebase(): Promise<void>;
export declare function getFirebaseApp(): admin.app.App;
export declare function sendPushNotification(token: string, title: string, body: string, data?: Record<string, string>): Promise<string>;
export declare function sendMulticastNotification(tokens: string[], title: string, body: string, data?: Record<string, string>): Promise<admin.messaging.BatchResponse>;
export default firebaseApp;
//# sourceMappingURL=firebase.d.ts.map