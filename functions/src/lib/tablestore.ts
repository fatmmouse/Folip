import TableStore from 'tablestore'

// Initialize at module level for warm invocation reuse (Pitfall 4)
export const tsClient = new TableStore.Client({
  accessKeyId: process.env.OTS_ACCESS_KEY_ID || '',
  secretAccessKey: process.env.OTS_ACCESS_KEY_SECRET || '',
  endpoint: process.env.TABLESTORE_ENDPOINT || '',
  instancename: process.env.TABLESTORE_INSTANCE || '',
})

// Table names -- centralized for consistency
export const Tables = {
  USERS: 'users',
  EMAIL_INDEX: 'email_index',
  DEVICES: 'devices',
  REFRESH_TOKENS: 'refresh_tokens',
  TRANSFERS: 'transfers',
} as const

// Helper to extract attribute value from TableStore row
export function getAttr(row: any, name: string): any {
  if (row.attributes) {
    for (const attr of row.attributes) {
      if (attr.columnName === name) return attr.columnValue
    }
  }
  if (row.primaryKey) {
    for (const pk of row.primaryKey) {
      if (pk.name === name) return pk.value
    }
  }
  return undefined
}

// Helper to build primary key array
export function pk(pairs: Record<string, string | number>): Array<Record<string, string | number>> {
  return Object.entries(pairs).map(([k, v]) => ({ [k]: v }))
}

// Helper to build attribute columns for putRow
export function attrs(pairs: Record<string, string | number | undefined>): Array<{ [key: string]: string | number }> {
  return Object.entries(pairs)
    .filter(([, v]) => v !== undefined)
    .map(([k, v]) => ({ [k]: v as string | number }))
}
