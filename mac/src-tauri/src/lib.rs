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

/// Show main panel and hide login window (called after successful auth).
#[tauri::command]
async fn show_main_hide_login(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(login_win) = app.get_webview_window("login") {
        let _ = login_win.hide();
    }
    // Main window is shown via tray click; just ensure it's ready
    // The tray click handler will show the main window when clicked
    Ok(())
}

/// Show the login window (called when auth check fails or session expires).
#[tauri::command]
async fn show_login(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(login_win) = app.get_webview_window("login") {
        let _ = login_win.show();
        let _ = login_win.set_focus();
    }
    Ok(())
}

/// Update tray icon badge based on pending inbox count.
/// Swaps tray icon between normal and badge (red dot) versions.
#[tauri::command]
async fn update_tray_badge(app: tauri::AppHandle, has_pending: bool) -> Result<(), String> {
    use tauri::image::Image;
    use tauri::tray::TrayIconId;

    let icon_bytes: &[u8] = if has_pending {
        include_bytes!("../icons/tray-icon-badge.png")
    } else {
        include_bytes!("../icons/tray-icon.png")
    };

    let icon = Image::from_bytes(icon_bytes).map_err(|e| format!("Failed to load tray icon: {e}"))?.to_owned();

    if let Some(tray) = app.tray_by_id(&TrayIconId::new("main")) {
        tray.set_icon(Some(icon)).map_err(|e| format!("Failed to set tray icon: {e}"))?;
    } else {
        // Try default tray icon (unnamed trays get auto-generated IDs)
        // Fall back to iterating — but Tauri v2 doesn't expose tray list.
        // The tray was built without explicit ID, so we can't reliably find it.
        // This is acceptable — the badge is a nice-to-have visual indicator.
    }

    Ok(())
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
            {
                app.set_activation_policy(tauri::ActivationPolicy::Accessory);

                // Make window backgrounds fully transparent (fix corner color artifacts)
                for label in &["main", "login"] {
                    if let Some(win) = app.get_webview_window(label) {
                        use tauri::window::Color;
                        let _ = win.set_background_color(Some(Color(0, 0, 0, 0)));
                    }
                }
            }

            // Check auth state on startup: if no tokens, show login window
            let has_tokens = credentials::get_access_token().is_ok();
            if !has_tokens {
                if let Some(login_win) = app.get_webview_window("login") {
                    let _ = login_win.show();
                    let _ = login_win.set_focus();
                }
            }

            // Create tray icon in synchronous .setup() context
            // CRITICAL: Do NOT create TrayIcon in async context (Pitfall 2)
            let _tray = TrayIconBuilder::with_id("main")
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
        .on_window_event(move |_window, _event| {
            // Panel visibility is toggled exclusively via tray icon click.
            // Auto-hide on blur removed: it breaks drag-and-drop from Finder
            // and causes crashes when native file dialogs steal focus.
        })
        .invoke_handler(tauri::generate_handler![
            show_main_hide_login,
            show_login,
            update_tray_badge,
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
