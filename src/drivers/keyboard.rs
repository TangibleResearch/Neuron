// src/drivers/keyboard.rs

use device_query::{DeviceQuery, DeviceState};

/// Cross-platform check to see if a keyboard interface is active and accessible
pub fn check_keyboard_present() -> bool {
    DeviceState::checked_new()
        .map(|device_state| {
            let _keys = device_state.get_keys();
        })
        .is_some()
}
