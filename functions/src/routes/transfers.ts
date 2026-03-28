import { Router, Request, Response } from 'express'
import { v4 as uuidv4 } from 'uuid'
import TableStore from 'tablestore'
import { tsClient, Tables, pk, attrs, getAttr } from '../lib/tablestore.js'
import { generatePutUrl, generateGetUrl } from '../lib/oss.js'

const router = Router()

const MAX_FILE_SIZE = 524288000 // 500MB in bytes

// ─── POST /prepare ──────────────────────────────────────────────────────────
router.post('/prepare', async (req: Request, res: Response) => {
  try {
    const { target_device_id, file_name, file_size } = req.body

    // Validate inputs
    if (!target_device_id || typeof target_device_id !== 'string' || !target_device_id.trim()) {
      res.status(400).json({ error: 'Target device ID is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }
    if (!file_name || typeof file_name !== 'string' || !file_name.trim()) {
      res.status(400).json({ error: 'File name is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }
    if (typeof file_size !== 'number' || file_size <= 0) {
      res.status(400).json({ error: 'File size must be a positive number', code: 'VALIDATION_ERROR', ok: false })
      return
    }
    if (file_size > MAX_FILE_SIZE) {
      res.status(400).json({ error: 'File size exceeds 500MB limit', code: 'FILE_TOO_LARGE', ok: false })
      return
    }

    // Validate target device belongs to the same user
    const deviceLookup = await tsClient.getRow({
      tableName: Tables.DEVICES,
      primaryKey: pk({ user_id: req.user!.userId, device_id: target_device_id }),
    })

    if (!deviceLookup.row || !deviceLookup.row.primaryKey || deviceLookup.row.primaryKey.length === 0) {
      res.status(404).json({ error: 'Target device not found', code: 'DEVICE_NOT_FOUND', ok: false })
      return
    }

    const sender_device_id = req.user!.deviceId
    const transfer_id = uuidv4()
    const oss_key = `transfers/${transfer_id}/${file_name.trim()}`
    const now = Date.now()

    // Write transfer metadata to TableStore
    await tsClient.putRow({
      tableName: Tables.TRANSFERS,
      primaryKey: pk({ target_device_id, transfers_id: transfer_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({
        sender_device_id,
        file_name: file_name.trim(),
        file_size,
        oss_key,
        status: 'uploading',
        created_at: now,
      }),
    })

    // Generate presigned PUT URL (1 hour expiry)
    const upload_url = await generatePutUrl(oss_key, 3600)

    res.status(201).json({
      data: { transfer_id, upload_url, oss_key, expires_in: 3600 },
      ok: true,
    })
  } catch (err) {
    console.error('Transfer prepare error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── POST /:transfer_id/confirm ─────────────────────────────────────────────
router.post('/:transfer_id/confirm', async (req: Request, res: Response) => {
  try {
    const transfer_id = req.params.transfer_id as string
    const { target_device_id } = req.body

    if (!target_device_id || typeof target_device_id !== 'string' || !target_device_id.trim()) {
      res.status(400).json({ error: 'Target device ID is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }

    // Look up the transfer
    const transferLookup = await tsClient.getRow({
      tableName: Tables.TRANSFERS,
      primaryKey: pk({ target_device_id: target_device_id as string, transfers_id: transfer_id }),
    })

    if (!transferLookup.row || !transferLookup.row.primaryKey || transferLookup.row.primaryKey.length === 0) {
      res.status(404).json({ error: 'Transfer not found', code: 'TRANSFER_NOT_FOUND', ok: false })
      return
    }

    // Verify sender ownership
    const storedSender = getAttr(transferLookup.row, 'sender_device_id')
    if (storedSender !== req.user!.deviceId) {
      res.status(403).json({ error: 'Forbidden', code: 'FORBIDDEN', ok: false })
      return
    }

    // Check current status
    const currentStatus = getAttr(transferLookup.row, 'status')
    if (currentStatus !== 'uploading') {
      res.status(409).json({ error: 'Transfer already confirmed', code: 'ALREADY_CONFIRMED', ok: false })
      return
    }

    // Update status to pending
    await tsClient.updateRow({
      tableName: Tables.TRANSFERS,
      primaryKey: pk({ target_device_id: target_device_id as string, transfers_id: transfer_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.EXPECT_EXIST, null),
      updateOfAttributeColumns: [
        { PUT: [{ status: 'pending' }] },
      ],
    })

    res.status(200).json({
      data: { transfer_id, status: 'pending' },
      ok: true,
    })
  } catch (err) {
    console.error('Transfer confirm error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── GET /inbox ─────────────────────────────────────────────────────────────
router.get('/inbox', async (req: Request, res: Response) => {
  try {
    const deviceId = req.user!.deviceId

    // Range query: all transfers for this device
    const result = await tsClient.getRange({
      tableName: Tables.TRANSFERS,
      direction: TableStore.Direction.FORWARD,
      inclusiveStartPrimaryKey: [
        { target_device_id: deviceId },
        { transfers_id: TableStore.INF_MIN },
      ],
      exclusiveEndPrimaryKey: [
        { target_device_id: deviceId },
        { transfers_id: TableStore.INF_MAX },
      ],
      limit: 100,
    })

    const transfers = []
    if (result.rows) {
      for (const row of result.rows) {
        const status = getAttr(row, 'status')
        // Only include confirmed or downloaded transfers (exclude 'uploading')
        if (status !== 'pending' && status !== 'downloaded') continue

        const oss_key = getAttr(row, 'oss_key')
        const download_url = await generateGetUrl(oss_key, 86400) // 24 hour expiry

        transfers.push({
          transfer_id: getAttr(row, 'transfers_id') ?? row.primaryKey?.find((p: any) => p.name === 'transfers_id')?.value,
          file_name: getAttr(row, 'file_name'),
          file_size: getAttr(row, 'file_size'),
          sender_device_id: getAttr(row, 'sender_device_id'),
          created_at: getAttr(row, 'created_at'),
          status,
          download_url,
        })
      }
    }

    res.status(200).json({
      data: { transfers },
      ok: true,
    })
  } catch (err) {
    console.error('Transfer inbox error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── POST /:transfer_id/downloaded ──────────────────────────────────────────
router.post('/:transfer_id/downloaded', async (req: Request, res: Response) => {
  try {
    const transfer_id = req.params.transfer_id as string
    const deviceId = req.user!.deviceId

    // Look up the transfer
    const transferLookup = await tsClient.getRow({
      tableName: Tables.TRANSFERS,
      primaryKey: pk({ target_device_id: deviceId, transfers_id: transfer_id }),
    })

    if (!transferLookup.row || !transferLookup.row.primaryKey || transferLookup.row.primaryKey.length === 0) {
      res.status(404).json({ error: 'Transfer not found', code: 'TRANSFER_NOT_FOUND', ok: false })
      return
    }

    // Update status to downloaded (D-01: do NOT delete OSS object)
    await tsClient.updateRow({
      tableName: Tables.TRANSFERS,
      primaryKey: pk({ target_device_id: deviceId, transfers_id: transfer_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.EXPECT_EXIST, null),
      updateOfAttributeColumns: [
        { PUT: [{ status: 'downloaded' }, { downloaded_at: Date.now() }] },
      ],
    })

    res.status(200).json({
      data: { transfer_id, status: 'downloaded' },
      ok: true,
    })
  } catch (err) {
    console.error('Transfer downloaded error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

export default router
