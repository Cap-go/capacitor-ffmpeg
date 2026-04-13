package ee.forgr.capacitor_ffmpeg;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Build;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.URI;
import java.util.Locale;

@CapacitorPlugin(name = "CapacitorFFmpeg")
public class CapacitorFFmpegPlugin extends Plugin {

    @PluginMethod
    public void getCapabilities(final PluginCall call) {
        try {
            call.resolve(createCapabilitiesPayload());
        } catch (final Exception e) {
            call.reject("Could not describe plugin capabilities", e);
        }
    }

    @PluginMethod
    public void reencodeVideo(final PluginCall call) {
        call.unimplemented(getUnsupportedOperationMessage("reencodeVideo"));
    }

    @PluginMethod
    public void convertImage(final PluginCall call) {
        final String inputPath = call.getString("inputPath");
        final String outputPath = call.getString("outputPath");
        final String format = call.getString("format");
        final Double quality = call.getDouble("quality");

        try {
            final File inputFile = resolveFilesystemPath(inputPath);
            final File outputFile = resolveFilesystemPath(outputPath);
            final String normalizedFormat = normalizeImageFormat(format);
            final int compressionQuality = resolveImageQuality(quality);
            final Bitmap.CompressFormat compressFormat = resolveCompressFormat(normalizedFormat);

            if (!inputFile.isFile()) {
                call.reject("Input image not found: " + inputFile.getAbsolutePath(), "INVALID_ARGUMENT");
                return;
            }

            if (inputFile.getCanonicalFile().equals(outputFile.getCanonicalFile())) {
                call.reject("In-place conversion is not allowed. Choose a different output path.", "INVALID_ARGUMENT");
                return;
            }

            final Bitmap bitmap = BitmapFactory.decodeFile(inputFile.getAbsolutePath());
            if (bitmap == null) {
                call.reject("Could not decode the input image.", "INVALID_ARGUMENT");
                return;
            }

            try {
                final File outputDirectory = outputFile.getParentFile();
                if (outputDirectory != null && !outputDirectory.exists() && !outputDirectory.mkdirs()) {
                    throw new IOException("Could not create output directory.");
                }

                try (FileOutputStream outputStream = new FileOutputStream(outputFile, false)) {
                    final boolean compressed = bitmap.compress(compressFormat, compressionQuality, outputStream);
                    if (!compressed) {
                        call.reject("Could not encode the output image.", "TRANSCODE_FAILED");
                        return;
                    }
                }
            } finally {
                bitmap.recycle();
            }

            final JSObject ret = new JSObject();
            ret.put("outputPath", Uri.fromFile(outputFile).toString());
            ret.put("format", normalizedFormat);
            call.resolve(ret);
        } catch (final IllegalArgumentException e) {
            call.reject(e.getMessage(), "INVALID_ARGUMENT", e);
        } catch (final IOException e) {
            call.reject("Could not convert image", "TRANSCODE_FAILED", e);
        }
    }

    @PluginMethod
    public void convertAudio(final PluginCall call) {
        call.unimplemented(getUnsupportedOperationMessage("convertAudio"));
    }

    @PluginMethod
    public void getPluginVersion(final PluginCall call) {
        try {
            call.resolve(createVersionPayload());
        } catch (final Exception e) {
            call.reject("Could not get plugin version", e);
        }
    }

    JSObject createVersionPayload() {
        final JSObject ret = new JSObject();
        ret.put("version", getPluginVersionValue());
        return ret;
    }

    JSObject createCapabilitiesPayload() {
        final JSObject ret = new JSObject();
        ret.put("platform", getPlatformName());
        ret.put("features", createCapabilitiesFeaturesPayload());
        return ret;
    }

    JSObject createCapabilitiesFeaturesPayload() {
        final JSObject features = new JSObject();
        features.put("getPluginVersion", createCapabilityPayload("getPluginVersion"));
        features.put("getCapabilities", createCapabilityPayload("getCapabilities"));
        features.put("reencodeVideo", createCapabilityPayload("reencodeVideo"));
        features.put("convertImage", createCapabilityPayload("convertImage"));
        features.put("convertAudio", createCapabilityPayload("convertAudio"));
        features.put("progressEvents", createCapabilityPayload("progressEvents"));
        features.put("probeMedia", createCapabilityPayload("probeMedia"));
        features.put("generateThumbnail", createCapabilityPayload("generateThumbnail"));
        features.put("extractAudio", createCapabilityPayload("extractAudio"));
        features.put("remux", createCapabilityPayload("remux"));
        features.put("trim", createCapabilityPayload("trim"));
        return features;
    }

