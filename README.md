# Hive Posts & Favorites App 📱📦

[![Flutter](https://img.shields.io/badge/Flutter-3.47.8-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.7-0175C2?logo=dart)](https://dart.dev)
[![Hive](https://img.shields.io/badge/Hive-2.2.3-orange)](https://pub.dev/packages/hive)
[![Status](https://img.shields.io/badge/Tests-18%20Passed-brightgreen)](https://github.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An offline-first Flutter application featuring local NoSQL storage with **Hive**, automatic offline caching, cache fallback resilience, and an independent favorites system. Built for **Fall 2026 | Section 5 (Hive Local NoSQL Storage)**.

---

## 📖 Table of Contents
1. [Overview & Objectives](#overview--objectives)
2. [Data Flow & Architecture](#data-flow--architecture)
3. [Hive Concepts & Key Implementation Details](#hive-concepts--key-implementation-details)
4. [Project Directory Structure](#project-directory-structure)
5. [Prerequisites & Dependencies](#prerequisites--dependencies)
6. [Getting Started & Running the App](#getting-started--running-the-app)
7. [Automated Testing & Static Analysis](#automated-testing--static-analysis)
8. [Manual Offline Testing Procedure](#manual-offline-testing-procedure)
9. [Screenshots Checklist](#screenshots-checklist)

---

## 🎯 Overview & Objectives

In modern mobile engineering, applications must handle network volatility and offline states gracefully without crashing or showing blank screens. This project implements a local NoSQL database between the remote REST API (`https://jsonplaceholder.typicode.com/posts`) and the UI layer.

### Key Objectives:
- **Differentiate storage mechanisms:** Contrast simple key-value storage (`SharedPreferences`) with binary object storage (`Hive`).
- **NoSQL implementation:** Utilize Hive boxes, `TypeAdapter`s, and binary serialization.
- **Offline-first fallback:** Fetch from remote API when online, cache responses into Hive, and seamlessly retrieve cached posts when offline.
- **Independent Favorites system:** Implement persistent favorites using a separate Hive box that survives network refreshes and app restarts.
- **HiveObject boundary compliance:** Respect the strict rule that a `HiveObject` instance can only reside in a single box at a time by cloning objects.

---

## 🏗️ Data Flow & Architecture

### Online vs. Offline Flow

```
[Online Mode]
  User opens app ──► API Request (http.get) ──► HTTP 200 OK ──► postsBox.clear() ──► postsBox.addAll() ──► UI Display
                                                                      │
                                                             Cached to Hive

[Offline Mode / Airplane Mode]
  User opens app ──► API Request fails ──► Fallback to postsBox.values ──► UI Display from Cache

[No Internet & No Cache]
  User opens fresh app offline ──► API fails & postsBox is empty ──► Displays "No Internet and No Cached Data" Error State
```

### High-Level Component Layers

```
lib/
├── models/
│   ├── post_model.dart            # Post entity extending HiveObject (@HiveType(typeId: 0))
│   └── post_model.g.dart          # Generated TypeAdapter (PostAdapter)
├── services/
│   ├── post_service.dart          # Handles API fetching + postsBox cache logic
│   └── favorites_service.dart     # Manages favoritesBox (toggle, query, clone safe)
├── screens/
│   ├── posts_screen.dart          # Posts UI (FutureBuilder, RefreshIndicator, Star buttons)
│   └── favorites_screen.dart      # Favorites UI (ValueListenableBuilder, real-time sync)
└── main.dart                      # App entrypoint, Hive initialization, early box opening
```

---

## 🧠 Hive Concepts & Key Implementation Details

### 1. SharedPreferences vs. Hive

| Feature | SharedPreferences | Hive |
|---|---|---|
| **Best For** | Small primitives (`isLoggedIn`, tokens) | Complex objects & large lists (`List<Post>`, Cart, Favorites) |
| **Speed on Large Data** | Slow (synchronous XML / disk read) | Blazing fast (in-memory binary index) |
| **Offline Support** | Yes | Yes (No server or API key required) |
| **Data Storage** | String key-value pairs | Any Dart object (via `TypeAdapter`) |

### 2. TypeAdapters & Code Generation
Custom Dart classes cannot be written to binary storage directly. Hive uses generated `TypeAdapter`s:
- `@HiveType(typeId: 0)` annotates the model class.
- `@HiveField(n)` annotates each serialized property (indices must never be reused or renumbered).
- Adapters are generated using `build_runner`:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

### 3. The HiveObject Single-Box Limitation (Crucial Warning)
> **Warning from Lab Section 5.3:**
> A `HiveObject` can only live in **one box at a time**. If you attempt to store the same instance from `postsBox` directly into `favoritesBox`, Hive throws an error.

**Our Implementation in `FavoritesService`:**
```dart
Future<void> toggleFavorite(Post post) async {
  if (isFavorite(post.id)) {
    await _box.delete(post.id);
  } else {
    // Create a copy of the Post object to avoid HiveObject single-box conflict
    final copy = Post(
      id: post.id,
      title: post.title,
      body: post.body,
      userId: post.userId,
    );
    await _box.put(post.id, copy);
  }
}
```

### 4. Dual-Box Architecture
`postsBox` and `favoritesBox` are completely decoupled. When `post_service.dart` refreshes posts online, it clears `postsBox` (`await box.clear()`) to sync new posts from the API. Because favorites reside in `favoritesBox`, user favorites are **never** accidentally erased during a network refresh.

---

## 📁 Project Directory Structure

```
hive_posts_app/
├── lib/
│   ├── main.dart                      # Starts Hive, registers PostAdapter, opens boxes, runs app
│   ├── models/
│   │   ├── data.dart                  # Part 1: Data model (@HiveType(typeId: 1))
│   │   ├── data.g.dart                # Part 1: Generated DataAdapter
│   │   ├── post_model.dart            # Part 2: Post model (@HiveType(typeId: 0))
│   │   └── post_model.g.dart          # Part 2: Generated PostAdapter
│   ├── services/
│   │   ├── post_service.dart          # Posts API + postsBox caching fallback logic
│   │   └── favorites_service.dart     # favoritesBox CRUD operations + instance cloning
│   └── screens/
│       ├── posts_screen.dart          # Posts feed, error recovery, pull-to-refresh, star icons
│       └── favorites_screen.dart      # Real-time favorites list via ValueListenableBuilder
├── test/
│   ├── models_test.dart               # Unit tests for Data and Post models + adapters
│   ├── post_service_test.dart         # Unit tests for offline caching and fallback
│   ├── favorites_service_test.dart    # Tests for favorites toggle, persistence & single-box safety
│   └── widget_test.dart               # Widget tests for PostsScreen and FavoritesScreen
├── screenshots/                       # Directory for feature and offline proof screenshots
├── pubspec.yaml                       # Project dependencies matching lab specification
└── README.md                          # Comprehensive project documentation
```

---

## 📦 Prerequisites & Dependencies

### Environment:
- **Flutter SDK:** `>= 3.0.0` (Tested on `Flutter 3.47.8`)
- **Dart SDK:** `>= 3.0.0` (Tested on `Dart 3.13.7`)

### Exact Package Constraints (`pubspec.yaml`):
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.1.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  connectivity_plus: ^5.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  hive_generator: ^2.0.1
  build_runner: ^2.4.7
```

---

## 🚀 Getting Started & Running the App

### 1. Clone the repository
```bash
git clone https://github.com/<your-username>/hive_posts_app.git
cd hive_posts_app
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Generate Hive Adapters
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the application
Run on your connected emulator, device, or desktop target:
```bash
# Run on Windows Desktop
flutter run -d windows

# Run on Chrome / Web
flutter run -d chrome

# Run on connected Android / iOS device
flutter run
```

---

## 🧪 Automated Testing & Static Analysis

This repository includes a 100% passing automated test suite covering models, service logic, Hive isolation, and widget UI states.

### 1. Static Analysis
Verify that all Dart code is compliant with zero warnings or errors:
```bash
flutter analyze
```
*Result: `No issues found! (ran in 3.5s)`*

### 2. Run All Automated Tests
```bash
flutter test
```
*Result: `All 18 tests passed!`*

### Automated Test Breakdown:
- **`test/models_test.dart` (5 tests):**
  - Verifies instantiation and field mapping for `Data` and `Post`.
  - Verifies `Post.fromJson` deserialization.
  - Verifies `typeId` integrity (`PostAdapter.typeId == 0`, `DataAdapter.typeId == 1`).
- **`test/favorites_service_test.dart` (5 tests):**
  - Verifies `isFavorite` query for saved and unsaved posts.
  - Verifies adding/removing favorites via `toggleFavorite`.
  - Verifies post cloning avoids the `HiveObject` single-box collision error.
  - Verifies favorites persistence across simulated application restarts (closing and reopening box).
- **`test/post_service_test.dart` (5 tests):**
  - Verifies HTTP 200 response caches to Hive and returns online posts.
  - Verifies non-200 HTTP responses fall back to cached Hive posts.
  - Verifies network failure (`SocketException`) falls back to cached Hive posts.
  - Verifies network failure with empty cache throws `'No Internet and No Cached Data'`.
  - Verifies non-200 status with empty cache throws `'No Internet and No Cached Data'`.
- **`test/widget_test.dart` (3 tests):**
  - Verifies `PostsScreen` renders AppBar with favorites star action button.
  - Verifies `FavoritesScreen` displays the friendly `"No favorites yet"` empty state.
  - Verifies `FavoritesScreen` renders favorite cards when items exist in `favoritesBox`.

---

## 📶 Manual Offline Testing Procedure

Follow these 4 verification steps from **Page 10 of Section 5.pdf**:

| # | Action | Expected Result | Console Log / UI Output |
|---|---|---|---|
| **1** | Run the app with internet enabled | Posts load successfully from API | `Loaded from API and cached to Hive: 100` |
| **2** | Star a few posts (e.g. #1, #2), then close the app and enable **Airplane Mode** | App closes; favorites persist | - |
| **3** | Reopen the app while still in **Airplane Mode** | Cached posts appear immediately; starred posts retain filled star | `Loaded from Hive offline: 100` |
| **4** | Uninstall app / clear app storage, keep **Airplane Mode** on, then launch app | Error screen appears with retry button | `Error: Exception: No Internet and No Cached Data` |

---

## 📸 Screenshots Checklist

When preparing your final lab submission, take screenshots and place them in the `screenshots/` directory:

1. **`01_posts_screen_online.png`**: Posts screen loaded with active internet connection showing posts feed and star icons.
2. **`02_posts_screen_favorites_selected.png`**: Posts screen with selected items showing filled amber stars.
3. **`03_favorites_screen_empty.png`**: Favorites screen showing `"No favorites yet"` empty state message and icon.
4. **`04_favorites_screen_populated.png`**: Favorites screen listing the saved favorite posts matching the card design.
5. **`05_offline_posts_cached.png`**: Posts screen opened in Airplane mode displaying cached posts and console log `"Loaded from Hive offline"`.
6. **`06_offline_error_empty_cache.png`**: Fresh launch in Airplane mode with empty cache showing `"Error: Exception: No Internet and No Cached Data"`.

---

## 📜 Submission Details

- **Course:** Fall 2026 | Section 5
- **Lab Topic:** Hive (Local NoSQL Storage) & Offline Architecture
- **Deadline:** November 20, 2026, by 11:59 PM
