use reqwest::Method;
use serde_json::Value;

use crate::api_client::ApiClient;

/// Get all devices for the current user.
#[tauri::command]
pub async fn get_devices(
    api_client: tauri::State<'_, ApiClient>,
) -> Result<Value, String> {
    api_client.request(Method::GET, "/devices/", None).await
}

/// Remove a device by ID.
#[tauri::command]
pub async fn remove_device(
    device_id: String,
    api_client: tauri::State<'_, ApiClient>,
) -> Result<(), String> {
    let path = format!("/devices/{device_id}");
    api_client.request(Method::DELETE, &path, None).await?;
    Ok(())
}
