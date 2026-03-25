use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tauri::{
    Manager,
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    WindowEvent,
};
use tauri_plugin_positioner::{WindowExt, Position};

mod credentials;
mod api_client;
mod commands;

/// Shared state to track whether an upload is in progress.
/// When uploading, the panel should NOT auto-hide on blur (per D-02).
pub struct UploadState {
    pub is_uploading: Arc<AtomicBool>,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let upload_state = UploadState {
        is_uploading: Arc::new(AtomicBool::new(false)),
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_positioner::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .manage(api_client::ApiClient::new())
        .manage(upload_state)
        .setup(move |app| {
            // D-01: Hide Dock icon — app runs as menu bar utility only
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // Create tray icon in synchronous .setup() context
            // CRITICAL: Do NOT create TrayIcon in async context (Pitfall 2)
            let _tray = TrayIconBuilder::new()
                .icon(app.default_window_icon().unwrap().clone())
                .show_menu_on_left_click(false) // CRITICAL: macOS bug workaround (Pitfall 1)
                .on_tray_icon_event(|tray_handle, event| {
                    // Pass event to positioner plugin first
                    tauri_plugin_positioner::on_tray_event(tray_handle.app_handle(), &event);

                    // Handle left click to toggle panel visibility
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray_handle.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            if window.is_visible().unwrap_or(false) {
                                let _ = window.hide();
                            } else {
                                // Position at TrayCenter then show
                                let _ = window.as_ref().window().move_window(Position::TrayCenter);
                                let _ = window.show();
                                let _ = window.set_focus();
                            }
                        }
                    }
                })
                .build(app)?;

            Ok(())
        })
        .on_window_event(move |window, event| {
            // D-02: Click outside panel to auto-dismiss
            // Exception: do NOT hide if upload is in progress
            if let WindowEvent::Focused(false) = event {
                if window.label() == "main" {
                    let state = window.state::<UploadState>();
                    if !state.is_uploading.load(Ordering::Relaxed) {
                        let _ = window.hide();
                    }
                }
            }
        })
        .invoke_handler(tauri::generate_handler![
            commands::auth::login,
            commands::auth::register,
            commands::auth::logout,
            commands::auth::check_auth,
            commands::auth::refresh_tokens,
            commands::devices::get_devices,
            commands::devices::remove_device,
            commands::transfer::prepare_upload,
            commands::transfer::upload_file,
            commands::inbox::get_inbox,
            commands::inbox::download_file,
            commands::inbox::redownload_file,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Folip");
}
