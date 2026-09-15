//! Mobile entry point for Max Desktop (iOS/Android).

#[tauri::mobile_entry_point]
fn main() {
    max_desktop::run();
}
