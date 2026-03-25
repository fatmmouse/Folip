import jwt from 'jsonwebtoken'
import crypto from 'crypto'
import type { TokenPayload, AuthTokens } from '../types/index.js'

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'dev-access-secret'
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret'
const ACCESS_EXPIRES = '20m'   // Mid-point of 15-30 min range (D-12)
const REFRESH_EXPIRES = '30d'  // 30 days (D-12)

export function generateAccessToken(userId: string, deviceId: string): string {
  return jwt.sign({ sub: userId, device_id: deviceId }, ACCESS_SECRET, {
    expiresIn: ACCESS_EXPIRES,
  })
}

export function generateRefreshToken(userId: string, deviceId: string): string {
  return jwt.sign({ sub: userId, device_id: deviceId }, REFRESH_SECRET, {
    expiresIn: REFRESH_EXPIRES,
  })
}

export function generateTokens(userId: string, deviceId: string): AuthTokens {
  return {
    accessToken: generateAccessToken(userId, deviceId),
    refreshToken: generateRefreshToken(userId, deviceId),
  }
}

export function hashToken(rawToken: string): string {
  return crypto.createHash('sha256').update(rawToken).digest('hex')
}

export function verifyAccessToken(token: string): TokenPayload {
  const payload = jwt.verify(token, ACCESS_SECRET) as jwt.JwtPayload
  return { sub: payload.sub as string, device_id: payload.device_id as string }
}

export function verifyRefreshToken(token: string): TokenPayload {
  const payload = jwt.verify(token, REFRESH_SECRET) as jwt.JwtPayload
  return { sub: payload.sub as string, device_id: payload.device_id as string }
}
