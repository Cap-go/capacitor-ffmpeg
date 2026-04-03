package ee.forgr.capacitor_ffmpeg;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

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
        return CapacitorFFmpegPluginContract.PLUGIN_VERSION;
    }

    String getPlatformName() {
        return "android";
    }

    String getCapabilityStatus(final String feature) {
        return switch (feature) {
            case "getPluginVersion", "getCapabilities" -> "available";
            case "reencodeVideo" -> "unimplemented";
            case "progressEvents" -> "unavailable";
            case "probeMedia", "generateThumbnail", "extractAudio", "remux", "trim" -> "unimplemented";
            default -> "unimplemented";
        };
    }

    String getCapabilityReason(final String feature) {
        return switch (feature) {
            case "reencodeVideo" -> getUnsupportedOperationMessage("reencodeVideo");
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
}
