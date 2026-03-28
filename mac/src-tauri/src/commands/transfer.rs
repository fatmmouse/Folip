use std::sync::atomic::Ordering;
use reqwest::Method;
use serde_json::{json, Value};
use tauri::Emitter;
use tokio::io::AsyncReadExt;

use crate::api_client::ApiClient;
use crate::UploadState;

const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024; // 500MB

/// Prepare an upload: validate file size, request presigned URL from backend.
#[tauri::command]
pub async fn prepare_upload(
    file_path: String,
    target_device_id: String,
    api_client: tauri::State<'_, ApiClient>,
) -> Result<Value, String> {
    let metadata = tokio::fs::metadata(&file_path)
        .await
        .map_err(|e| format!("Cannot read file: {e}"))?;

    let file_size = metadata.len();
    if file_size > MAX_FILE_SIZE {
        return Err(format!(
            "File size ({:.1}MB) exceeds 500MB limit",
            file_size as f64 / 1_048_576.0
        ));
    }

    let file_name = std::path::Path::new(&file_path)
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or("Invalid file name")?
        .to_string();

    let body = json!({
        "target_device_id": target_device_id,
        "file_name": file_name,
        "file_size": file_size,
    });

    let data = api_client.request(Method::POST, "/transfers/prepare", Some(body)).await?;

    Ok(json!({
        "transfer_id": data.get("transfer_id"),
        "upload_url": data.get("upload_url"),
    }))
}

/// Upload a file to OSS via presigned URL, then confirm the transfer.
/// Emits `upload-progress` events (0-100) and `upload-complete` on success.
#[tauri::command]
pub async fn upload_file(
    app: tauri::AppHandle,
    file_path: String,
    upload_url: String,
    transfer_id: String,
    target_device_id: String,
    api_client: tauri::State<'_, ApiClient>,
    upload_state: tauri::State<'_, UploadState>,
) -> Result<(), String> {
    upload_state.is_uploading.store(true, Ordering::SeqCst);

    let result = upload_file_inner(
        &app, &file_path, &upload_url, &transfer_id, &target_device_id, &api_client,
    ).await;

    upload_state.is_uploading.store(false, Ordering::SeqCst);

    match result {
        Ok(()) => {
            let _ = app.emit("upload-complete", json!({ "transfer_id": transfer_id }));
            Ok(())
        }
        Err(e) => {
            let _ = app.emit("upload-error", json!({ "error": e }));
            Err(e)
        }
    }
}

async fn upload_file_inner(
    app: &tauri::AppHandle,
    file_path: &str,
    upload_url: &str,
    transfer_id: &str,
    target_device_id: &str,
    api_client: &ApiClient,
) -> Result<(), String> {
    // Read entire file into memory (up to 500MB validated by prepare_upload)
    // then upload with progress via a stream wrapper
    let mut file = tokio::fs::File::open(file_path)
        .await
        .map_err(|e| format!("Cannot open file: {e}"))?;

    let file_size = file.metadata()
        .await
        .map_err(|e| format!("Cannot read file metadata: {e}"))?
        .len();

    // Use a tokio channel to stream chunks with progress
    let (tx, rx) = tokio::sync::mpsc::channel::<Result<bytes::Bytes, std::io::Error>>(4);

    let app_clone = app.clone();
    let transfer_id_clone = transfer_id.to_string();

    // Spawn task to read file in chunks and send through channel
    let read_task = tokio::spawn(async move {
        let mut bytes_sent: u64 = 0;
        let mut buf = vec![0u8; 256 * 1024]; // 256KB chunks
        let mut last_percent: u64 = 0;

        loop {
            let n = file.read(&mut buf).await.map_err(|e| format!("Read error: {e}"))?;
            if n == 0 {
                break;
            }

            let chunk = bytes::Bytes::copy_from_slice(&buf[..n]);
            if tx.send(Ok(chunk)).await.is_err() {
                return Err("Upload channel closed".to_string());
            }

            bytes_sent += n as u64;
            let percent = if file_size > 0 {
                (bytes_sent * 100) / file_size
            } else {
                100
            };

            if percent != last_percent {
                last_percent = percent;
                let _ = app_clone.emit("upload-progress", json!({
                    "transfer_id": transfer_id_clone,
                    "percent": percent,
                    "bytes_sent": bytes_sent,
                    "total_bytes": file_size,
                }));
            }
        }

        Ok::<(), String>(())
    });

    // Convert receiver to a stream for reqwest
    let stream = tokio_stream::wrappers::ReceiverStream::new(rx);
    let body = reqwest::Body::wrap_stream(stream);

    // PUT to presigned URL (NO auth header — presigned URL is self-authenticating)
    let client = reqwest::Client::new();
    let put_response = client
        .put(upload_url)
        .header("Content-Type", "application/octet-stream")
        .header("Content-Length", file_size.to_string())
        .body(body)
        .send()
        .await
        .map_err(|e| format!("Upload failed: {e}"))?;

    // Wait for the read task to finish
    read_task.await
        .map_err(|e| format!("Upload task panicked: {e}"))??;

    if !put_response.status().is_success() {
        return Err(format!("OSS upload failed with status: {}", put_response.status()));
    }

    // Confirm the transfer with the backend
    let confirm_body = json!({ "target_device_id": target_device_id });
    api_client
        .request(
            Method::POST,
            &format!("/transfers/{transfer_id}/confirm"),
            Some(confirm_body),
        )
        .await?;

    Ok(())
}
