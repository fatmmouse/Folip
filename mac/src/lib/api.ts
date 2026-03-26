import { invoke } from '@tauri-apps/api/core';

// Auth commands
export async function login(email: string, password: string) {
  return invoke<{ user_id: string; email: string; device_id: string; device_name: string }>('login', { email, password });
}

export async function register(email: string, password: string) {
  return invoke<{ user_id: string; email: string; device_id: string; device_name: string }>('register', { email, password });
}

export async function logout() {
  return invoke<void>('logout');
}

export async function checkAuth() {
  return invoke<boolean>('check_auth');
}

export async function refreshTokens() {
  return invoke<void>('refresh_tokens');
}

// Device commands
export async function getDevices() {
  return invoke<{ devices: Array<{ device_id: string; device_name: string; registered_at: number }> }>('get_devices');
}

export async function removeDevice(deviceId: string) {
  return invoke<void>('remove_device', { deviceId });
}

// Transfer commands
export async function prepareUpload(filePath: string, targetDeviceId: string) {
  return invoke<{ transfer_id: string; upload_url: string }>('prepare_upload', { filePath, targetDeviceId });
}

export async function uploadFile(filePath: string, uploadUrl: string, transferId: string, targetDeviceId: string) {
  return invoke<void>('upload_file', { filePath, uploadUrl, transferId, targetDeviceId });
}

// Inbox commands
export async function getInbox() {
  return invoke<{ transfers: Array<{ transfer_id: string; file_name: string; file_size: number; sender_device_id: string; created_at: number; status: string; download_url: string }> }>('get_inbox');
}

export async function downloadFile(downloadUrl: string, fileName: string, transferId: string) {
  return invoke<string>('download_file', { downloadUrl, fileName, transferId });
}

export async function redownloadFile(downloadUrl: string, fileName: string, transferId: string) {
  return invoke<string>('redownload_file', { downloadUrl, fileName, transferId });
}
