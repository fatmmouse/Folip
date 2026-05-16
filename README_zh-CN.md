<div align="center">

# Folip

**在这里丢一个文件，在那里取走它。**

极简的跨平台个人文件投递工具。

中文 | [English](./README.md)

---

</div>

## Folip 是什么？

Folip 是你设备之间的私人文件快递。从 Mac 发一个文件，随时在 Android 手机上取走（反过来也行）。接收端不需要在发送时在线。

像"文件快递柜"，不是"云盘"。

## 特性

- **异步投递** — 发送方和接收方无需同时在线
- **双向传输** — 任何设备都能发送和接收（Mac、Android）
- **轻量原生** — Mac 端是原生托盘应用（约 8MB），不是臃肿的 Electron
- **临时中转** — 文件自动过期，是快递不是仓库
- **安全传输** — 通过预签名 URL 传文件，客户端不存储云凭据
- **断点续传** — 大文件（最大 500MB）分片上传，支持中断恢复

## 架构

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│   Mac 应用   │         │     阿里云        │         │ Android 应用 │
│   (Tauri)   │◄───────►│  函数计算 + 表格存储│◄───────►│  (Flutter)  │
└──────┬──────┘         └────────┬─────────┘         └──────┬──────┘
       │                         │                          │
       └─────────────────► OSS 存储桶 ◄────────────────────┘
                        (预签名 URL 直传)
```

- **Mac 端**: Tauri v2 + Rust — 原生系统托盘，支持拖放
- **Android 端**: Flutter 3.24+ — Material Design，支持后台下载
- **后端**: 阿里云函数计算（Serverless）+ 表格存储（NoSQL）
- **存储**: 阿里云 OSS，配置生命周期自动过期

## 项目结构

```
Folip/
├── mac/              # Tauri v2 Mac 桌面应用
│   └── src-tauri/    # Rust 后端 + Tauri 命令
├── mobile/           # Flutter Android 应用
│   └── lib/          # Dart 源码 (Riverpod, Dio)
├── functions/        # Serverless 后端 (Node.js / TypeScript)
│   └── src/          # API 路由、认证、OSS 集成
└── .planning/        # 开发规划文档
```

## 技术栈

| 层级 | 技术 | 选型理由 |
|------|------|---------|
| Mac 应用 | Tauri v2 + Rust | 约 8MB 二进制，原生 macOS 集成 |
| 移动应用 | Flutter 3.24+ | 一套代码覆盖 Android + 未来 iOS |
| 后端 | 阿里云函数计算 FC 3.0 | Serverless，零空闲成本 |
| 数据库 | 表格存储 (OTS) | NoSQL 键值存储，全托管 |
| 文件存储 | 阿里云 OSS | S3 兼容，分片上传，生命周期规则 |
| 认证 | JWT + bcrypt | 无状态，适配 Serverless |

## 快速开始

### 前置条件

- Rust 工具链（Tauri 需要）
- Flutter SDK 3.24+
- Node.js 18+（后端函数）
- 阿里云账号，开通 OSS + 函数计算

### Mac 应用

```bash
cd mac
cargo tauri dev
```

### Android 应用

```bash
cd mobile
flutter pub get
flutter run
```

### 后端（本地开发）

```bash
cd functions
npm install
npm run dev
```

## 项目状态

v1.0 MVP 已完成，端到端可用。四个开发阶段全部完成：

1. 后端基础设施
2. Mac 桌面应用
3. Android 移动应用
4. 云端部署

## 许可证

MIT

