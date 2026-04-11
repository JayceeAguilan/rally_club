# rally_club

A new Flutter project.

## Mobile-First Website Release

This project can now be released as a mobile-first website using Flutter web and Firebase Hosting.

- The website is optimized primarily for phone-sized browsers.
- Desktop browsers remain usable, but the phone layout is the main target.
- Firebase Auth and Firestore work on web using the generated Firebase web config.
- Browser push notifications are intentionally out of scope for the first web release.
- Announcement awareness on web uses the existing in-app unread badges and dashboard reminders.

Build the website locally:

```bash
flutter build web
```

Deploy the built website with Firebase Hosting:

```bash
firebase deploy --only hosting
```

Before the first production release, also verify these Firebase Console settings:

- Add your final hosting domain to Firebase Authentication `Authorized domains`.
- Confirm the Firebase web app configuration matches the deployed domain and project.
- Keep Firestore rules and indexes deployed before inviting users to the website.

## Vercel Deployment

This repo now includes a Vercel build path for the Flutter web app.

Files used by Vercel:

- [vercel.json](vercel.json)
- [scripts/vercel-install.sh](scripts/vercel-install.sh)
- [scripts/vercel-build.sh](scripts/vercel-build.sh)

How to deploy:

1. Push this repository to GitHub.
2. Import the repository into Vercel.
3. Keep the root directory as the repository root.
4. Let Vercel use the repo config from [vercel.json](vercel.json).
5. Trigger the first deployment.

Important Firebase step after Vercel gives you a deployment domain:

- Add the Vercel domain (for example `your-project.vercel.app`) to Firebase Authentication `Authorized domains`.

Recommended release flow:

1. Deploy once to get the Vercel domain.
2. Add that domain in Firebase Console.
3. Redeploy if needed.
4. Test sign-in, announcements, unread badges, and player management on phone browsers.

Notes:

- Browser push notifications are still intentionally out of scope for the website release.
- The website relies on the existing in-app unread announcement indicators instead.
- Vercel is hosting the generated Flutter web build; Firebase continues to provide Auth, Firestore, and backend services.

## Announcements Feature

The app now includes a club announcements feed for scheduled play sessions.

- Admins can post announcements with a title, date/time, and location.
- Members can open any announcement and add comments to respond.
- Comment authors can edit or delete their own comments.
- Admins can delete any comment in the announcement thread.
- Members now get Spark-safe in-app unread badges and dashboard reminders for new announcements.
- Announcement awareness is intentionally in-app only, so no Cloud Functions or push-topic setup is required.

## Optional Functions Folder

The `functions/` folder is kept only for optional backend automation.

- It is not required for the app's current Spark-safe setup.
- It should be treated as Blaze-only infrastructure.
- If your project stays on Spark, ignore that folder and do not deploy Cloud Functions.
- If you are on Blaze and want those optional triggers, use the instructions in `functions/README.md`.

For Spark projects, prefer scoped deploy commands such as:

```bash
firebase deploy --only hosting,firestore
```

## Email Verification Setup

This app uses Firebase Auth's built-in email verification flow during registration.

How it works:

- After a player creates an account, the app sends a Firebase verification email.
- Unverified users are blocked by the auth gate and shown the verification screen.
- The user must open the email link before they can enter the app.
- If the link opens outside the app, the verification screen also accepts the full link or action code manually.

Typical setup for Firebase Auth email verification:

```bash
flutter pub get
```

Make sure Email/Password authentication is enabled in your Firebase Authentication settings. No custom email API provider, SMTP setup, or Cloud Functions deployment is required for the built-in verification-link flow.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
