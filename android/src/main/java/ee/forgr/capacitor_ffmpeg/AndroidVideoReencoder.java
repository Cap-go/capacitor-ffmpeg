package ee.forgr.capacitor_ffmpeg;

import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.OptIn;
import androidx.media3.common.MediaItem;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.effect.Presentation;
import androidx.media3.transformer.Composition;
import androidx.media3.transformer.DefaultEncoderFactory;
import androidx.media3.transformer.EditedMediaItem;
import androidx.media3.transformer.Effects;
import androidx.media3.transformer.ExportException;
import androidx.media3.transformer.ExportResult;
import androidx.media3.transformer.ProgressHolder;
import androidx.media3.transformer.Transformer;
import androidx.media3.transformer.VideoEncoderSettings;
import java.io.File;
import java.util.Collections;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

@OptIn(markerClass = UnstableApi.class)
final class AndroidVideoReencoder {

    private static final int DEFAULT_BITRATE = 1_000_000;
    private static final long TRANSFORM_TIMEOUT_SECONDS = 600;

    interface ProgressListener {
        void onProgress(double progress, String state, String message);
    }

    void reencode(
        final Context context,
        final File inputFile,
        final File outputFile,
        final int width,
        final int height,
        final int bitrate,
        final ProgressListener listener
    ) throws Exception {
        final Handler mainHandler = new Handler(Looper.getMainLooper());
        final CountDownLatch completionLatch = new CountDownLatch(1);
        final AtomicReference<Exception> failure = new AtomicReference<>();
        final ProgressHolder progressHolder = new ProgressHolder();
        final Runnable[] progressPoller = new Runnable[1];

        mainHandler.post(() -> {
            try {
                final File outputDirectory = outputFile.getParentFile();
                if (outputDirectory != null && !outputDirectory.exists() && !outputDirectory.mkdirs()) {
                    throw new IllegalStateException("Could not create output directory.");
                }

                final Presentation presentation = Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT);
                final Effects effects = new Effects(Collections.emptyList(), Collections.singletonList(presentation));
                final EditedMediaItem editedMediaItem = new EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(inputFile)))
                    .setEffects(effects)
                    .build();

                final DefaultEncoderFactory.Builder encoderFactoryBuilder = new DefaultEncoderFactory.Builder(context);
                if (bitrate > 0) {
                    encoderFactoryBuilder.setRequestedVideoEncoderSettings(new VideoEncoderSettings.Builder().setBitrate(bitrate).build());
                }

                final Transformer transformer = new Transformer.Builder(context)
                    .setVideoMimeType(MimeTypes.VIDEO_H264)
                    .setEncoderFactory(encoderFactoryBuilder.build())
                    .addListener(
                        new Transformer.Listener() {
                            @Override
                            public void onCompleted(final Composition composition, final ExportResult exportResult) {
                                listener.onProgress(1.0, "completed", "Re-encoding completed.");
                                completionLatch.countDown();
                            }

                            @Override
                            public void onError(
                                final Composition composition,
                                final ExportResult exportResult,
                                final ExportException exportException
                            ) {
                                failure.set(
                                    new IllegalStateException(
                                        exportException.getMessage() != null
                                            ? exportException.getMessage()
                                            : "Could not re-encode the input video."
                                    )
                                );
                                listener.onProgress(0.0, "failed", exportException.getMessage());
                                completionLatch.countDown();
                            }
                        }
                    )
                    .build();

                progressPoller[0] = new Runnable() {
                    @Override
                    public void run() {
                        if (completionLatch.getCount() == 0) {
                            return;
                        }

                        final int progressState = transformer.getProgress(progressHolder);
                        if (progressState == Transformer.PROGRESS_STATE_AVAILABLE) {
                            final double normalizedProgress = Math.min(0.99, Math.max(0.0, progressHolder.progress / 100.0));
                            listener.onProgress(normalizedProgress, "running", "Re-encoding video...");
                        }

                        mainHandler.postDelayed(this, 200);
                    }
                };

                listener.onProgress(0.0, "running", "Re-encoding video...");
                mainHandler.post(progressPoller[0]);
                transformer.start(editedMediaItem, outputFile.getAbsolutePath());
            } catch (final Exception exception) {
                failure.set(exception);
                listener.onProgress(0.0, "failed", exception.getMessage());
                completionLatch.countDown();
            }
        });

        if (!completionLatch.await(TRANSFORM_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            mainHandler.post(() -> {
                if (progressPoller[0] != null) {
                    mainHandler.removeCallbacks(progressPoller[0]);
                }
            });
            throw new IllegalStateException("Video re-encoding timed out.");
        }

        mainHandler.post(() -> {
            if (progressPoller[0] != null) {
                mainHandler.removeCallbacks(progressPoller[0]);
            }
        });

        if (failure.get() != null) {
            throw failure.get();
        }

        if (!outputFile.isFile()) {
            throw new IllegalStateException("Re-encoded video was not created.");
        }
    }

    static int resolveBitrate(final Integer rawBitrate) {
        if (rawBitrate == null || rawBitrate <= 0) {
            return DEFAULT_BITRATE;
        }

        return rawBitrate;
    }
}
