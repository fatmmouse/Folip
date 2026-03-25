import { Request, Response, NextFunction } from 'express'
import { verifyAccessToken } from '../lib/jwt.js'
import type { AuthenticatedUser } from '../types/index.js'

// Extend Express Request with user context
declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser
    }
  }
}

export function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing authorization header', code: 'AUTH_REQUIRED', ok: false })
    return
  }
  const token = authHeader.slice(7)
  try {
    const payload = verifyAccessToken(token)
    req.user = { userId: payload.sub, deviceId: payload.device_id }
    next()
  } catch {
    res.status(401).json({ error: 'Invalid or expired access token', code: 'TOKEN_INVALID', ok: false })
  }
}
