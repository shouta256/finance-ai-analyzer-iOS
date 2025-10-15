# Repository Guidelines

## Project Overview
- Safepocket is a SwiftUI personal finance client for the existing Safepocket API.
- Target Swift 5.10+, iOS 17+, and stable Xcode.

## Project Structure & Module Organization
- `Safepocket/` holds entrypoint code, assets (`Assets.xcassets`), and feature folders arranged `Features/<Feature>/View/` and `Features/<Feature>/ViewModel/` (e.g., `Features/Dashboard/...`); previews stay under `Preview Content/`.
- Tests mirror production layout in `SafepocketTests/` and `SafepocketUITests/`.

## Architecture Principles
- Adopt MVVM: Codable models map API JSON, SwiftUI views stay declarative, and view models (`ObservableObject`) expose `@Published` state.
- Inject services through view-model initializers; manual DI keeps wiring explicit.

## API Communication Rules
- Use `URLSession` with `async/await`; avoid third-party libraries.
- Collect requests in an `ApiClient` derived from `contracts/openapi.yaml` with typed endpoint methods.
- Authenticate via `ASWebAuthenticationSession`, persist JWTs in Keychain, and attach `Authorization: Bearer` headers automatically.

## UI/UX Development Guidelines
- Place reusable controls under `View/Components/`; prefer system SwiftUI components.
- Own view models with `@StateObject`; receive injected ones via `@ObservedObject`; keep view-local state with `@State`.
- Test light/dark mode and key Dynamic Type sizes; align with Apple HIG.

## Build, Test, and Development Commands
- `xed .` opens the project in Xcode.
- `xcodebuild -scheme Safepocket -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 15" build` for CI-style builds.
- `xcodebuild test -scheme Safepocket -destination "platform=iOS Simulator,name=iPhone 15"` runs unit and UI suites.

## Coding Style & Tooling
- Follow Swift API Design Guidelines; four-space indentation, ≤120-column lines, expressive names (`UpperCamelCase` types).
- Run SwiftLint before commits and address every warning.
- Prefer `async/await`; reach for Combine only when streaming pipelines are required.

## Testing Guidelines
- Place unit coverage beside features in `SafepocketTests/`; UI flows belong in `SafepocketUITests/`.
- Name tests `test_<Scenario>_<ExpectedBehavior>` and run `xcodebuild test` pre-push to keep touched files ≥80% covered; update snapshots or launch tests with UI changes.

## Commit & Pull Request Guidelines
- Use imperative subjects (e.g., “Implement dashboard totals”) and add risk or context in the body when behavior shifts.
- Keep commits focused and lint/test clean; avoid bundling unrelated work.
- PRs must describe changes, link issues, include test notes and UI screenshots, and request at least one review.

## Security & Configuration Tips
- Store secrets via local `.xcconfig` overlays and Keychain access—never in source.
- Document new entitlements or provisioning steps in PRs when integrations change.
- Audit asset catalogs before release to remove previews or placeholders.
