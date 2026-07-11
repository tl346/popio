# Popio

## Vision

Popio helps people discover and share local pop-up experiences that are easy to miss.

Unlike traditional event platforms that focus on large organized events, Popio focuses on community-discovered experiences such as:

* Matcha pop-ups
* Card shows
* Food trucks
* Vendor markets
* Anime events
* Community gatherings
* Temporary shops
* Seasonal attractions

The goal is to become the easiest way to discover what's happening nearby right now.

---

# Initial Goals

The first version should be intentionally simple.

Users can:

1. Create an account
2. Add friends
3. Create and publish events
4. View events created by other users

Anything beyond this is considered a future feature.

---

# Target Users

### Primary Users

People who enjoy discovering local experiences and hidden events.

Examples:

* Food enthusiasts
* Matcha lovers
* Collectors
* Hobby communities
* College students
* Young professionals

### Event Creators

Users who discover or host local events and want to share them with others.

---

# Core Features

## User Accounts

Users should be able to:

* Register
* Login
* Logout
* Edit profile

### User Profile Fields

* User ID
* Username
* Display Name
* Email
* Profile Picture URL
* Created Date

---

## Friend System

Users can:

* Search users
* Send friend requests
* Accept friend requests
* Remove friends

### Friend Request Status

* Pending
* Accepted
* Declined

---

## Event Creation

Users can create events.

### Event Fields

* Event ID
* Title
* Description
* Category
* Address
* Event Date
* Event Start Time
* Event End Time
* Created By User ID

### Categories

Initial categories:

* Food
* Matcha
* Cards

---

## Event Feed

All users can view all approved events.

Feed should display:

* Event title
* Event image
* Category
* Distance from user
* Event date
* Creator username

---

## Event Details

Tapping an event should display:

* Full event information
* Event image
* Creator profile
* Location
* Date and time

---


# Technical Stack

## Frontend

* SwiftUI
* MVVM Architecture

## Backend

* Firebase Authentication
* Firestore Database
* Firebase Storage

## Future Ready

Architecture should support:

* Feature Flags
* Push Notifications
* Premium Features
* Business Accounts
* Moderation System

without requiring major refactors.

---

# Folder Structure

Features/
├── Authentication/
├── Friends/
├── Events/
├── Profile/

Core/
├── Networking/
├── Firebase/
├── Models/
├── Services/
├── DesignSystem/

---

# Database Collections

users

friend_requests

friends

events

---

# Success Criteria

A user should be able to:

1. Download Popio
2. Create an account
3. Add a friend
4. Create an event
5. Have the event immediately visible to all users

If these actions work reliably, MVP (minimum viable product) is considered complete.

---

# Future Roadmap

Phase 2

* Save events
* Event likes
* Event comments
* Push notifications

Phase 3

* Business accounts
* Featured listings
* Premium subscriptions

Phase 4

* AI-powered recommendations
* Trending events
* Personalized discovery feed

Long-Term Vision

Become the go-to platform for discovering community-driven pop-up experiences that are often missed by traditional event platforms.
