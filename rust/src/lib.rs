use anyhow::anyhow;
use std::ffi::{CStr, CString};
use std::os::raw::{c_void, c_char, c_int};
use std::sync::Arc;
use std::sync::Mutex;

mod plugin;
use plugin::CapacitorFFmpegPlugin;

/// C-compatible result structure for communicating with Swift
#[repr(C)]
pub struct CResult {
    pub ok: bool,
    pub error_message: *mut c_char, // NULL if ok = true, otherwise points to error string
}

impl CResult {
    /// Create a success result
    fn success() -> *mut CResult {
        let result = CResult {
            ok: true,
            error_message: std::ptr::null_mut(),
        };
        Box::into_raw(Box::new(result))
    }
    
    /// Create an error result with detailed message
    fn error(message: String) -> *mut CResult {
        let c_string = match CString::new(message) {
            Ok(s) => s,
            Err(_) => CString::new("Failed to create error message").unwrap(),
        };
        
        let result = CResult {
            ok: false,
            error_message: c_string.into_raw(),
        };
        Box::into_raw(Box::new(result))
    }
}

/// Free the CResult structure and associated error message
/// This must be called from Swift when done with the result
#[no_mangle]
pub extern "C" fn free_c_result(result: *mut CResult) {
    if result.is_null() {
        return;
    }
    
    unsafe {
        let boxed_result = Box::from_raw(result);
        
        // Free the error message if it exists
        if !boxed_result.error_message.is_null() {
            let _ = CString::from_raw(boxed_result.error_message);
        }
        
        // boxed_result is automatically dropped here
    }
}

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
pub extern "C" fn init_ffmpeg_plugin() -> *mut c_void {
    let plugin = match CapacitorFFmpegPlugin::new() {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Failed to initialize FFmpeg plugin: {:?}", e);
            return std::ptr::null_mut();
        }
    };

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
/// * `bitrate` - Target bitrate in bits per second (0 or negative for default)
/// * `swift_internal_data_structure_pointer` - Pointer to Swift data structure for callbacks
/// * `inform_about_progress` - Callback function for progress updates
/// 
/// # Returns
/// 
/// Pointer to CResult structure - caller must call free_c_result() when done
#[no_mangle]
pub extern "C" fn reencode_video(
    plugin: *mut c_void, 
    input_path: *const c_char, 
    output_path: *const c_char, 
    target_width: c_int, 
    target_height: c_int, 
    bitrate: c_int,
    swift_internal_data_structure_pointer: *mut c_void,
    inform_about_progress: extern "C" fn(progress: f64, swift_internal_data_structure_pointer: *mut c_void) -> c_int,
) -> *mut CResult {
    // Safety check: ensure plugin pointer is not null
    if plugin.is_null() {
        return CResult::error("Plugin pointer is null".to_string());
    }

    // Convert C strings to Rust strings safely
    let input_path_str = unsafe { c_str_to_string(input_path) };
    let output_path_str = unsafe { c_str_to_string(output_path) };

    let input_path_str = match input_path_str {
        Some(path) => path,
        None => {
            return CResult::error("Invalid input path".to_string());
        }
    };

    let output_path_str = match output_path_str {
        Some(path) => path,
        None => {
            return CResult::error("Invalid output path".to_string());
        }
    };

    // Get reference to the plugin without consuming the Box
    let plugin_ref = unsafe { &*(plugin as *const Arc<Mutex<Box<CapacitorFFmpegPlugin>>>) };
    let locked_plugin = match plugin_ref.lock() {
        Ok(plugin) => plugin,
        Err(e) => {
            let anyhow_error = anyhow!("Failed to lock plugin mutex: {:?}", e);
            let error_message = format!("Mutex lock failed: {:?}\nBacktrace:\n{}", anyhow_error, anyhow_error.backtrace());
            return CResult::error(error_message);
        }
    };

    // Call the actual re-encoding function
    let bitrate_option = if bitrate <= 0 {
        None // Use default bitrate.
    } else {
        Some(bitrate as u64)
    };

    let wrapped_inform_about_progress: Arc<Box<dyn Fn(f64) -> Result<(), anyhow::Error>>> = Arc::new(Box::new(move |progress: f64| {
        
        // Call the C function with proper C string pointer
        let result = inform_about_progress(progress, swift_internal_data_structure_pointer);
        if result != 0 {
            return Err(anyhow!("Failed to inform about progress"));
        }
        
        // CString is dropped here, so C function must not rely on data persisting
        Ok(())
    }));

    match locked_plugin.reencode_video(&input_path_str, &output_path_str, target_width as u32, target_height as u32, bitrate_option, wrapped_inform_about_progress) {
        Ok(()) => {
            println!("Video re-encoding completed successfully");
            CResult::success()
        }
        Err(e) => {
            let error_message = format!("Video re-encoding failed: {:?}\nBacktrace:\n{}", e, e.backtrace());
            eprintln!("{}", error_message);
            CResult::error(error_message)
        }
    }
}