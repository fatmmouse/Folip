import express from 'express'
import { authMiddleware } from './middleware/auth.js'
import authRoutes from './routes/auth.js'
import deviceRoutes from './routes/devices.js'
import transferRoutes from './routes/transfers.js'

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

// Transfer routes (protected — authMiddleware applied at mount level)
app.use('/transfers', authMiddleware, transferRoutes)

// FC 3.0 HTTP trigger handler — adapts FC event to Express via local HTTP server
import http from 'http'

// Create a persistent HTTP server wrapping Express (reused across warm invocations)
const server = http.createServer(app)

export const handler = async (event: any, _context: any) => {
  const parsed = Buffer.isBuffer(event) ? JSON.parse(event.toString()) : event
  const method = parsed.requestContext?.http?.method || 'GET'
  const path = parsed.rawPath || '/'
  const query = parsed.queryParameters
    ? '?' + Object.entries(parsed.queryParameters).map(([k, v]) => `${k}=${v}`).join('&')
    : ''
  const headers: Record<string, string> = {}
  // Normalize header keys to lowercase for Express compatibility
  for (const [k, v] of Object.entries(parsed.headers || {})) {
    headers[k.toLowerCase()] = String(v)
  }
  const bodyStr = parsed.body
    ? (parsed.isBase64Encoded ? Buffer.from(parsed.body, 'base64').toString() : parsed.body)
    : undefined

  // Ensure content-length is set for body parsing
  if (bodyStr && !headers['content-length']) {
    headers['content-length'] = String(Buffer.byteLength(bodyStr))
  }

  return new Promise<any>((resolve, reject) => {
    // Start server on random port if not already listening
    if (!server.listening) {
      server.listen(0)
    }
    const addr = server.address() as any
    const port = addr.port

    const options: http.RequestOptions = {
      hostname: '127.0.0.1',
      port,
      path: path + query,
      method,
      headers,
    }

    const req = http.request(options, (res) => {
      const chunks: Buffer[] = []
      res.on('data', (chunk) => chunks.push(chunk))
      res.on('end', () => {
        const responseBody = Buffer.concat(chunks).toString()
        const responseHeaders: Record<string, string> = {}
        for (const [k, v] of Object.entries(res.headers)) {
          if (v !== undefined) responseHeaders[k] = Array.isArray(v) ? v.join(', ') : v
        }
        resolve({
          statusCode: res.statusCode,
          headers: responseHeaders,
          body: responseBody,
        })
      })
    })

    req.on('error', (err) => reject(err))
    if (bodyStr) req.write(bodyStr)
    req.end()
  })
}
