#!/usr/bin/env node
/**
 * Smoke test script for Folip API.
 * Verifies all endpoints work correctly against any running API instance.
 *
 * Usage:
 *   API_BASE_URL=https://your-fc-url node functions/scripts/smoke-test.mjs
 *   node functions/scripts/smoke-test.mjs  # defaults to http://localhost:3000
 */

const BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000'
const EMAIL = `smoke-test-${Date.now()}@folip.test`
const PASSWORD = 'SmokeTestPass1234'
const DEVICE_REGISTER = 'Smoke Register Device'
const DEVICE_LOGIN = 'Smoke Login Device'

let passed = 0
let failed = 0

async function post(path, body, token) {
  const headers = { 'Content-Type': 'application/json' }
  if (token) headers['Authorization'] = `Bearer ${token}`
  const res = await fetch(`${BASE_URL}${path}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  })
  const data = await res.json()
  return { status: res.status, data }
}

async function get(path, token) {
  const headers = {}
  if (token) headers['Authorization'] = `Bearer ${token}`
  const res = await fetch(`${BASE_URL}${path}`, { headers })
  const data = await res.json()
  return { status: res.status, data }
}

function assert(condition, msg) {
  if (!condition) throw new Error(`Assertion failed: ${msg}`)
}

async function test(name, fn) {
  try {
    await fn()
    passed++
    console.log(`  PASS  ${name}`)
  } catch (err) {
    failed++
    console.log(`  FAIL  ${name}: ${err.message}`)
  }
}

console.log(`\nSmoke testing against: ${BASE_URL}\n`)

// State shared across tests
let accessToken, refreshToken, deviceId, transferId, uploadUrl
let registerToken, registerDeviceId

// 1. Health check
await test('GET /health', async () => {
  const { status, data } = await get('/health')
  assert(status === 200, `expected 200, got ${status}`)
  assert(data.ok === true, `expected ok:true, got ${JSON.stringify(data)}`)
})

// 2. Register
await test('POST /auth/register', async () => {
  const { status, data } = await post('/auth/register', {
    email: EMAIL,
    password: PASSWORD,
    device_name: DEVICE_REGISTER,
  })
  assert(status === 201 || status === 200, `expected 201/200, got ${status}: ${JSON.stringify(data)}`)
  assert(data.data?.accessToken, 'missing accessToken')
  assert(data.data?.refreshToken, 'missing refreshToken')
  registerToken = data.data.accessToken
  registerDeviceId = data.data.device_id
})

// 3. Login
await test('POST /auth/login', async () => {
  const { status, data } = await post('/auth/login', {
    email: EMAIL,
    password: PASSWORD,
    device_name: DEVICE_LOGIN,
  })
  assert(status === 200, `expected 200, got ${status}: ${JSON.stringify(data)}`)
  assert(data.data?.accessToken, 'missing accessToken')
  assert(data.data?.refreshToken, 'missing refreshToken')
  accessToken = data.data.accessToken
  refreshToken = data.data.refreshToken
  deviceId = data.data.device_id
})

// 4. List devices
await test('GET /devices', async () => {
  const { status, data } = await get('/devices', accessToken)
  assert(status === 200, `expected 200, got ${status}: ${JSON.stringify(data)}`)
  const devices = data.data?.devices || data.data
  assert(Array.isArray(devices), `expected array, got ${typeof devices}`)
  assert(devices.length >= 1, `expected >= 1 device, got ${devices.length}`)
})

// 5. Prepare transfer
let targetDeviceId
await test('POST /transfers/prepare', async () => {
  // Send from login device to register device
  targetDeviceId = registerDeviceId

  const { status, data } = await post('/transfers/prepare', {
    file_name: 'smoke-test.txt',
    file_size: 11,
    target_device_id: targetDeviceId,
  }, accessToken)
  assert(status === 200 || status === 201, `expected 200/201, got ${status}: ${JSON.stringify(data)}`)
  assert(data.data?.upload_url, 'missing upload_url')
  assert(data.data?.transfer_id, 'missing transfer_id')
  transferId = data.data.transfer_id
  uploadUrl = data.data.upload_url
})

// 6. Upload to OSS via presigned URL
await test('PUT <upload_url> (OSS direct)', async () => {
  const res = await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/octet-stream' },
    body: 'hello world',
  })
  assert(res.status === 200 || res.status === 204, `expected 200/204, got ${res.status}`)
})

// 7. Confirm transfer
await test('POST /transfers/:id/confirm', async () => {
  const { status, data } = await post(`/transfers/${transferId}/confirm`, {
    target_device_id: targetDeviceId,
  }, accessToken)
  assert(status === 200, `expected 200, got ${status}: ${JSON.stringify(data)}`)
})

// 8. Check inbox (as register device — the target)
await test('GET /transfers/inbox', async () => {
  const { status, data } = await get('/transfers/inbox', registerToken)
  assert(status === 200, `expected 200, got ${status}: ${JSON.stringify(data)}`)
  const transfers = data.data?.transfers || data.data
  assert(Array.isArray(transfers), `expected array, got ${typeof transfers}`)
})

// 9. Mark downloaded (as register device — the target)
await test('POST /transfers/:id/downloaded', async () => {
  const { status, data } = await post(`/transfers/${transferId}/downloaded`, {}, registerToken)
  assert(status === 200, `expected 200, got ${status}: ${JSON.stringify(data)}`)
})

// Summary
console.log(`\n${'='.repeat(50)}`)
if (failed === 0) {
  console.log(`All ${passed} smoke tests passed against ${BASE_URL}`)
  process.exit(0)
} else {
  console.log(`${passed} passed, ${failed} FAILED against ${BASE_URL}`)
  process.exit(1)
}
