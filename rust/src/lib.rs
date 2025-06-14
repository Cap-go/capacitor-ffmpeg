use anyhow::anyhow;
use std::ffi::{CStr, CString};
use std::os::raw::{c_void, c_char, c_int};
use std::sync::Arc;
use std::sync::Mutex;

mod plugin;
use plugin::CapacitorFFmpegPlugin;

macro_rules! lock_mutex_or_log {
    (
        $MUTEX: ident
    ) => {
        match $MUTEX.lock() {
            Ok(val) => val,
            Err(err) => {
                eprintln!("Cannot lock mutex: {}", err);
                return;
            }
        }
    };
}

macro_rules! lock_mutex_or_return {
    (
        $MUTEX: ident, $error_code: expr
    ) => {
        match $MUTEX.lock() {
            Ok(val) => val,
            Err(err) => {
                eprintln!("Cannot lock mutex: {}", err);
                return $error_code;
            }
        }
    };
}

/// Convert a C string to a Rust String safely
/// Returns None if the pointer is null or the string is invalid UTF-8
unsafe fn c_str_to_string(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    
    match CStr::from_ptr(ptr).to_str() {
        Ok(s) => Some(s.to_string()),
        Err(_) => None,
    }
}

/// Initialize FFmpeg 
/// 
/// # Returns
/// 
/// A pointer to the plugin on success, NULL on failure
#[no_mangle]
pub extern "C" fn init_ffmpeg_plugin(
    inform_about_progress: extern "C" fn(progress: f64, progress_file_id: *const c_char) -> c_int,
) -> *mut c_void {

    let wrapped_inform_about_progress = Box::new(move |progress: f64, progress_file_id: String| {
        // Convert String to CString (null-terminated C string)
        let c_string = CString::new(progress_file_id)
            .map_err(|_| anyhow!("Failed to convert progress_file_id to C string"))?;
        
        // Call the C function with proper C string pointer
        let result = inform_about_progress(progress, c_string.as_ptr());
        if result != 0 {
            return Err(anyhow!("Failed to inform about progress"));
        }
        
        // CString is dropped here, so C function must not rely on data persisting
        Ok(())
    });

    let plugin = CapacitorFFmpegPlugin::new(wrapped_inform_about_progress);

    // Now, we have some things to do... It's not going to be pretty.
    let boxed_plugin = Box::new(plugin);

    let arc_mutex_plugin = Arc::new(Mutex::new(boxed_plugin));
    Box::into_raw(Box::new(arc_mutex_plugin)) as *mut c_void
}

/// Deinitialize the plugin
/// 
/// # Arguments
/// 
/// * `plugin` - A pointer to the plugin
#[no_mangle]
pub extern "C" fn deinit_ffmpeg_plugin(plugin: *mut c_void) {
    let plugin = unsafe { Box::from_raw(plugin as *mut Arc<Mutex<Box<CapacitorFFmpegPlugin>>>) };
    let mut locked_plugin = lock_mutex_or_log!(plugin);
    locked_plugin.destroy();
}

/// Re-encode a video file to a lower resolution
/// 
/// # Arguments
/// 
/// * `plugin` - A pointer to the plugin
/// * `input_path` - The path to the input video file
/// * `output_path` - The path to the output video file
/// * `target_width` - The target width of the output video
/// * `target_height` - The target height of the output video
/// 
/// # Returns
/// 
/// 0 on success, -1 on error
#[no_mangle]
pub extern "C" fn reencode_video(plugin: *mut c_void, input_path: *const c_char, output_path: *const c_char, target_width: c_int, target_height: c_int, bitrate: c_int) -> c_int {
    // Safety check: ensure plugin pointer is not null
    if plugin.is_null() {
        eprintln!("Plugin pointer is null");
        return -1;
    }

    // Convert C strings to Rust strings safely
    let input_path_str = unsafe { c_str_to_string(input_path) };
    let output_path_str = unsafe { c_str_to_string(output_path) };

    let input_path_str = match input_path_str {
        Some(path) => path,
        None => {
            eprintln!("Invalid input path");
            return -1;
        }
    };

    let output_path_str = match output_path_str {
        Some(path) => path,
        None => {
            eprintln!("Invalid output path");
            return -1;
        }
    };

    // Get reference to the plugin without consuming the Box
    let plugin_ref = unsafe { &*(plugin as *const Arc<Mutex<Box<CapacitorFFmpegPlugin>>>) };
    let locked_plugin = lock_mutex_or_return!(plugin_ref, -1);

    // Call the actual re-encoding function
    let bitrate_option = if bitrate <= 0 {
        None // Use default bitrate.
    } else {
        Some(bitrate as u64)
    };

    match locked_plugin.reencode_video(&input_path_str, &output_path_str, target_width as u32, target_height as u32, bitrate_option) {
        Ok(()) => {
            println!("Video re-encoding completed successfully");
            0
        }
        Err(e) => {
            eprintln!("Video re-encoding failed: {:?}", e);
            eprintln!("Backtrace:\n{}", e.backtrace());
            -1
        }
    }
}