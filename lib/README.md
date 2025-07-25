
# Refactored Flutter Firebase App

This project follows **Clean Architecture** with **Riverpod**, **Firebase Authentication**, and **Cloud Firestore**.

## Project Structure

```
lib/
  core/
    di/                # Dependency Injection
    router/            # GoRouter configuration
  features/
    auth/
      domain/          # AuthState, models, abstract repositories
      data/            # FirebaseAuth repository & Firestore user repository
      application/     # AuthController (Notifier)
    profile/
      domain/          # ProfileSetupData
      data/            # Profile Firestore provider
      application/     # ProfileSetupController (Notifier)
  screens/             # UI screens (SignIn, SignUp, Profile setup, Home, etc.)
main.dart
```

## Key Principles

1. **Domain Layer**
   - Pure Dart models and abstract repository interfaces.
   - No Flutter or Firebase dependencies.

2. **Data Layer**
   - Implements repositories using Firebase Auth and Firestore.
   - Maps raw Firebase data to domain models.

3. **Application Layer**
   - Contains Riverpod Notifiers (Controllers).
   - Coordinates between UI and repositories.

4. **UI Layer (Screens)**
   - Uses `ref.watch` and `ref.read` to interact with controllers.
   - No direct Firebase/Firestore access.

## How to Run

1. Install dependencies:

```bash
flutter pub get
```

2. Configure Firebase for your app:

- Add your Firebase project configuration files (GoogleService-Info.plist for iOS, google-services.json for Android).

3. Run the app:

```bash
flutter run
```

## Routing

The app uses **GoRouter** with a `RouterNotifier` that automatically redirects users based on authentication state:

- `/login` – Sign in screen
- `/signup` – Sign up screen
- `/complete-profile`, `/chronotype`, `/sleep-schedule` – Profile setup flow
- `/` – Main home screen (Insights + Settings)

## Features

- Email/password and Google sign-in with Firebase.
- Firestore-based user profile storage.
- Profile completion flow.
- Clean architecture for testable, scalable code.

## Diagram

```
UI (screens)
   ↓
Application Layer (Controllers / Notifiers)
   ↓
Domain Layer (Abstract repositories & Models)
   ↓
Data Layer (FirebaseAuth & Firestore implementations)
   ↓
Firebase (Auth, Firestore)
```
