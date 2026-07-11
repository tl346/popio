# Popio iOS

Popio is a SwiftUI iOS application for discovering and sharing local pop-up experiences.

## MVP Scope

- Create an account, login, logout, and edit profile.
- Search users, send friend requests, accept requests, and remove friends.
- Create and publish events in the Food, Matcha, and Cards categories.
- Detect likely duplicate pop-up submissions by comparing event name and location similarity before publishing.
- View approved events in a public feed and open full event details.

## Architecture

- `Popio/Core/Models` contains the user, friend request, and event models.
- `Popio/Core/Networking` contains environment configuration.
- `Popio/Core/Firebase` contains the Firebase bootstrap boundary.
- `Popio/Core/Services` contains app session state, feature flags, and Firebase-ready service protocols.
- `Popio/Core/DesignSystem` contains shared colors and UI components.
- `Popio/Features` contains SwiftUI MVVM feature areas for authentication, friends, events, and profile.
- `Popio/Root` contains the authenticated tab shell.

## Run

Open `Popio.xcodeproj` in Xcode and run the app scheme on an iPhone simulator.

The initial implementation uses in-memory data so the app is usable before Firebase is configured. The service protocols are ready for Firebase Authentication, Firestore, and Storage adapters.
