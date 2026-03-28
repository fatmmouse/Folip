use keyring::Entry;

const SERVICE_NAME: &str = "com.folip.app";
const KEY_ACCESS_TOKEN: &str = "access_token";
const KEY_REFRESH_TOKEN: &str = "refresh_token";
const KEY_DEVICE_ID: &str = "device_id";
const KEY_API_BASE_URL: &str = "api_base_url";

const DEFAULT_API_BASE_URL: &str = "https://folip-api-ngvinksolj.cn-hangzhou.fcapp.run";

fn entry(key: &str) -> Result<Entry, String> {
    Entry::new(SERVICE_NAME, key).map_err(|e| format!("Keychain entry error: {e}"))
}

pub fn save_tokens(access_token: &str, refresh_token: &str) -> Result<(), String> {
    entry(KEY_ACCESS_TOKEN)?
        .set_password(access_token)
        .map_err(|e| format!("Failed to save access token: {e}"))?;
    entry(KEY_REFRESH_TOKEN)?
        .set_password(refresh_token)
        .map_err(|e| format!("Failed to save refresh token: {e}"))?;
    Ok(())
}

pub fn get_access_token() -> Result<String, String> {
    entry(KEY_ACCESS_TOKEN)?
        .get_password()
        .map_err(|e| format!("Failed to read access token: {e}"))
}

pub fn get_refresh_token() -> Result<String, String> {
    entry(KEY_REFRESH_TOKEN)?
        .get_password()
        .map_err(|e| format!("Failed to read refresh token: {e}"))
}

pub fn save_device_id(device_id: &str) -> Result<(), String> {
    entry(KEY_DEVICE_ID)?
        .set_password(device_id)
        .map_err(|e| format!("Failed to save device ID: {e}"))
}

pub fn get_device_id() -> Result<String, String> {
    entry(KEY_DEVICE_ID)?
        .get_password()
        .map_err(|e| format!("Failed to read device ID: {e}"))
}

pub fn clear_all() -> Result<(), String> {
    for key in &[KEY_ACCESS_TOKEN, KEY_REFRESH_TOKEN, KEY_DEVICE_ID, KEY_API_BASE_URL] {
        if let Ok(e) = entry(key) {
            // Ignore NoEntry errors — credential may not exist yet
            let _ = e.delete_credential();
        }
    }
    Ok(())
}

pub fn get_api_base_url() -> String {
    entry(KEY_API_BASE_URL)
        .ok()
        .and_then(|e| e.get_password().ok())
        .unwrap_or_else(|| DEFAULT_API_BASE_URL.to_string())
}
