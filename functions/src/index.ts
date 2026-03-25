import express from 'express'
import { authMiddleware } from './middleware/auth.js'
import authRoutes from './routes/auth.js'
import deviceRoutes from './routes/devices.js'

const app = express()
app.use(express.json())

// Health check (public)
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', ok: true })
})

// Auth routes (public — middleware applied per-route inside auth.ts)
app.use('/auth', authRoutes)

// Device routes (protected — authMiddleware applied at mount level)
app.use('/devices', authMiddleware, deviceRoutes)

// Route placeholders -- subsequent plans wire these:
// app.use('/transfers', authMiddleware, transferRoutes) // Plan 01-04

// FC 3.0 HTTP trigger handler export
export const handler = app
