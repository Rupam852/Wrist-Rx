const admin = require('firebase-admin');

function initFirebase() {
  if (admin.apps.length > 0) return; // Already initialized

  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      }),
      storageBucket: `${process.env.FIREBASE_PROJECT_ID}.firebasestorage.app`,
    });
    console.log('✅ Firebase Admin initialized');
  } catch (error) {
    console.error('❌ Firebase Admin initialization failed:', error);
    throw error;
  }
}

async function verifyFirebaseToken(token) {
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded;
}

module.exports = { initFirebase, verifyFirebaseToken };
