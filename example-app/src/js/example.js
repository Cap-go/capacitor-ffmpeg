import { CapacitorFFmpeg } from '@capgo/capacitor-ffmpeg';
import { CameraPreview } from '@capgo/camera-preview';

// Global variables to track state
let cameraStarted = false;
let isRecording = false;

// Progress bar functions
function showProgressBar() {
    const progressContainer = document.getElementById('progressContainer');
    const progressBar = document.getElementById('progressBar');
    const progressText = document.getElementById('progressText');
    
    progressContainer.style.display = 'block';
    progressBar.style.width = '0%';
    progressText.textContent = 'Processing...';
}

function updateProgress(progress, message = 'Processing...') {
    const progressBar = document.getElementById('progressBar');
    const progressText = document.getElementById('progressText');
    
    const percentage = Math.round(progress * 100);
    progressBar.style.width = `${percentage}%`;
    progressText.textContent = `${message} ${percentage}%`;

    if (progress > 0.99) {
        // Hide progress bar
        hideProgressBar();
        
        console.log('Video re-encoded successfully!');
        showNotification('Video re-encoded successfully!', 'success');
    }
}

function hideProgressBar() {
    const progressContainer = document.getElementById('progressContainer');
    setTimeout(() => {
        progressContainer.style.display = 'none';
    }, 500); // Brief delay to show completion
}

// Set up progress listener when the app loads
async function setupProgressListener() {
    try {
        await CapacitorFFmpeg.addListener('progress', (data) => {
            console.log('Progress update:', data);
            updateProgress(data.progress, 'Re-encoding video...');
        });
        console.log('Progress listener set up successfully');
    } catch (error) {
        console.error('Error setting up progress listener:', error);
    }
}

// Initialize progress listener when the page loads
document.addEventListener('DOMContentLoaded', () => {
    setupProgressListener();
});

// Function to start camera preview
window.startCamera = async () => {
    try {
        console.log('Starting camera preview...');
        
        // Hide the main container and show camera container
        document.getElementById('mainContainer').classList.add('hidden');
        document.getElementById('cameraContainer').style.display = 'block';
        
        // Make body background transparent to show camera preview
        document.body.classList.add('camera-active');
        
        // Camera preview options
        const cameraPreviewOptions = {
            position: 'rear',
            height: window.innerHeight,
            width: window.innerWidth,
            quality: 85,
            x: 0,
            y: 0,
            paddingBottom: 0,
            rotateWhenOrientationChanged: true,
            toBack: true,
            tapPhoto: false,
            tapFocus: true,
            previewDrag: false,
            storeToFile: false,
            disableExifHeaderStripping: false
        };
        
        // Start the camera preview
        await CameraPreview.start(cameraPreviewOptions);
        cameraStarted = true;
        
        console.log('Camera preview started successfully!');
        
        // Add some funky effects to make it "funky"
        addFunkyEffects();
        
    } catch (error) {
        console.error('Error starting camera preview:', error);
        alert('Failed to start camera preview: ' + error.message);
        
        // Show main container again if there's an error
        document.getElementById('mainContainer').classList.remove('hidden');
        document.getElementById('cameraContainer').style.display = 'none';
        
        // Restore body background
        document.body.classList.remove('camera-active');
    }
};

// Function to toggle video recording
window.toggleButton = async () => {
    const button = document.getElementById('controlButton');
    
    try {
        if (isRecording) {
            // Stop recording
            console.log('Stopping video recording...');
            const result = await CameraPreview.stopRecordVideo();
            console.log('Video saved to:', result.videoFilePath);

            console.log('Re-encoding video...');

            const slashSplit = result.videoFilePath.split('/');
            const outputPath = slashSplit.slice(0, -1).join('/') + '/' + new Date().getTime() + '_reencoded.mp4';
            console.log('Output path:', outputPath);

            try {
                // Show progress bar
                showProgressBar();
                
                // Show notification that re-encoding started
                showNotification('Re-encoding video...', 'info');
                
                // wait 1 second
                await new Promise(resolve => setTimeout(resolve, 1000));
                
                await CapacitorFFmpeg.reencodeVideo({
                    inputPath: result.videoFilePath,
                    outputPath: outputPath,
                    width: 960,
                    height: 540,
                    bitrate: 1048576 * 2
                });
            } catch (error) {
                console.error('Error re-encoding video:', error);
                hideProgressBar();
                showNotification('Re-encoding failed: ' + error.message, 'error');
            }
    
            
            // Change button to green (ready to record)
            button.classList.remove('red');
            isRecording = false;
            
        } else {
            // Start recording
            console.log('Starting video recording...');
            await CameraPreview.startRecordVideo({ 
                storeToFile: true,
                disableAudio: false,
                quality: 85
            });
            
            // Change button to red (recording)
            button.classList.add('red');
            isRecording = true;
            
            // Show recording indicator
            showNotification('Recording...', 'recording');
        }
    } catch (error) {
        console.error('Error toggling video recording:', error);
        showNotification('Recording error: ' + error.message, 'error');
        
        // Reset state on error
        button.classList.remove('red');
        isRecording = false;
        
        // Hide progress bar if it was shown
        hideProgressBar();
    }
};

