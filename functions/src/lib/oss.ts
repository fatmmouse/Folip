import OSS from 'ali-oss'

// Initialize at module level for warm invocation reuse (Pitfall 4)
const client = new OSS({
  accessKeyId: process.env.OSS_ACCESS_KEY_ID || '',
  accessKeySecret: process.env.OSS_ACCESS_KEY_SECRET || '',
  bucket: process.env.OSS_BUCKET || 'folip-transit',
  region: process.env.OSS_REGION || 'oss-cn-hangzhou',
  authorizationV4: true,
  ...(process.env.OSS_CUSTOM_DOMAIN ? {
    endpoint: process.env.OSS_CUSTOM_DOMAIN,
    cname: true,
  } : {}),
})

export async function generatePutUrl(objectKey: string, expiresSeconds = 3600): Promise<string> {
  return await client.signatureUrlV4('PUT', expiresSeconds, { headers: {} }, objectKey)
}

export async function generateGetUrl(objectKey: string, expiresSeconds = 86400): Promise<string> {
  return await client.signatureUrlV4('GET', expiresSeconds, { headers: {} }, objectKey)
}
