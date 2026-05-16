<div align="center">

# Folip

**Drop a file here, pick it up there.**

A minimal cross-platform file delivery tool for personal multi-device use.

[中文](./README_zh-CN.md) | English

---

</div>

## What is Folip?

Folip is a personal file shuttle between your devices. Send a file from your Mac — pick it up on your Android phone (or vice versa) whenever you want. The receiving device doesn't need to be online when the file is sent.

Think "file dropbox", not "cloud drive".

## Features

- **Async delivery** — sender and receiver don't need to be online at the same time
- **Bidirectional** — send and receive from any device (Mac, Android)
- **Lightweight** — Mac app is a native tray utility (~8MB), not a bloated Electron app
- **Temporary transit** — files auto-expire; this is a shuttle, not storage
- **Secure** — files transfer via presigned URLs; no credentials stored on client
- **Resumable upload** — large files (up to 500MB) upload in chunks with resume support

## Architecture

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│   Mac App   │         │  Alibaba Cloud   │         │ Android App │
│   (Tauri)   │◄───────►│  Function Compute│◄───────►│  (Flutter)  │
└──────┬──────┘         │  + TableStore    │         └──────┬──────┘
       │                └────────┬─────────┘                │
       │                         │                          │
       └─────────────────► OSS Bucket ◄────────────────────┘
                        (presigned URLs)
```

- **Mac**: Tauri v2 + Rust — native system tray with drag-and-drop
- **Android**: Flutter 3.24+ — material design with background download
- **Backend**: Alibaba Cloud Function Compute (serverless) + TableStore (NoSQL)
- **Storage**: Alibaba Cloud OSS with lifecycle auto-expiry

## Project Structure

```
Folip/
├── mac/              # Tauri v2 Mac desktop app
│   └── src-tauri/    # Rust backend + Tauri commands
├── mobile/           # Flutter Android app
│   └── lib/          # Dart source (Riverpod, Dio)
├── functions/        # Serverless backend (Node.js / TypeScript)
│   └── src/          # API routes, auth, OSS integration
└── .planning/        # Development planning artifacts
```

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Mac App | Tauri v2 + Rust | ~8MB binary, native macOS integration |
| Mobile App | Flutter 3.24+ | Single codebase for Android + future iOS |
| Backend | Alibaba Cloud FC 3.0 | Serverless, zero idle cost |
| Database | TableStore (OTS) | NoSQL key-value, serverless |
| File Storage | Alibaba Cloud OSS | S3-compatible, multipart upload, lifecycle rules |
| Auth | JWT + bcrypt | Stateless, serverless-friendly |

## Getting Started

### Prerequisites

- Rust toolchain (for Tauri)
- Flutter SDK 3.24+
- Node.js 18+ (for backend functions)
- Alibaba Cloud account with OSS + FC enabled

### Mac App

```bash
cd mac
cargo tauri dev
```

### Android App

```bash
cd mobile
flutter pub get
flutter run
```

### Backend (local dev)

```bash
cd functions
npm install
npm run dev
```

## Status

v1.0 MVP is complete and working end-to-end. All 4 development phases finished:

1. Backend Foundation
2. Mac Desktop App
3. Android Mobile App
4. Cloud Deployment

## License

MIT

