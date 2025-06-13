use std::os::raw::c_int;

#[cfg(feature = "ffmpeg")]
use ffmpeg_next as ffmpeg;

/// Adds two numbers together
/// 
/// # Arguments
/// 
/// * `a` - The first number
/// * `b` - The second number
/// 
/// # Returns
/// 
/// The sum of `a` and `b`
#[no_mangle]
pub extern "C" fn add_two_numbers(a: c_int, b: c_int) -> c_int {
    a + b
}

/// Initialize FFmpeg (only available when ffmpeg feature is enabled)
/// 
/// # Returns
/// 
/// 0 on success, error code on failure
#[cfg(feature = "ffmpeg")]
#[no_mangle]
pub extern "C" fn init_ffmpeg() -> c_int {
    match ffmpeg::init() {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Stub function when FFmpeg is not available
#[cfg(not(feature = "ffmpeg"))]
#[no_mangle]
pub extern "C" fn init_ffmpeg() -> c_int {
    // Return error code indicating FFmpeg is not available
    -2
}