import { Router, Request, Response } from 'express'
import bcrypt from 'bcryptjs'
import { v4 as uuidv4 } from 'uuid'
import TableStore from 'tablestore'
import { generateTokens, hashToken, verifyRefreshToken } from '../lib/jwt.js'
import { tsClient, Tables, pk, attrs, getAttr } from '../lib/tablestore.js'
import { authMiddleware } from '../middleware/auth.js'

const router = Router()

// ─── POST /register ──────────────────────────────────────────────────────────
router.post('/register', async (req: Request, res: Response) => {
  try {
    const { email, password, device_name } = req.body

    // Validate inputs
    if (!email || typeof email !== 'string' || !email.trim()) {
      res.status(400).json({ error: 'Email is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }
    if (!password || typeof password !== 'string' || password.length < 8) {
      res.status(400).json({ error: 'Password must be at least 8 characters', code: 'VALIDATION_ERROR', ok: false })
      return
    }
    if (!device_name || typeof device_name !== 'string' || !device_name.trim()) {
      res.status(400).json({ error: 'Device name is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }

    const normalizedEmail = email.toLowerCase().trim()

    // Check if email already registered
    const emailLookup = await tsClient.getRow({
      tableName: Tables.EMAIL_INDEX,
      primaryKey: pk({ email: normalizedEmail }),
    })

    if (emailLookup.row && emailLookup.row.primaryKey && emailLookup.row.primaryKey.length > 0) {
      res.status(409).json({ error: 'Email already registered', code: 'EMAIL_EXISTS', ok: false })
      return
    }

    // Create user
    const user_id = uuidv4()
    const password_hash = await bcrypt.hash(password, 12)
    const now = Date.now()

    await tsClient.putRow({
      tableName: Tables.USERS,
      primaryKey: pk({ user_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({ email: normalizedEmail, password_hash, created_at: now }),
    })

    // Write email index
    await tsClient.putRow({
      tableName: Tables.EMAIL_INDEX,
      primaryKey: pk({ email: normalizedEmail }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({ user_id }),
    })

    // Create device
    const device_id = uuidv4()
    await tsClient.putRow({
      tableName: Tables.DEVICES,
      primaryKey: pk({ user_id, device_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({ device_name: device_name.trim(), registered_at: now }),
    })

    // Generate tokens
    const tokens = generateTokens(user_id, device_id)

    // Store refresh token hash
    const token_hash = hashToken(tokens.refreshToken)
    const expires_at = now + 30 * 24 * 60 * 60 * 1000 // 30 days
    await tsClient.putRow({
      tableName: Tables.REFRESH_TOKENS,
      primaryKey: pk({ user_id, device_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({ token_hash, expires_at }),
    })

    res.status(201).json({
      data: {
        user_id,
        email: normalizedEmail,
        device_id,
        device_name: device_name.trim(),
        ...tokens,
      },
      ok: true,
    })
  } catch (err) {
    console.error('Register error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── POST /login ─────────────────────────────────────────────────────────────
router.post('/login', async (req: Request, res: Response) => {
  try {
    const { email, password, device_name } = req.body

    // Validate inputs
    if (!email || typeof email !== 'string' || !email.trim()) {
      res.status(400).json({ error: 'Email is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }
    if (!password || typeof password !== 'string') {
      res.status(400).json({ error: 'Password is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }
    if (!device_name || typeof device_name !== 'string' || !device_name.trim()) {
      res.status(400).json({ error: 'Device name is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }

    const normalizedEmail = email.toLowerCase().trim()

    // Look up email in email_index
    const emailLookup = await tsClient.getRow({
      tableName: Tables.EMAIL_INDEX,
      primaryKey: pk({ email: normalizedEmail }),
    })

    if (!emailLookup.row || !emailLookup.row.primaryKey || emailLookup.row.primaryKey.length === 0) {
      res.status(401).json({ error: 'Invalid credentials', code: 'INVALID_CREDENTIALS', ok: false })
      return
    }

    const user_id = getAttr(emailLookup.row, 'user_id')

    // Get user record
    const userLookup = await tsClient.getRow({
      tableName: Tables.USERS,
      primaryKey: pk({ user_id }),
    })

    if (!userLookup.row || !userLookup.row.primaryKey || userLookup.row.primaryKey.length === 0) {
      res.status(401).json({ error: 'Invalid credentials', code: 'INVALID_CREDENTIALS', ok: false })
      return
    }

    const password_hash = getAttr(userLookup.row, 'password_hash')
    const isValid = await bcrypt.compare(password, password_hash)

    if (!isValid) {
      res.status(401).json({ error: 'Invalid credentials', code: 'INVALID_CREDENTIALS', ok: false })
      return
    }

    // Create new device entry for this login
    const device_id = uuidv4()
    const now = Date.now()

    await tsClient.putRow({
      tableName: Tables.DEVICES,
      primaryKey: pk({ user_id, device_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({ device_name: device_name.trim(), registered_at: now }),
    })

    // Generate tokens
    const tokens = generateTokens(user_id, device_id)

    // Store refresh token hash
    const token_hash = hashToken(tokens.refreshToken)
    const expires_at = now + 30 * 24 * 60 * 60 * 1000
    await tsClient.putRow({
      tableName: Tables.REFRESH_TOKENS,
      primaryKey: pk({ user_id, device_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({ token_hash, expires_at }),
    })

    res.status(200).json({
      data: {
        user_id,
        email: normalizedEmail,
        device_id,
        device_name: device_name.trim(),
        ...tokens,
      },
      ok: true,
    })
  } catch (err) {
    console.error('Login error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── POST /refresh ───────────────────────────────────────────────────────────
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body

    if (!refreshToken || typeof refreshToken !== 'string') {
      res.status(400).json({ error: 'Refresh token is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }

    // Verify JWT signature and expiry
    let payload
    try {
      payload = verifyRefreshToken(refreshToken)
    } catch {
      res.status(401).json({ error: 'Invalid or expired refresh token', code: 'TOKEN_INVALID', ok: false })
      return
    }

    const userId = payload.sub
    const deviceId = payload.device_id

    // Look up stored token hash
    const tokenLookup = await tsClient.getRow({
      tableName: Tables.REFRESH_TOKENS,
      primaryKey: pk({ user_id: userId, device_id: deviceId }),
    })

    const incomingHash = hashToken(refreshToken)
    const storedHash = tokenLookup.row?.primaryKey?.length
      ? getAttr(tokenLookup.row, 'token_hash')
      : undefined

    // Token reuse detection (D-09 family invalidation)
    if (!storedHash || storedHash !== incomingHash) {
      // Delete ALL refresh tokens for this user (family invalidation)
      await invalidateAllUserSessions(userId)
      res.status(401).json({
        error: 'Token reused — all sessions invalidated',
        code: 'TOKEN_REUSE',
        ok: false,
      })
      return
    }

    // Check expiry from stored record
    const storedExpiry = getAttr(tokenLookup.row, 'expires_at')
    if (storedExpiry && Date.now() > storedExpiry) {
      // Clean up expired token
      await tsClient.deleteRow({
        tableName: Tables.REFRESH_TOKENS,
        primaryKey: pk({ user_id: userId, device_id: deviceId }),
        condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      })
      res.status(401).json({ error: 'Refresh token expired', code: 'TOKEN_EXPIRED', ok: false })
      return
    }

    // Delete old refresh token
    await tsClient.deleteRow({
      tableName: Tables.REFRESH_TOKENS,
      primaryKey: pk({ user_id: userId, device_id: deviceId }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
    })

    // Generate new token pair
    const newTokens = generateTokens(userId, deviceId)
    const now = Date.now()

    // Store new refresh token hash
    const newTokenHash = hashToken(newTokens.refreshToken)
    const expires_at = now + 30 * 24 * 60 * 60 * 1000
    await tsClient.putRow({
      tableName: Tables.REFRESH_TOKENS,
      primaryKey: pk({ user_id: userId, device_id: deviceId }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({ token_hash: newTokenHash, expires_at }),
    })

    res.status(200).json({
      data: { ...newTokens },
      ok: true,
    })
  } catch (err) {
    console.error('Refresh error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── POST /logout ────────────────────────────────────────────────────────────
router.post('/logout', authMiddleware, async (req: Request, res: Response) => {
  try {
    const { userId, deviceId } = req.user!

    await tsClient.deleteRow({
      tableName: Tables.REFRESH_TOKENS,
      primaryKey: pk({ user_id: userId, device_id: deviceId }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
    })

    res.status(200).json({
      data: { message: 'Logged out' },
      ok: true,
    })
  } catch (err) {
    console.error('Logout error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── Helper: Invalidate all user sessions (D-09 family invalidation) ────────
async function invalidateAllUserSessions(userId: string): Promise<void> {
  // Use getRange to find all refresh tokens for this user
  const result = await tsClient.getRange({
    tableName: Tables.REFRESH_TOKENS,
    direction: TableStore.Direction.FORWARD,
    inclusiveStartPrimaryKey: [
      { user_id: userId },
      { device_id: TableStore.INF_MIN },
    ],
    exclusiveEndPrimaryKey: [
      { user_id: userId },
      { device_id: TableStore.INF_MAX },
    ],
    limit: 100,
  })

  if (!result.rows || result.rows.length === 0) return

  // Batch delete all found refresh token rows
  const deleteRows = result.rows.map((row: any) => ({
    type: 'DELETE',
    condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
    primaryKey: row.primaryKey.map((pkCol: any) => ({ [pkCol.name]: pkCol.value })),
  }))

  // batchWriteRow supports up to 200 rows per batch
  await tsClient.batchWriteRow({
    tables: [
      {
        tableName: Tables.REFRESH_TOKENS,
        rows: deleteRows,
      },
    ],
  })
}

export default router
