/**
 * ============================================================================
 * NMC PATHAN SCRIPT HUB - RENDER BACKEND & CRYPTOGRAPHIC VAULT
 * ============================================================================
 * Architecture:
 *   1. Anti-Browser & Anti-Inspection Perimeter Trap
 *   2. Ephemeral Nonce-Based Cryptographic Handshake (10s TTL)
 *   3. Shared Custom ARX Hash Signature Verification
 *   4. Dynamic Stream XOR Payload Delivery (In-Memory Encryption)
 * ============================================================================
 */

const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Shared cryptographic secret key (synced with loader.lua)
const SECRET_KEY = process.env.SECRET_KEY || 'NMC_PATHAN_SECURE_VAULT_KEY_2026_99X!';

// Path to protected Buy.lua vault file
const VAULT_FILE_PATH = path.join(__dirname, 'vault', 'Buy.lua');

// In-memory nonce vault (stores active nonces with 10-second expiration)
// Key: nonce (string) => Value: { placeId: string, createdAt: number }
const nonceStore = new Map();

// Periodic cleanup every 5 seconds to wipe stale nonces
setInterval(() => {
  const now = Date.now();
  for (const [nonce, data] of nonceStore.entries()) {
    if (now - data.createdAt > 10000) {
      nonceStore.delete(nonce);
    }
  }
}, 5000);

// Parse JSON request bodies
app.use(express.json({ limit: '1mb' }));

/**
 * Custom 128-bit ARX (Addition-Rotation-XOR) Hash Function.
 * Designed for 100% mathematical parity with Luau bit32 implementation.
 * Guarantees zero precision loss between 64-bit double float and 32-bit uint.
 *
 * @param {string} str
 * @returns {string} 32-character hexadecimal digest
 */
function customHash(str) {
  let h0 = 0x6a09e667 >>> 0;
  let h1 = 0xbb67ae85 >>> 0;
  let h2 = 0x3c6ef372 >>> 0;
  let h3 = 0xa54ff53a >>> 0;

  for (let i = 0; i < str.length; i++) {
    const c = str.charCodeAt(i);
    const rotH1 = ((h1 << 7) | (h1 >>> 25)) >>> 0;
    h0 = ((h0 + c) ^ rotH1) >>> 0;

    const rotH2 = ((h2 << 13) | (h2 >>> 19)) >>> 0;
    h1 = ((h1 + (c ^ (i & 0xff))) ^ rotH2) >>> 0;

    const rotH3 = ((h3 << 17) | (h3 >>> 15)) >>> 0;
    h2 = ((h2 + (h0 >>> 3)) ^ rotH3) >>> 0;

    const rotH0 = ((h0 << 11) | (h0 >>> 21)) >>> 0;
    h3 = ((h3 + (h1 >>> 5)) ^ rotH0) >>> 0;

    // Round mixing
    h0 = (h0 + h1) >>> 0;
    h2 = (h2 + h3) >>> 0;
    h1 = (h1 ^ h2) >>> 0;
    h3 = (h3 ^ h0) >>> 0;
  }

  const toHex8 = (n) => (n >>> 0).toString(16).padStart(8, '0');
  return toHex8(h0) + toHex8(h1) + toHex8(h2) + toHex8(h3);
}

/**
 * Dynamic Stream XOR Encryption
 * Encrypts arbitrary binary/string buffer using ephemeral key (nonce + SECRET_KEY).
 *
 * @param {Buffer} buffer - Raw file buffer of Buy.lua
 * @param {string} key - Nonce + SECRET_KEY string
 * @returns {string} Hex encoded ciphertext
 */
function encryptPayload(buffer, key) {
  const hexParts = [];
  const keyLen = key.length;

  for (let i = 0; i < buffer.length; i++) {
    const keyByte = key.charCodeAt(i % keyLen);
    const encryptedByte = buffer[i] ^ keyByte;
    hexParts.push(encryptedByte.toString(16).padStart(2, '0'));
  }

  return hexParts.join('');
}

/**
 * Standard Security Trap Response
 */
function sendAccessDenied(res) {
  return res.status(401).json({
    authorization: false,
    owner: 'NMC Pathan',
    error: 'Access Denied: Direct or Unauthorized Request Blocked!'
  });
}

/**
 * ============================================================================
 * ROUTE 1: PUBLIC HEALTH & STATUS (Allowed for Vercel Frontend)
 * ============================================================================
 * GET /api/status
 * Enables https://nmc-pathan.vercel.app to query backend live state.
 */
app.get('/api/status', cors({
  origin: '*',
  methods: ['GET', 'OPTIONS']
}), (req, res) => {
  res.status(200).json({
    status: 'online',
    protected: true,
    owner: 'NMC Pathan',
    service: 'NMC Pathan Vault Gateway',
    timestamp: Date.now()
  });
});

