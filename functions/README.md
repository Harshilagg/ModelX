Migration Cloud Function — `migrateFullName`

What it does

- Iterates all documents in the `users` collection.
- For each document that does NOT have a non-empty `fullName` but has `firstName` or `lastName`, it sets `fullName` to `"<firstName> <lastName>"` (trimmed).
- Uses batched writes (up to 500 writes per batch) to stay within Firestore limits.
- Idempotent: running it multiple times won't overwrite existing `fullName` values.

Security

- The function checks for a migration secret. Configure it using:

  firebase functions:config:set migration.secret="YOUR_SECRET"

  You must pass the secret when calling the function, either as a query parameter `?secret=YOUR_SECRET` or the HTTP header `x-migration-secret: YOUR_SECRET`.

How to deploy

1. Install dependencies and deploy the function:

```bash
cd functions
npm install
firebase deploy --only functions:migrateFullName
```

2. Call the function (after deploy) using curl:

```bash
curl -X POST "https://REGION-PROJECT.cloudfunctions.net/migrateFullName?secret=YOUR_SECRET"
```

How to run locally (emulator)

1. Install dependencies:

```bash
cd functions
npm install
```

2. Start the functions emulator (requires Firebase CLI and Emulator setup):

```bash
firebase emulators:start --only functions
```

3. Invoke the HTTP endpoint exposed by the emulator. The emulator will print the local URL; you can also call the function via the CLI:

```bash
# Example using the functions emulator URL printed by the emulator
curl -X POST "http://localhost:5001/YOUR_PROJECT/us-central1/migrateFullName?secret=YOUR_SECRET"
```

Notes

- Make a backup or export of your Firestore data before running a migration in production.
- If your dataset is extremely large, consider running the migration in multiple passes or using a paginated query instead of loading all user docs at once.
