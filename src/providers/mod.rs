//! ModelProvider subsystem — re-exported from `max-providers`.

pub use max_providers::*;

// Keep traits.rs as a file module so its #[cfg(test)] block compiles.
#[path = "traits.rs"]
pub mod traits;