    JSObject createCapabilityPayload(final String feature) {
        final JSObject ret = new JSObject();
        ret.put("status", getCapabilityStatus(feature));
        final String reason = getCapabilityReason(feature);
        if (reason != null) {
            ret.put("reason", reason);
        }
        return ret;
    }

    String getPluginVersionValue() {
        return BuildConfig.CAPACITOR_FFMPEG_PLUGIN_VERSION;
    }

    String getPlatformName() {
        return "android";
    }

    String getCapabilityStatus(final String feature) {
        return switch (feature) {
            case "getPluginVersion", "getCapabilities" -> "available";
            case "reencodeVideo" -> "unimplemented";
            case "convertImage" -> "available";
            case "convertAudio" -> "unimplemented";
            case "progressEvents" -> "unavailable";
            case "probeMedia", "generateThumbnail", "extractAudio", "remux", "trim" -> "unimplemented";
            default -> "unimplemented";
        };
    }

    String getCapabilityReason(final String feature) {
        return switch (feature) {
            case "reencodeVideo" -> getUnsupportedOperationMessage("reencodeVideo");
            case "convertImage" -> "Still-image conversion is available on Android for webp, jpeg, and png outputs.";
            case "convertAudio" -> getUnsupportedOperationMessage("convertAudio");
            case "progressEvents" -> "No media jobs are available on Android today.";
            case "probeMedia" -> "probeMedia is not implemented on Android.";
            case "generateThumbnail" -> "generateThumbnail is not implemented on Android.";
            case "extractAudio" -> "extractAudio is not implemented on Android.";
            case "remux" -> "remux is not implemented on Android.";
            case "trim" -> "trim is not implemented on Android.";
            default -> null;
        };
    }

    String getUnsupportedOperationMessage(final String operation) {
        return operation + " is currently only available on iOS.";
    }

    File resolveFilesystemPath(final String rawPath) {
        if (rawPath == null || rawPath.trim().isEmpty()) {
            throw new IllegalArgumentException("A file path is required.");
        }

        final String trimmedPath = rawPath.trim();
        if (trimmedPath.startsWith("file://")) {
            try {
                final URI uri = URI.create(trimmedPath);
                if (uri.getPath() != null && !uri.getPath().isEmpty()) {
                    return new File(uri.getPath());
                }
            } catch (final IllegalArgumentException ignored) {
                // Fall back to treating malformed file:// inputs as raw file paths.
            }
        }

        return new File(trimmedPath);
    }

    String normalizeImageFormat(final String rawFormat) {
        if (rawFormat == null || rawFormat.trim().isEmpty()) {
            throw new IllegalArgumentException("An output image format is required.");
        }

        return switch (rawFormat.trim().toLowerCase(Locale.ROOT)) {
            case "jpg", "jpeg" -> "jpeg";
            case "png" -> "png";
            case "webp" -> "webp";
            default -> throw new IllegalArgumentException("Unsupported image format: " + rawFormat);
        };
    }

    int resolveImageQuality(final Double rawQuality) {
        if (rawQuality == null) {
            return 85;
        }

        if (rawQuality < 0.0 || rawQuality > 1.0) {
            throw new IllegalArgumentException("Image quality must be between 0.0 and 1.0.");
        }

        return (int) Math.round(rawQuality * 100.0);
    }

    Bitmap.CompressFormat resolveCompressFormat(final String normalizedFormat) {
        return switch (normalizedFormat) {
            case "jpeg" -> Bitmap.CompressFormat.JPEG;
            case "png" -> Bitmap.CompressFormat.PNG;
            case "webp" -> Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ? Bitmap.CompressFormat.WEBP_LOSSY : Bitmap.CompressFormat.WEBP;
            default -> throw new IllegalArgumentException("Unsupported image format: " + normalizedFormat);
        };
    }
}