/**
 * ============================================================================
 * SECURITY PERIMETER TRAP MIDDLEWARE
 * ============================================================================
 * Intercepts and blocks all web browsers, cURL, Postman, or standard GET requests
 * to protected execution endpoints.
 */
function executorSecurityGuard(req, res, next) {
  const userAgent = (req.headers['user-agent'] || '').toLowerCase();
  const nmcClient = req.headers['x-nmc-client'];
  const placeId = req.headers['x-place-id'];

  // Block any browser-like User-Agents (Mozilla, Chrome, Safari, Edge, Postman, etc.)
  const browserPatterns = [
    'mozilla', 'chrome', 'safari', 'edge', 'firefox', 'opera',
    'postman', 'insomnia', 'curl', 'wget', 'python-requests'
  ];

  const isBrowserOrBot = browserPatterns.some(pattern => userAgent.includes(pattern));

  // Must strictly possess executor headers and MUST NOT be a browser inspection tool
  if (isBrowserOrBot || nmcClient !== 'Roblox-Executor' || !placeId) {
    return sendAccessDenied(res);
  }

  next();
}

/**
 * ============================================================================
 * ROUTE 2: STEP 1 HANDSHAKE - CHALLENGE REQUEST
 * ============================================================================
 * POST /api/challenge
 * Requires custom executor headers.
 * Generates an ephemeral cryptographic nonce with a strict 10-second TTL.
 */
app.post('/api/challenge', executorSecurityGuard, (req, res) => {
  try {
    const placeId = String(req.headers['x-place-id']).trim();

    // Generate 128-bit random cryptographic nonce
    const nonce = crypto.randomBytes(16).toString('hex');
    const timestamp = Date.now();

    // Store in memory
    nonceStore.set(nonce, {
      placeId,
      createdAt: timestamp
    });

    return res.status(200).json({
      authorized: true,
      nonce: nonce,
      timestamp: timestamp
    });
  } catch (err) {
    return sendAccessDenied(res);
  }
});

/**
 * ============================================================================
 * ROUTE 3: STEP 2 ENCRYPTED DELIVERY - EXECUTION REQUEST
 * ============================================================================
 * POST /api/execute
 * Verifies nonce freshness, enforces single-use burn, checks HMAC signature,
 * reads Buy.lua, encrypts payload via stream XOR, and delivers hex payload.
 */
app.post('/api/execute', executorSecurityGuard, (req, res) => {
  try {
    const placeId = String(req.headers['x-place-id']).trim();
    const { nonce, signature } = req.body || {};

    if (!nonce || !signature) {
      return sendAccessDenied(res);
    }

    // 1. Verify nonce existence in active vault memory
    const nonceRecord = nonceStore.get(nonce);
    if (!nonceRecord) {
      return sendAccessDenied(res);
    }

    // 2. Burn nonce immediately (Single-Use Defense against replay attacks)
    nonceStore.delete(nonce);

    // 3. Verify nonce freshness (under 10 seconds)
    const now = Date.now();
    if (now - nonceRecord.createdAt > 10000) {
      return sendAccessDenied(res);
    }

    // 4. Verify PlaceId match
    if (nonceRecord.placeId !== placeId) {
      return sendAccessDenied(res);
    }

    // 5. Verify mathematical signature parity
    const expectedData = `${nonce}:${placeId}:${SECRET_KEY}`;
    const expectedSignature = customHash(expectedData);

    if (signature !== expectedSignature) {
      return sendAccessDenied(res);
    }

    // 6. Check that hidden vault file exists
    if (!fs.existsSync(VAULT_FILE_PATH)) {
      return res.status(500).json({
        authorization: false,
        owner: 'NMC Pathan',
        error: 'Vault Error: Core script missing on server.'
      });
    }

    // 7. Read vault Buy.lua content
    const rawScriptBuffer = fs.readFileSync(VAULT_FILE_PATH);

    // 8. Dynamically stream-encrypt using key = nonce + SECRET_KEY
    const encryptionKey = nonce + SECRET_KEY;
    const encryptedHex = encryptPayload(rawScriptBuffer, encryptionKey);

    // 9. Deliver protected payload
    return res.status(200).json({
      authorized: true,
      payload: encryptedHex
    });
  } catch (err) {
    return sendAccessDenied(res);
  }
});

/**
 * ============================================================================
 * GLOBAL TRAP CATCH-ALL
 * ============================================================================
 * Catches all direct GET, PUT, DELETE, or any unhandled routes to return 401.
 */
app.all('*', (req, res) => {
  return sendAccessDenied(res);
});

// Start Express Server
app.listen(PORT, () => {
  console.log(`[NMC Pathan Vault] Server online on port ${PORT}`);
  console.log(`[NMC Pathan Vault] Core Buy.lua loaded: ${fs.existsSync(VAULT_FILE_PATH)}`);
});
