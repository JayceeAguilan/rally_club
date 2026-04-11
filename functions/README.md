# Optional Cloud Functions

This folder is kept in the repository for optional backend automation.

Important:

- This app's core experience does not require deploying anything from this folder.
- Spark-compatible app behavior already works without Cloud Functions.
- Firebase Cloud Functions deployment is not supported on the Spark plan.
- Only use this folder if you are on the Blaze plan and explicitly want optional backend triggers.

What still works without this folder:

- Firebase Auth sign-in and registration
- Firestore data reads and writes
- DUPR rating updates handled directly in the app
- Announcements feed, unread badges, and dashboard reminders

Blaze-only usage:

```bash
npm install
npm run deploy:blaze
```

If you are staying on Spark, ignore this folder and deploy only the Firebase products you actually use, such as Hosting and Firestore.