// Function to show notifications
function showNotification(message, type = 'info') {
    // Remove any existing notification
    const existingNotification = document.getElementById('notification');
    if (existingNotification) {
        existingNotification.remove();
    }
    
    // Create notification element
    const notification = document.createElement('div');
    notification.id = 'notification';
    notification.textContent = message;
    
    // Style based on type
    const baseStyle = `
        position: fixed;
        top: 170px;
        left: 50%;
        transform: translateX(-50%);
        padding: 15px 25px;
        border-radius: 25px;
        font-weight: bold;
        z-index: 1000;
        animation: slideDown 0.3s ease;
        box-shadow: 0 5px 15px rgba(0, 0, 0, 0.3);
        color: white;
        font-size: 16px;
    `;
    
    switch (type) {
        case 'recording':
            notification.style.cssText = baseStyle + 'background: #ff4444; animation: pulse 1s infinite;';
            break;
        case 'success':
            notification.style.cssText = baseStyle + 'background: #00ff44;';
            break;
        case 'error':
            notification.style.cssText = baseStyle + 'background: #ff0000;';
            break;
        default:
            notification.style.cssText = baseStyle + 'background: #4444ff;';
    }
    
    document.body.appendChild(notification);
    
    // Auto-remove notification after 3 seconds (except for recording)
    if (type !== 'recording') {
        setTimeout(() => {
            if (notification && notification.parentNode) {
                notification.style.animation = 'slideUp 0.3s ease';
                setTimeout(() => notification.remove(), 300);
            }
        }, 3000);
    }
}

// Function to add funky effects to the camera preview
function addFunkyEffects() {
    const cameraContainer = document.getElementById('cameraContainer');
    
    // Add a subtle pulsing border effect
    cameraContainer.style.animation = 'funkyPulse 3s ease-in-out infinite';
    
    // Create CSS for the funky animation
    const style = document.createElement('style');
    style.textContent = `
        @keyframes funkyPulse {
            0% { box-shadow: inset 0 0 20px rgba(255, 0, 255, 0.3); }
            50% { box-shadow: inset 0 0 40px rgba(0, 255, 255, 0.3); }
            100% { box-shadow: inset 0 0 20px rgba(255, 0, 255, 0.3); }
        }
        
        .camera-container::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(45deg, transparent 48%, rgba(255, 255, 255, 0.1) 49%, rgba(255, 255, 255, 0.1) 51%, transparent 52%);
            animation: funkySlide 5s linear infinite;
            pointer-events: none;
            z-index: 50;
        }
        
        @keyframes funkySlide {
            0% { transform: translateX(-100%); }
            100% { transform: translateX(100%); }
        }
    `;
    
    if (!document.querySelector('#funkyStyles')) {
        style.id = 'funkyStyles';
        document.head.appendChild(style);
    }
}

// Function to stop camera preview (optional, for testing)
window.stopCamera = async () => {
    try {
        if (cameraStarted) {
            // Stop recording if in progress
            if (isRecording) {
                try {
                    const res = await CameraPreview.stopRecordVideo();
                    console.log('Video saved to:', res.videoFilePath);
                    isRecording = false;
                } catch (recordError) {
                    console.error('Error stopping recording:', recordError);
                }
            }
            
            await CameraPreview.stop();
            cameraStarted = false;
            
            // Show main container and hide camera container
            document.getElementById('mainContainer').classList.remove('hidden');
            document.getElementById('cameraContainer').style.display = 'none';
            
            // Restore body background
            document.body.classList.remove('camera-active');
            
            // Reset button state
            const button = document.getElementById('controlButton');
            button.classList.remove('red');
            
            // Clear any notifications
            const notification = document.getElementById('notification');
            if (notification) {
                notification.remove();
            }
            
            // Hide progress bar
            hideProgressBar();
            
            console.log('Camera preview stopped');
        }
    } catch (error) {
        console.error('Error stopping camera preview:', error);
    }
};

// Handle device back button (Android)
document.addEventListener('deviceready', () => {
    document.addEventListener('backbutton', () => {
        if (cameraStarted) {
            stopCamera();
        }
    }, false);
});

// Keep the original echo function for testing
window.testEcho = () => {
    const inputValue = document.getElementById("echoInput")?.value || "Hello from Camera App!";
    CapacitorFFmpeg.echo({ value: inputValue });
};

console.log('Camera Preview App loaded successfully!');
