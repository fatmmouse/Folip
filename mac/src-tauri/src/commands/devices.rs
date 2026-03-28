use reqwest::Method;
use serde_json::{json, Value};

use crate::api_client::ApiClient;

/// Get all devices for the current user.
#[tauri::command]
pub async fn get_devices(
    api_client: tauri::State<'_, ApiClient>,
) -> Result<Value, String> {
    api_client.request(Method::GET, "/devices/", None).await
}

/// Rename a device.
#[tauri::command]
pub async fn rename_device(
    device_id: String,
    device_name: String,
    api_client: tauri::State<'_, ApiClient>,
) -> Result<Value, String> {
    let path = format!("/devices/{device_id}");
    let body = json!({ "device_name": device_name });
    api_client.request(Method::PUT, &path, Some(body)).await
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
