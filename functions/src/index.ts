import express from 'express'
import { authMiddleware } from './middleware/auth.js'
import authRoutes from './routes/auth.js'

const app = express()
app.use(express.json())

// Health check (public)
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', ok: true })
})

// Auth routes (public — middleware applied per-route inside auth.ts)
app.use('/auth', authRoutes)

// Route placeholders -- subsequent plans wire these:
// app.use('/devices', authMiddleware, deviceRoutes)    // Plan 01-03
// app.use('/transfers', authMiddleware, transferRoutes) // Plan 01-04

// Suppress unused import warning -- authMiddleware is used when routes are wired
void authMiddleware

// FC 3.0 HTTP trigger handler export
export const handler = app
