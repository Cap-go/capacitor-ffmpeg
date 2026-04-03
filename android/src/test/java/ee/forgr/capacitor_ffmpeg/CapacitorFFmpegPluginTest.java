package ee.forgr.capacitor_ffmpeg;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;

import com.getcapacitor.annotation.CapacitorPlugin;
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
        assertEquals("reencodeVideo is currently only available on iOS.", plugin.getCapabilityReason("reencodeVideo"));
    }
}
