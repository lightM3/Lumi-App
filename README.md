# Lumi - Elevating Visual Discovery

> A robust, high-performance Flutter application designed for seamless visual discovery, curation, and inspiration.

| Home Feed Placeholder | Collection Details Placeholder |
| :---: | :---: |
| <img src="feed_screen.png" width="250" alt="Home Feed Screen"/> | <img src="profile_screen.png" width="250" alt="Profile Screen"/> |

---

## 💻 Tech Stack

- **Language:** Dart (Flutter)
- **Architecture:** Feature-First Layered Architecture (Data, Domain, Presentation)
- **UI:** Custom Glassmorphism UI, Material 3, `flutter_staggered_grid_view`
- **State Management & Dependency Injection:** Riverpod (`flutter_riverpod`)
- **Local Data & Caching:** `cached_network_image`, `shared_preferences`
- **Networking & BaaS:** Supabase (`supabase_flutter`)
- **Routing:** GoRouter

---

## 🏗 Architecture & Design Decisions

The application is built with a strong emphasis on **Separation of Concerns** and **Testability**. By adopting a feature-first approach combined with a layered domain-driven design, the codebase remains highly modular, scalable, and easy to navigate. 

### Folder Structure

```text
lib/
├── core/                   # Shared utilities, constants, exceptions, routing
├── features/               # Feature-centric modules
│   ├── auth/               # Authentication logic & UI
│   │   ├── data/           # Repositories & DTOs
│   │   ├── domain/         # Interfaces & Models
│   │   └── presentation/   # Controllers, Screens, Widgets
│   ├── curation/           # Collection management
│   ├── feed/               # Main discovery feed
│   ├── notifications/      # Real-time updates
│   ├── profile/            # User profile, boards, and followers
│   └── search/             # Querying & filtering
└── main.dart               # App entry point & provider scope
```

### SOLID Principles in Action

- **Dependency Inversion Principle (DIP):** The presentation layer depends on domain interfaces (e.g., `AuthRepository`, `FeedRepository`), not concrete implementations. Supabase implementations (`SupabaseAuthRepository`) are injected via Riverpod providers, allowing seamless swapping for mock repositories during testing.
- **Single Responsibility Principle (SRP):** Business logic is completely isolated from UI. `Controllers` (Notifiers) handle state mutations, `Repositories` handle data fetching, and `Widgets` are strictly responsible for rendering.

---

## ⚡ Key Features & Engineering

- **Robust State Synchronization:** Features complex cross-screen state invalidation. Actions like toggling a collection's privacy instantly invalidate parent feed states, ensuring UI consistency without redundant network calls.
- **Advanced UI & Custom Animations:** Implementation of high-performance glassmorphism aesthetics, completely custom bottom navigation elements, and micro-interactions optimized for 60fps rendering.
- **Generic Action Guards:** A centralized `GuestGuard` utility intercepts authenticated actions (likes, follows, curations) using an elegant bottom sheet, bypassing deep logic nesting and keeping the UI layer declarative.
- **Scalable Network & Data Layer:** Efficient handling of relational data via Supabase, complemented by aggressive image caching and optimization techniques (`flutter_image_compress`, `cached_network_image`) to prevent memory leaks and UI thread blocking.

---

## 🧪 CI/CD & Quality Assurance

- **Testing:** 
  - **Unit tests for Business Logic:** Isolating state controllers and repository layers using `mocktail` to ensure predictable data flows.
  - **UI tests for critical flows:** Validating widget trees and modal behaviors (e.g. , Authentication Prompts, Guest Guards) in isolated `ProviderScope` environments.
- **Automation & Code Quality:**
  - Automated **Linting** utilizing `flutter analyze` and custom lint rules to enforce strict Dart practices.
  - Test suites are designed for seamless integration into **GitHub Actions** for continuous integration.

---

## 🚀 Future Improvements

- **Boost unit test coverage to 90%+** to ensure absolute confidence in edge-case handling.
- **Transition to a fully Modularization (Multi-package) architecture** to completely isolate features into their own independent Dart packages, further reducing build times and enforcing strict boundaries.

---

## 🛠 Getting Started

To run this project locally, ensure you have the Flutter SDK installed on your machine.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/lightM3/Lumi-App.git
   cd Lumi-App
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment:**
   Add your `.env` file containing your Supabase credentials to the root directory.
   ```text
   SUPABASE_URL=your_url_here
   SUPABASE_ANON_KEY=your_anon_key_here
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```
 