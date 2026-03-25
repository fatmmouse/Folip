// API response envelope (Claude's discretion per CONTEXT.md)
export interface ApiSuccess<T> {
  data: T
  ok: true
}

export interface ApiError {
  error: string
  code: string
  ok: false
}

export type ApiResponse<T> = ApiSuccess<T> | ApiError

// Domain models
export interface User {
  user_id: string
  email: string
  password_hash: string
  created_at: number  // Unix ms
}

export interface Device {
  user_id: string
  device_id: string
  device_name: string
  registered_at: number  // Unix ms
}

export interface RefreshTokenRecord {
  user_id: string
  device_id: string
  token_hash: string  // SHA-256 of raw token
  expires_at: number  // Unix ms
}

// Transfer states per D-02: uploading -> pending -> downloaded
export type TransferStatus = 'uploading' | 'pending' | 'downloaded'

export interface Transfer {
  target_device_id: string
  transfer_id: string
  sender_device_id: string
  file_name: string
  file_size: number  // bytes
  oss_key: string    // e.g., transfers/{transfer_id}/{file_name}
  status: TransferStatus
  created_at: number  // Unix ms
  downloaded_at?: number  // Unix ms, set when status = 'downloaded'
}

// Auth payloads
export interface AuthTokens {
  accessToken: string
  refreshToken: string
}

export interface TokenPayload {
  sub: string       // user_id
  device_id: string
}

// Express request extension
export interface AuthenticatedUser {
  userId: string
  deviceId: string
}
