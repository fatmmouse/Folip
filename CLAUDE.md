<!-- GSD:project-start source:PROJECT.md -->
## Project

**Folip**

Folip is a minimal cross-platform file delivery tool for personal multi-device use. It lets you quickly send files from your Mac to your other devices (Android, iPad), with the receiving device able to pick them up later — no need for both devices to be online at the same time. Think "file dropbox" not "cloud drive."

**Core Value:** A user can send a file from one device and pick it up on another device at any time — the receiving device does not need to be online when the file is sent.

### Constraints

- **Cloud provider**: Alibaba Cloud (阿里云) — user has existing services
- **Desktop**: Tauri for Mac — lightweight native wrapper with system integration
- **Mobile**: Flutter or React Native — cross-platform for Android (and later iPad)
- **Auth**: Email + password for MVP
- **File size**: Up to 500MB per file
- **Storage**: Temporary transit only — files expire and auto-delete (not long-term storage)
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Tauri | 2.x (v2.0 released Oct 2024) | Mac desktop app shell | Lighter than Electron (~8MB binary vs ~150MB), native Rust backend, first-class system tray and macOS shell extension support via plugins. v2 added mobile targets and a mature plugin API. |
| Flutter | 3.24+ | Android mobile app | Single codebase that also covers future iPad target (already in PROJECT.md v2 scope). Dart is strongly typed, hot reload is fast, and the file I/O + HTTP story on Android is well-established. Significantly better Android integration than React Native for file pickers and background tasks. |
| Rust (Tauri backend) | 1.79+ (MSRV for Tauri 2) | Mac-side logic: file reading, Finder extension IPC, upload orchestration | Tauri commands are plain Rust async functions. No separate Node backend is needed for the Mac app; all file I/O and upload logic lives in Rust. |
| Alibaba Cloud OSS | OSS SDK for Rust / Dart | Transit file storage | Aliyun OSS supports multipart upload natively (up to 48.8TB per object, 5GB per part). For 500MB files, multipart upload with resumable upload is the correct primitive. User already has existing Aliyun account. |
| Alibaba Cloud Function Compute (FC) | FC 3.0 | API / business logic layer | Serverless HTTP API for auth, device registry, file metadata, and presigned URL generation. No ECS to manage. FC 3.0 (released 2023) supports Node.js 18, Python 3.10, Java 17 runtimes. For this use case — infrequent API calls — FC is cheaper and simpler than ECS. |
| JWT (JSON Web Tokens) | — | Stateless auth tokens | Standard for serverless auth. FC functions are stateless so session-based auth doesn't apply. Issue JWT on login, verify on every FC invocation. |
### Supporting Libraries — Mac (Tauri / Rust side)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `tauri-plugin-shell` | 2.x | Execute Finder Quick Action scripts / open files | For right-click "Send to Folip" Finder integration via macOS Quick Actions (Automator/Shortcuts workflow calling a Tauri deep link or CLI) |
| `tauri-plugin-drag` | 2.x | Accept drag-and-drop file payloads into the tray icon window | Required for the drag-to-tray-icon drop zone UX |
| `tauri-plugin-notification` | 2.x | Show native macOS notifications on upload complete / new file received | Use for "File delivered" and "New file waiting" alerts |
| `tauri-plugin-global-shortcut` | 2.x | Optional: keyboard shortcut to open send dialog | Nice-to-have; include in later phase |
| `aliyun-oss-rust-sdk` (community) or raw HTTP with `reqwest` | — | OSS multipart upload from Rust | No official Alibaba Rust SDK exists (MEDIUM confidence). Use `reqwest` with AWS-style OSS signing; OSS is S3-compatible so `aws-sdk-s3` pointed at OSS endpoints is a viable alternative. |
| `reqwest` | 0.12+ | HTTP client for Rust | Standard async HTTP for Tauri backend. Use with `tokio` runtime (Tauri already uses tokio). |
| `serde` + `serde_json` | 1.x | Serialize/deserialize Tauri command payloads and API responses | Required for all Tauri IPC. |
| `keychain-rs` or `tauri-plugin-stronghold` | 2.x | Secure credential storage on macOS Keychain | Store JWT refresh token securely. `tauri-plugin-stronghold` is the official Tauri v2 answer; `keychain-rs` is more lightweight if Stronghold is overkill. |
### Supporting Libraries — Android (Flutter / Dart side)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `dio` | 5.x | HTTP client with multipart upload, progress callbacks, cancellation | Required. `http` package lacks multipart progress. Use `dio` + `FormData` for chunked upload with progress bar. |
| `file_picker` | 8.x | Native Android file picker dialog | Required for picking files to send from Android. Handles scoped storage (Android 13+). |
| `flutter_local_notifications` | 17.x | Local push notifications for download complete / new file | Required. Shows "File ready to download" alert even when app is backgrounded. |
| `workmanager` or `flutter_background_service` | — | Background polling for new files | MEDIUM confidence. For Android background tasks (checking inbox while app is closed). `workmanager` uses Android WorkManager API and is the idiomatic choice. |
| `flutter_secure_storage` | 9.x | Secure credential store (JWT tokens in Android Keystore) | Required for auth token persistence. Do not use SharedPreferences for tokens. |
| `provider` or `riverpod` | riverpod 2.x | State management | Riverpod 2.x (with code generation) is the current community standard for Flutter apps with async data. More testable than Provider. |
| `go_router` | 13.x | Declarative routing | Standard for Flutter navigation. Handles deep links for future share-sheet integration. |
| `aliyun_oss_flutter` (pub.dev, unofficial) or direct OSS HTTP | — | OSS upload from Dart | LOW confidence — the Alibaba OSS Flutter SDK on pub.dev has inconsistent maintenance. Recommend calling OSS directly via `dio` using presigned URLs generated by the FC API backend. This avoids embedding OSS credentials in the app. |
### Supporting Libraries — Backend (Function Compute / Node.js)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ali-oss` | 6.x | Official Alibaba OSS Node.js SDK | Use in FC functions to generate presigned PUT/GET URLs for client-direct upload/download. Clients upload directly to OSS; FC never proxies the file bytes. |
| `jsonwebtoken` | 9.x | JWT sign and verify | Issue tokens on login, verify on protected endpoints. |
| `bcryptjs` | 2.x | Password hashing | Hash passwords before storage. Use bcrypt with cost factor 12. |
| `@aliyun/fc-client` or native FC HTTP trigger | — | FC 3.0 HTTP trigger handler | FC 3.0 HTTP triggers are plain HTTP handlers; no special SDK needed in function code. Use Express-compatible handler pattern. |
| TableStore (OTS) or PolarDB Serverless | — | User accounts, device registry, file metadata | LOW confidence on best choice. TableStore is Aliyun's NoSQL (DynamoDB-equivalent) and avoids running a relational DB. For this use case (simple key-value lookups by user/device), TableStore is appropriate and serverless. PolarDB Serverless is better if you need SQL joins. |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| Tauri CLI | `cargo tauri dev`, `cargo tauri build` for Mac app | Install via `cargo install tauri-cli`. Use `--target aarch64-apple-darwin` and `x86_64-apple-darwin` for universal binary. |
| Flutter CLI | `flutter run`, `flutter build apk` | Use `flutter build apk --release --split-per-abi` for Android to get smaller per-architecture APKs. |
| Serverless Devs (Alibaba) | Deploy and manage FC functions | Official Alibaba CLI tool for FC 3.0 deployment. Alternative: use FC web console directly for MVP. |
| `cargo` | Rust package manager | Already included with Rust toolchain. |
| Aliyun CLI (`aliyun`) | Manage OSS buckets, set lifecycle rules, test presigned URLs | Install from github.com/aliyun/aliyun-cli. Useful for setting auto-expiry bucket lifecycle rules. |
## Installation
# Rust toolchain (prerequisite for Tauri)
# Tauri CLI
# Create Tauri v2 project (in project root)
# Flutter SDK — install via official installer or fvm
# https://docs.flutter.dev/get-started/install/macos
# Flutter project dependencies (pubspec.yaml)
# FC function (Node.js in functions/ directory)
# Aliyun CLI (macOS)
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Flutter | React Native | If team already has strong React/TypeScript expertise and no Dart experience. RN has better JS ecosystem interop but weaker Android background task story. Flutter is preferred here because future iPad target is already planned (one codebase) and Dart's type system suits a file I/O-heavy app. |
| Function Compute (FC) | ECS (always-on VM) | If you need WebSockets, long-running processes, or complex inbound webhooks. For Folip's API pattern (short-lived REST calls to get presigned URLs), FC is strictly better — no idle cost, no OS patching. |
| Function Compute (FC) | Alibaba Container Service (ACK) | If the API layer grows to need complex middleware, stateful services, or multi-service orchestration. Overkill for MVP. |
| TableStore (OTS) | PolarDB Serverless | If business logic requires relational joins (e.g., complex reporting). For Folip's data model (users, devices, files), NoSQL key-value is sufficient and cheaper. |
| Presigned URL pattern | FC proxying file bytes | Never proxy file bytes through FC — 500MB through a serverless function will be slow, expensive, and hit timeout limits. Always generate presigned URLs and let clients talk directly to OSS. |
| `tauri-plugin-stronghold` | `keychain-rs` | Use `keychain-rs` if you want a minimal dependency; use Stronghold if you want Tauri's official secret store with encrypted vault semantics. |
| `riverpod` (Flutter) | `bloc` / `cubit` | Use `bloc` if team prefers explicit event/state separation and is already experienced with it. Riverpod is simpler for a small team or solo developer. |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Electron | 150MB+ binary for a system tray utility is unacceptable. High memory footprint contradicts the "lightweight native feel" requirement. | Tauri v2 |
| React Native (for this project) | Android background file transfer requires native modules. RN's bridge adds friction for file I/O intensive code. No path to a native iPad target without significant rework (RN for iPad is possible but not as natural as Flutter). | Flutter |
| Embedding OSS credentials in the mobile/desktop client | Credentials in the app binary can be extracted. If the bucket is private (required for user data), any leak exposes all users' files. | Generate short-lived presigned URLs server-side (FC) and return them to the client. Clients use presigned URLs; they never see OSS credentials. |
| SharedPreferences / AsyncStorage for JWT tokens | Unencrypted on-disk storage. Tokens persist across reinstalls on some Android versions. | `flutter_secure_storage` (Android Keystore) on Flutter; `tauri-plugin-stronghold` on Mac. |
| OSS public bucket | Files from all users would be publicly accessible via guessable URLs. | Private bucket + presigned URLs with short expiry (e.g., 1 hour for upload, 24 hours for download). |
| Long-polling from mobile for new files | Drains battery, wastes FC invocations, increases costs with no online users. | FCM push notifications (Firebase Cloud Messaging) triggered from FC when a file is deposited. Wakes the app only when needed. |
| Tauri v1 | v1 is not maintained for new features. Plugin ecosystem for system tray and drag-drop is v2-only. v1 lacks the `tauri-plugin-drag` and updated `tauri-plugin-shell` APIs. | Tauri v2 |
| Aliyun SDK embedded in Flutter app for direct OSS auth | SDK would require AccessKey/SecretKey embedded in app. See "credentials in client" above. | Presigned URL pattern via FC API |
## Stack Patterns by Variant
- Use Tauri v2's tray icon API (`tauri-plugin-tray`) with a minimal webview window for the drop zone UI
- For right-click "Send to Folip" in Finder: implement a macOS Quick Action (Automator service) that calls a Tauri deep link (`folip://send?path=...`) — this is the standard pattern, not a Finder Sync Extension (which requires app sandbox entitlements and is significantly more complex)
- Drag-to-tray-icon: use `tauri-plugin-drag` to accept `ondrop` events on the tray popover window
- Always use OSS multipart upload: split into 5-20MB parts, upload in parallel (3-5 concurrent parts), reassemble with CompleteMultipartUpload
- Generate the presigned multipart initiation URL from FC, return part presigned URLs to client, client uploads parts directly to OSS
- Track upload progress client-side using `dio` (Flutter) or `reqwest` with a progress wrapper (Rust)
- Implement resumable upload: store the OSS uploadId and completed part ETags locally so upload can resume after app restart
- Configure OSS bucket lifecycle rules to delete objects after N days (e.g., 7 days)
- Also store expiry metadata in TableStore so the app can show "expires in X days" without querying OSS directly
- On pickup, delete the OSS object immediately and mark the TableStore record as claimed
- File is uploaded to OSS by sender, metadata written to TableStore by FC
- Receiver polls on app open OR wakes via FCM push (preferred)
- Receiver downloads directly from OSS via presigned GET URL
## Version Compatibility
| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Tauri 2.x | Rust 1.79+ (MSRV) | Check `.cargo/config.toml` for MSRV override if using older Rust. |
| tauri-plugin-* 2.x | Tauri 2.x only | v1 plugins are NOT compatible with Tauri v2. Do not mix. |
| Flutter 3.24+ | Dart 3.4+ | Dart 3.x null safety is mandatory. All packages must be null-safe. |
| `riverpod` 2.x + code gen | `flutter_riverpod` 2.x, `riverpod_annotation` 2.x, `riverpod_generator` 2.x | All three must be version-aligned. Use `flutter pub upgrade` together. |
| `dio` 5.x | Dart 3.x, Flutter 3.10+ | `dio` 4.x had breaking changes to interceptors. Stay on 5.x. |
| `ali-oss` Node.js SDK 6.x | Node.js 16-20 | FC 3.0 supports Node.js 18 runtime; use that. ali-oss 6.x works with Node 18. |
| FCM (Firebase) | Requires Google Play Services on Android | Standard Android phones have this. Note: Chinese mainland Android devices (MIUI, ColorOS, etc.) may not have Google Play Services. If the target user's Android phone lacks GMS, FCM silent push will not work — fall back to polling on app foreground. This is a significant real-world concern for a Chinese user's device. |
## Critical Design Decision: Presigned URL Architecture
## Sources
- Training knowledge (cutoff August 2025) — Tauri v2 release details, plugin architecture, Flutter/Dart ecosystem state
- Tauri 2.0 was announced and released October 2024 (HIGH confidence — well-covered in training data)
- Flutter 3.24 released August 2024 (HIGH confidence)
- Alibaba Cloud OSS multipart upload documentation pattern (MEDIUM confidence — standard feature, OSS is S3-compatible, but exact SDK versions should be verified at help.aliyun.com)
- FCM limitation on Chinese Android devices (MEDIUM confidence — well-known limitation but real-world device set varies; verify with target device)
- `aliyun-oss-rust-sdk` availability (LOW confidence — no official Alibaba Rust SDK in training data; verify on crates.io before assuming)
- FC 3.0 Node.js 18 runtime support (MEDIUM confidence — verify current supported runtimes at help.aliyun.com/product/50980.html)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
