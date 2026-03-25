use std::sync::Arc;
use reqwest::{Client, Method, StatusCode};
use serde_json::Value;
use tokio::sync::Mutex;

use crate::credentials;

/// HTTP API client with automatic token refresh on 401.
/// The refresh_lock ensures only one concurrent refresh request runs at a time
/// (Pitfall 5: token refresh race condition).
pub struct ApiClient {
    pub client: Client,
    refresh_lock: Arc<Mutex<()>>,
}

impl ApiClient {
    pub fn new() -> Self {
        let client = Client::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .expect("Failed to create HTTP client");

        Self {
            client,
            refresh_lock: Arc::new(Mutex::new(())),
        }
    }

    /// Send an authenticated request to the backend API.
    /// Automatically retries once with a refreshed token on 401.
    pub async fn request(
        &self,
        method: Method,
        path: &str,
        body: Option<Value>,
    ) -> Result<Value, String> {
        let access_token = credentials::get_access_token()?;
        let url = format!("{}{}", credentials::get_api_base_url(), path);

        let response = self.send_request(&method, &url, body.clone(), &access_token).await?;

        if response.status() == StatusCode::UNAUTHORIZED {
            // Acquire mutex — only one refresh at a time
            let _lock = self.refresh_lock.lock().await;

            // Re-read token: another request may have already refreshed it
            let current_token = credentials::get_access_token()
                .unwrap_or_default();

            if current_token == access_token {
                // Token hasn't changed — we need to refresh
                self.refresh_token().await?;
            }

            // Retry with the (now-refreshed) token
            let new_token = credentials::get_access_token()?;
            let retry_response = self.send_request(&method, &url, body, &new_token).await?;
            return self.parse_response(retry_response).await;
        }

        self.parse_response(response).await
    }

    /// Send a raw request without automatic 401 retry.
    /// Used for public endpoints (login, register) that don't need auth.
    pub async fn request_public(
        &self,
        method: Method,
        path: &str,
        body: Option<Value>,
    ) -> Result<Value, String> {
        let url = format!("{}{}", credentials::get_api_base_url(), path);

        let mut req = self.client.request(method, &url);
        if let Some(b) = body {
            req = req.json(&b);
        }

        let response = req.send().await.map_err(|e| format!("Request failed: {e}"))?;
        self.parse_response(response).await
    }

    /// Refresh the access token using the stored refresh token.
    /// On TOKEN_REUSE error, clears all credentials (re-login required).
    pub async fn refresh_token(&self) -> Result<(), String> {
        let refresh_token = credentials::get_refresh_token()?;
        let url = format!("{}/auth/refresh", credentials::get_api_base_url());

        let body = serde_json::json!({ "refreshToken": refresh_token });
        let response = self.client
            .post(&url)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Refresh request failed: {e}"))?;

        let json: Value = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse refresh response: {e}"))?;

        if json.get("ok") == Some(&Value::Bool(true)) {
            let data = json.get("data").ok_or("Missing data in refresh response")?;
            let new_access = data.get("accessToken")
                .and_then(|v| v.as_str())
                .ok_or("Missing accessToken in refresh response")?;
            let new_refresh = data.get("refreshToken")
                .and_then(|v| v.as_str())
                .ok_or("Missing refreshToken in refresh response")?;
            credentials::save_tokens(new_access, new_refresh)?;
            Ok(())
        } else {
            // Token reuse or other error — clear credentials, require re-login
            let error_code = json.get("code")
                .and_then(|v| v.as_str())
                .unwrap_or("UNKNOWN");
            let error_msg = json.get("error")
                .and_then(|v| v.as_str())
                .unwrap_or("Token refresh failed");
            let _ = credentials::clear_all();
            Err(format!("Re-login required: {error_msg} ({error_code})"))
        }
    }

    async fn send_request(
        &self,
        method: &Method,
        url: &str,
        body: Option<Value>,
        token: &str,
    ) -> Result<reqwest::Response, String> {
        let mut req = self.client.request(method.clone(), url)
            .header("Authorization", format!("Bearer {token}"));
        if let Some(b) = body {
            req = req.json(&b);
        }
        req.send().await.map_err(|e| format!("Request failed: {e}"))
    }

    async fn parse_response(&self, response: reqwest::Response) -> Result<Value, String> {
        let status = response.status();
        let json: Value = response
            .json()
            .await
            .map_err(|e| format!("Failed to parse response: {e}"))?;

        if json.get("ok") == Some(&Value::Bool(true)) {
            Ok(json)
        } else {
            let error_msg = json.get("error")
                .and_then(|v| v.as_str())
                .unwrap_or("Unknown error");
            let error_code = json.get("code")
                .and_then(|v| v.as_str())
                .unwrap_or("UNKNOWN");
            Err(format!("[{status}] {error_msg} ({error_code})"))
        }
    }
}
