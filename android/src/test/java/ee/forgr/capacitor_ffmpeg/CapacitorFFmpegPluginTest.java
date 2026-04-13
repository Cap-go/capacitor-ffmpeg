package ee.forgr.capacitor_ffmpeg;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

import com.getcapacitor.JSObject;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.File;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
public class CapacitorFFmpegPluginTest {

    @Test
    public void pluginAnnotationMatchesTheSharedContract() {
        final CapacitorPlugin annotation = CapacitorFFmpegPlugin.class.getAnnotation(CapacitorPlugin.class);

        assertNotNull(annotation);
        assertEquals(CapacitorFFmpegPluginContract.PLUGIN_NAME, annotation.name());
    }

    @Test
    public void versionValueUsesTheSharedContractVersion() {
        final CapacitorFFmpegPlugin plugin = new CapacitorFFmpegPlugin();

        assertEquals(BuildConfig.CAPACITOR_FFMPEG_PLUGIN_VERSION, plugin.getPluginVersionValue());
    }

    @Test
    public void unsupportedOperationMessageExplainsTheCurrentPlatformScope() {
        final CapacitorFFmpegPlugin plugin = new CapacitorFFmpegPlugin();

        assertEquals("reencodeVideo is currently only available on iOS.", plugin.getUnsupportedOperationMessage("reencodeVideo"));
    }

    @Test
    public void capabilityHelpersDescribeTheCurrentAndroidScope() {
        final CapacitorFFmpegPlugin plugin = new CapacitorFFmpegPlugin();

        assertEquals("android", plugin.getPlatformName());
        assertEquals("available", plugin.getCapabilityStatus("getCapabilities"));
        assertEquals("unimplemented", plugin.getCapabilityStatus("reencodeVideo"));
        assertEquals("available", plugin.getCapabilityStatus("convertImage"));
        assertEquals("unimplemented", plugin.getCapabilityStatus("convertAudio"));
        assertEquals("reencodeVideo is currently only available on iOS.", plugin.getCapabilityReason("reencodeVideo"));
        assertEquals(
            "Still-image conversion is available on Android for webp, jpeg, and png outputs.",
            plugin.getCapabilityReason("convertImage")
        );
        assertEquals("convertAudio is currently only available on iOS.", plugin.getCapabilityReason("convertAudio"));
    }

    @Test
    public void capabilitiesPayloadExposesTheJsVisibleContract() throws Exception {
        final CapacitorFFmpegPlugin plugin = new CapacitorFFmpegPlugin();
        final JSObject payload = plugin.createCapabilitiesPayload();
        final var features = payload.getJSONObject("features");

        assertEquals("android", payload.getString("platform"));
        assertEquals("available", features.getJSONObject("getCapabilities").getString("status"));
        assertEquals("unimplemented", features.getJSONObject("reencodeVideo").getString("status"));
        assertEquals("reencodeVideo is currently only available on iOS.", features.getJSONObject("reencodeVideo").getString("reason"));
        assertEquals("unimplemented", features.getJSONObject("convertAudio").getString("status"));
        assertEquals("convertAudio is currently only available on iOS.", features.getJSONObject("convertAudio").getString("reason"));
    }

    @Test
    public void imageConversionHelpersNormalizeFormatAndQuality() {
        final CapacitorFFmpegPlugin plugin = new CapacitorFFmpegPlugin();

        assertEquals("jpeg", plugin.normalizeImageFormat("jpg"));
        assertEquals("webp", plugin.normalizeImageFormat("webp"));
        assertEquals(85, plugin.resolveImageQuality(null));
        assertEquals(25, plugin.resolveImageQuality(0.25));
    }

    @Test
    public void filesystemPathResolverAcceptsRawAndFileUris() {
        final CapacitorFFmpegPlugin plugin = new CapacitorFFmpegPlugin();
        final File rawPath = plugin.resolveFilesystemPath("/tmp/input.png");
        final File fileUriPath = plugin.resolveFilesystemPath("file:///tmp/output.webp");
        final File malformedFileUriPath = plugin.resolveFilesystemPath("file://%zz");

        assertEquals("/tmp/input.png", rawPath.getPath());
        assertEquals("/tmp/output.webp", fileUriPath.getPath());
        assertEquals("file:/%zz", malformedFileUriPath.getPath());
    }
}
