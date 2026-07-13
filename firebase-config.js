// ============================================================
// firebase-config.js — Global Standard Script (Non-Module)
// Compatibility: Runs perfectly on file:// protocol & web servers
// ============================================================

const firebaseConfig = {
  apiKey: "AIzaSyDPKKTZxAs3ey_9pPMdMOFDQXDSSKuK10w",
  authDomain: "ikill-4e337.firebaseapp.com",
  projectId: "ikill-4e337",
  storageBucket: "ikill-4e337.firebasestorage.app",
  messagingSenderId: "27384687475",
  appId: "1:27384687475:web:019a38523efb0e742ef306",
  measurementId: "G-QTZPFQPYSM"
};

// Initialize Firebase if the SDK is loaded globally
if (typeof firebase !== 'undefined') {
  if (!firebase.apps.length) {
    firebase.initializeApp(firebaseConfig);
  }
  // Auth — only available if firebase-auth-compat.js is loaded on the page
  try {
    window.auth = firebase.auth();
  } catch (e) {
    // Auth SDK not loaded on this page — safe to ignore
  }
  // Firestore — only available if firebase-firestore-compat.js is loaded on the page
  try {
    window.db = firebase.firestore();
  } catch (e) {
    console.warn('Firestore SDK not loaded on this page.');
  }
} else {
  console.warn("Firebase SDK not loaded yet. Make sure to include Firebase Compat CDN scripts before this script.");
}
