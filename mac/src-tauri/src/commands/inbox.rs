use reqwest::Method;
use serde_json::{json, Value};
use tauri::Emitter;
use tokio::io::AsyncWriteExt;

use crate::api_client::ApiClient;

/// Get the inbox (list of pending and downloaded transfers).
#[tauri::command]
pub async fn get_inbox(
    api_client: tauri::State<'_, ApiClient>,
) -> Result<Value, String> {
    api_client.request(Method::GET, "/transfers/inbox", None).await
}

/// Download a file from OSS, save to ~/Downloads, mark as downloaded.
/// Emits `download-progress` events (0-100).
/// Returns the saved file path.
#[tauri::command]
pub async fn download_file(
    app: tauri::AppHandle,
    download_url: String,
    file_name: String,
    transfer_id: String,
    api_client: tauri::State<'_, ApiClient>,
) -> Result<String, String> {
    let save_path = download_to_disk(&app, &download_url, &file_name, &transfer_id).await?;

    // Mark transfer as downloaded in the backend
    api_client
        .request(
            Method::POST,
            &format!("/transfers/{transfer_id}/downloaded"),
            None,
        )
        .await?;

    Ok(save_path)
}

/// Re-download a previously downloaded file. Does NOT call /downloaded endpoint.
#[tauri::command]
pub async fn redownload_file(
    app: tauri::AppHandle,
    download_url: String,
    file_name: String,
    transfer_id: String,
) -> Result<String, String> {
    download_to_disk(&app, &download_url, &file_name, &transfer_id).await
}

/// Shared download logic: stream from presigned URL to ~/Downloads with progress.
async fn download_to_disk(
    app: &tauri::AppHandle,
    download_url: &str,
    file_name: &str,
    transfer_id: &str,
) -> Result<String, String> {
    // GET from presigned URL (NO auth header — presigned URL is self-authenticating)
    let client = reqwest::Client::new();
    let response = client
        .get(download_url)
        .send()
        .await
        .map_err(|e| format!("Download request failed: {e}"))?;

    if !response.status().is_success() {
        return Err(format!("Download failed with status: {}", response.status()));
    }

    let content_length = response.content_length().unwrap_or(0);

    // Determine save path in ~/Downloads with collision avoidance
    let downloads_dir = dirs::download_dir()
        .ok_or("Cannot find Downloads directory")?;
    let save_path = unique_file_path(&downloads_dir, file_name);

    // Stream response to file with progress
    let mut file = tokio::fs::File::create(&save_path)
        .await
        .map_err(|e| format!("Cannot create file: {e}"))?;

    let mut stream = response.bytes_stream();
    let mut bytes_received: u64 = 0;
    let mut last_percent: u64 = 0;

    use futures_util::StreamExt;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| format!("Download stream error: {e}"))?;
        file.write_all(&chunk)
            .await
            .map_err(|e| format!("File write error: {e}"))?;

        bytes_received += chunk.len() as u64;
        let percent = if content_length > 0 {
            (bytes_received * 100) / content_length
        } else {
            0
        };

        if percent != last_percent {
            last_percent = percent;
            let _ = app.emit("download-progress", json!({
                "transfer_id": transfer_id,
                "percent": percent,
                "bytes_received": bytes_received,
                "total_bytes": content_length,
            }));
        }
    }

    file.flush().await.map_err(|e| format!("File flush error: {e}"))?;

    Ok(save_path.to_string_lossy().to_string())
}

/// Generate a unique file path: if file.txt exists, try file (1).txt, file (2).txt, etc.
fn unique_file_path(dir: &std::path::Path, file_name: &str) -> std::path::PathBuf {
    let path = dir.join(file_name);
    if !path.exists() {
        return path;
    }

    let stem = std::path::Path::new(file_name)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or(file_name);
    let ext = std::path::Path::new(file_name)
        .extension()
        .and_then(|s| s.to_str());

    for i in 1..1000 {
        let new_name = match ext {
            Some(e) => format!("{stem} ({i}).{e}"),
            None => format!("{stem} ({i})"),
        };
        let candidate = dir.join(new_name);
        if !candidate.exists() {
            return candidate;
        }
    }

    // Fallback — very unlikely
    dir.join(format!("{file_name}.download"))
}
