import { Router, Request, Response } from 'express'
import { v4 as uuidv4 } from 'uuid'
import TableStore from 'tablestore'
import { tsClient, Tables, pk, attrs, getAttr } from '../lib/tablestore.js'

const router = Router()

// ─── POST / ── Register a new device ────────────────────────────────────────
router.post('/', async (req: Request, res: Response) => {
  try {
    const { device_name } = req.body
    const userId = req.user!.userId

    // Validate device_name
    if (!device_name || typeof device_name !== 'string' || !device_name.trim()) {
      res.status(400).json({ error: 'Device name is required', code: 'VALIDATION_ERROR', ok: false })
      return
    }
    if (device_name.trim().length > 50) {
      res.status(400).json({ error: 'Device name must be 50 characters or less', code: 'VALIDATION_ERROR', ok: false })
      return
    }

    const device_id = uuidv4()
    const registered_at = Date.now()

    await tsClient.putRow({
      tableName: Tables.DEVICES,
      primaryKey: pk({ user_id: userId, device_id }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
      attributeColumns: attrs({ device_name: device_name.trim(), registered_at }),
    })

    res.status(201).json({
      data: { device_id, device_name: device_name.trim(), registered_at },
      ok: true,
    })
  } catch (err) {
    console.error('Device register error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── GET / ── List all devices for the authenticated user ───────────────────
router.get('/', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.userId

    const result = await tsClient.getRange({
      tableName: Tables.DEVICES,
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

    const devices = (result.rows || []).map((row: any) => ({
      device_id: getAttr(row, 'device_id'),
      device_name: getAttr(row, 'device_name'),
      registered_at: getAttr(row, 'registered_at'),
    }))

    res.status(200).json({
      data: { devices },
      ok: true,
    })
  } catch (err) {
    console.error('Device list error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

// ─── DELETE /:device_id ── Remove a device and its refresh token ────────────
router.delete('/:device_id', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.userId
    const deviceId = req.params.device_id as string

    // Verify device belongs to this user
    const lookup = await tsClient.getRow({
      tableName: Tables.DEVICES,
      primaryKey: pk({ user_id: userId, device_id: deviceId }),
    })

    if (!lookup.row || !lookup.row.primaryKey || lookup.row.primaryKey.length === 0) {
      res.status(404).json({ error: 'Device not found', code: 'DEVICE_NOT_FOUND', ok: false })
      return
    }

    // Delete device row
    await tsClient.deleteRow({
      tableName: Tables.DEVICES,
      primaryKey: pk({ user_id: userId, device_id: deviceId }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
    })

    // Delete associated refresh token (logs the device out)
    await tsClient.deleteRow({
      tableName: Tables.REFRESH_TOKENS,
      primaryKey: pk({ user_id: userId, device_id: deviceId }),
      condition: new TableStore.Condition(TableStore.RowExistenceExpectation.IGNORE, null),
    })

    res.status(200).json({
      data: { message: 'Device removed' },
      ok: true,
    })
  } catch (err) {
    console.error('Device remove error:', err)
    res.status(500).json({ error: 'Internal server error', code: 'INTERNAL_ERROR', ok: false })
  }
})

export default router
