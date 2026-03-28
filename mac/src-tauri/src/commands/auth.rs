use reqwest::Method;
use serde_json::{json, Value};

use crate::api_client::ApiClient;
use crate::credentials;

/// Login with email/password. Saves tokens and device_id to Keychain.
#[tauri::command]
pub async fn login(
    email: String,
    password: String,
    api_client: tauri::State<'_, ApiClient>,
) -> Result<Value, String> {
    // D-15: auto device naming via hostname
    let device_name = hostname::get()
        .map(|h| h.to_string_lossy().to_string())
        .unwrap_or_else(|_| "Mac".to_string());

    let body = json!({
        "email": email,
        "password": password,
        "device_name": device_name,
    });

    let data = api_client.request_public(Method::POST, "/auth/login", Some(body)).await?;

    // Save tokens and device_id to Keychain
    let access_token = data.get("accessToken")
        .and_then(|v| v.as_str())
        .ok_or("Missing accessToken")?;
    let refresh_token = data.get("refreshToken")
        .and_then(|v| v.as_str())
        .ok_or("Missing refreshToken")?;
    let device_id = data.get("device_id")
        .and_then(|v| v.as_str())
        .ok_or("Missing device_id")?;

    credentials::save_tokens(access_token, refresh_token)?;
    credentials::save_device_id(device_id)?;

    // Return user data (without tokens — they're in Keychain)
    Ok(json!({
        "user_id": data.get("user_id"),
        "email": data.get("email"),
        "device_id": data.get("device_id"),
        "device_name": data.get("device_name"),
    }))
}

/// Register a new account. Saves tokens and device_id to Keychain.
#[tauri::command]
pub async fn register(
    email: String,
    password: String,
    api_client: tauri::State<'_, ApiClient>,
) -> Result<Value, String> {
    let device_name = hostname::get()
        .map(|h| h.to_string_lossy().to_string())
        .unwrap_or_else(|_| "Mac".to_string());

    let body = json!({
        "email": email,
        "password": password,
        "device_name": device_name,
    });

    let data = api_client.request_public(Method::POST, "/auth/register", Some(body)).await?;

    let access_token = data.get("accessToken")
        .and_then(|v| v.as_str())
        .ok_or("Missing accessToken")?;
    let refresh_token = data.get("refreshToken")
        .and_then(|v| v.as_str())
        .ok_or("Missing refreshToken")?;
    let device_id = data.get("device_id")
        .and_then(|v| v.as_str())
        .ok_or("Missing device_id")?;

    credentials::save_tokens(access_token, refresh_token)?;
    credentials::save_device_id(device_id)?;

    Ok(json!({
        "user_id": data.get("user_id"),
        "email": data.get("email"),
        "device_id": data.get("device_id"),
        "device_name": data.get("device_name"),
    }))
}

/// Logout: call API then clear all Keychain credentials.
#[tauri::command]
pub async fn logout(
    api_client: tauri::State<'_, ApiClient>,
) -> Result<(), String> {
    // Best-effort API call — clear credentials regardless of outcome
    let _ = api_client.request(Method::POST, "/auth/logout", None).await;
    credentials::clear_all()?;
    Ok(())
}

/// Check if access token exists in Keychain (quick auth state check).
#[tauri::command]
pub async fn check_auth() -> Result<bool, String> {
    match credentials::get_access_token() {
        Ok(_) => Ok(true),
        Err(_) => Ok(false),
    }
}

/// Force a token refresh. Used when frontend detects stale auth.
#[tauri::command]
pub async fn refresh_tokens(
    api_client: tauri::State<'_, ApiClient>,
) -> Result<(), String> {
    api_client.refresh_token().await
}
