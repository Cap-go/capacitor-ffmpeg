package ee.forgr.capacitor_ffmpeg;

import com.arthenica.ffmpegkit.FFmpegKit;
import com.arthenica.ffmpegkit.FFmpegSession;
import com.arthenica.ffmpegkit.ReturnCode;
import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

final class AndroidAudioConverter {

    private static final Map<String, String> FORMAT_TO_CODEC = Map.of(
        "m4a",
        "aac",
        "mp3",
        "libmp3lame",
        "wav",
        "pcm_s16le",
        "ogg",
        "libvorbis",
        "aac",
        "aac",
        "flac",
        "flac"
    );

    ConvertedAudio convert(final File inputFile, final File outputFile, final String format, final Integer bitrate)
        throws IllegalArgumentException, IllegalStateException {
        final String normalizedFormat = normalizeAudioFormat(format);
        final String codec = FORMAT_TO_CODEC.get(normalizedFormat);
        if (codec == null) {
            throw new IllegalArgumentException("Unsupported audio format: " + format);
        }

        final String extension = outputFile.getName();
        final int dotIndex = extension.lastIndexOf('.');
        if (dotIndex < 0 || !extension.substring(dotIndex + 1).equalsIgnoreCase(normalizedFormat)) {
            throw new IllegalArgumentException("Output path extension must be ." + normalizedFormat + ".");
        }

        final List<String> arguments = new ArrayList<>();
        arguments.add("-y");
        arguments.add("-i");
        arguments.add(inputFile.getAbsolutePath());
        arguments.add("-vn");
        arguments.add("-c:a");
        arguments.add(codec);

        if (bitrate != null && bitrate > 0 && !"wav".equals(normalizedFormat) && !"flac".equals(normalizedFormat)) {
            arguments.add("-b:a");
            arguments.add(String.valueOf(bitrate));
        }

        if ("m4a".equals(normalizedFormat)) {
            arguments.add("-movflags");
            arguments.add("+faststart");
        }

        arguments.add(outputFile.getAbsolutePath());

        final FFmpegSession session = FFmpegKit.executeWithArguments(arguments.toArray(new String[0]));
        if (!ReturnCode.isSuccess(session.getReturnCode())) {
            final String logs = session.getAllLogsAsString();
            final String message = logs != null && !logs.isBlank() ? logs.trim() : "Could not convert the input audio.";
            throw new IllegalStateException(message);
        }

        if (!outputFile.isFile()) {
            throw new IllegalStateException("Converted audio was not created.");
        }

        return new ConvertedAudio(outputFile.getAbsolutePath(), normalizedFormat);
    }

    String normalizeAudioFormat(final String rawFormat) {
        if (rawFormat == null || rawFormat.trim().isEmpty()) {
            throw new IllegalArgumentException("An output audio format is required.");
        }

        return switch (rawFormat.trim().toLowerCase(Locale.ROOT)) {
            case "m4a" -> "m4a";
            case "mp3" -> "mp3";
            case "wav" -> "wav";
            case "ogg" -> "ogg";
            case "aac" -> "aac";
            case "flac" -> "flac";
            default -> throw new IllegalArgumentException("Unsupported audio format: " + rawFormat);
        };
    }

    static final class ConvertedAudio {

        private final String outputPath;
        private final String format;

        ConvertedAudio(final String outputPath, final String format) {
            this.outputPath = outputPath;
            this.format = format;
        }

        String getOutputPath() {
            return outputPath;
        }

        String getFormat() {
            return format;
        }
    }
}
