package ee.forgr.capacitor_ffmpeg;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.File;
import org.junit.Test;

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

        assertEquals(CapacitorFFmpegPluginContract.PLUGIN_VERSION, plugin.getPluginVersionValue());
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
        assertEquals("reencodeVideo is currently only available on iOS.", plugin.getCapabilityReason("reencodeVideo"));
        assertEquals(
            "Still-image conversion is available on Android for webp, jpeg, and png outputs.",
            plugin.getCapabilityReason("convertImage")
        );
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

        assertEquals("/tmp/input.png", rawPath.getPath());
        assertEquals("/tmp/output.webp", fileUriPath.getPath());
    }
}
