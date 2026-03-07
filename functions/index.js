const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize the admin SDK (uses the default service account when deployed)
admin.initializeApp();

/**
 * HTTP Cloud Function to migrate existing user documents by populating `fullName`
 * when it's missing and `firstName` / `lastName` are present.
 *
 * Security: supply a secret query param `?secret=...` which must match
 * `functions.config().migration.secret` (set with `firebase functions:config:set migration.secret="VALUE"`).
 * This avoids accidentally exposing the endpoint publicly.
 */
exports.migrateFullName = functions.https.onRequest(async (req, res) => {
  try {
    const requiredSecret = functions.config && functions.config().migration && functions.config().migration.secret
      ? functions.config().migration.secret
      : process.env.MIGRATION_SECRET;

    const provided = req.query.secret || req.get('x-migration-secret');
    if (requiredSecret) {
      if (!provided || provided !== requiredSecret) {
        res.status(403).send({error: 'Missing or invalid secret'});
        return;
      }
    }

    const firestore = admin.firestore();
    const usersRef = firestore.collection('users');

    const snapshot = await usersRef.get();
    let updatedCount = 0;
    const BATCH_LIMIT = 500;
    let batch = firestore.batch();
    let batchSize = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const hasFull = data.fullName && data.fullName.toString().trim().length > 0;
      const first = data.firstName ? data.firstName.toString().trim() : '';
      const last = data.lastName ? data.lastName.toString().trim() : '';

      if (!hasFull && (first.length > 0 || last.length > 0)) {
        const full = `${first} ${last}`.trim();
        if (full.length === 0) continue;
        batch.update(doc.ref, { fullName: full });
        batchSize++;
        updatedCount++;
      }

      if (batchSize >= BATCH_LIMIT) {
        await batch.commit();
        batch = firestore.batch();
        batchSize = 0;
      }
    }

    if (batchSize > 0) {
      await batch.commit();
    }

    res.status(200).send({ success: true, updated: updatedCount });
  } catch (err) {
    console.error('Migration error', err);
    res.status(500).send({ error: String(err) });
  }
});
