use anyhow::{Result, Context, bail};
use ffmpeg_next::format;
use ffmpeg_next::media;
use ffmpeg_next::{codec, decoder, encoder, frame, picture, Dictionary, Packet, Rational};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;
use tokio::runtime::{Builder, Runtime};

// Bitrate constants (in bits per second)
const MIN_BITRATE: u64 = 100_000;      // 100 Kbps minimum
const MAX_BITRATE: u64 = 100_000_000;  // 100 Mbps maximum  
const DEFAULT_BITRATE: u64 = 1_000_000; // 1 Mbps default

pub struct CapacitorFFmpegPlugin {
    inform_about_progress: Arc<Box<dyn Fn(f64, String) -> Result<(), anyhow::Error> + Send + Sync>>,
    runtime: Runtime,
}

impl CapacitorFFmpegPlugin {
    pub fn new(inform_about_progress: Box<dyn Fn(f64, String) -> Result<(), anyhow::Error> + Send + Sync>) -> Result<Self, anyhow::Error> {
        let runtime = Builder::new_multi_thread()
            .worker_threads(2) // 2 threads for now, but perhaps we will do more later
            .thread_name("ffmpeg-worker")
            .build()?;
        
        Ok(Self { 
            inform_about_progress: Arc::new(inform_about_progress),
            runtime,
        })
    }

    pub fn destroy(&mut self) {
        // TODO: Implement
    }

    /// Validates and converts bitrate to a safe usize value
    /// 
    /// # Arguments
    /// 
    /// * `bitrate` - Optional bitrate in bits per second
    /// 
    /// # Returns
    /// 
    /// Result containing validated bitrate as usize, or error if invalid
    fn validate_bitrate(bitrate: Option<u64>) -> Result<usize> {
        let bitrate = bitrate.unwrap_or(DEFAULT_BITRATE);
        
        if bitrate < MIN_BITRATE {
            bail!("Bitrate {} is too low. Minimum is {} bps", bitrate, MIN_BITRATE);
        }
        
        if bitrate > MAX_BITRATE {
            bail!("Bitrate {} is too high. Maximum is {} bps", bitrate, MAX_BITRATE);
        }
        
        // Safe conversion from u64 to usize
        bitrate.try_into()
            .with_context(|| format!("Bitrate {} cannot be converted to usize on this platform", bitrate))
    }

    /// Re-encode a video file to a lower resolution
    /// 
    /// # Arguments
    /// 
    /// * `input_path` - Path to the input video file
    /// * `output_path` - Path to save the re-encoded video
    /// * `target_width` - Target width for the output video
    /// * `target_height` - Target height for the output video
    /// * `bitrate` - Target bitrate in bits per second (optional, defaults to 1Mbps)
    /// 
    /// # Returns
    /// 
    /// Result indicating success or error
    pub fn reencode_video(
        &self,
        input_path: &String,
        output_path: &String,
        target_width: u32,
        target_height: u32,
        bitrate: Option<u64>
    ) -> Result<(), anyhow::Error> {
        // Validate bitrate early
        let validated_bitrate = Self::validate_bitrate(bitrate)
            .context("Invalid bitrate specified")?;
        
        let input_file = if input_path.starts_with("file://") {
            input_path.replace("file://", "")
        } else {
            input_path.to_string()
        };
        let output_file = if output_path.starts_with("file://") {
            output_path.replace("file://", "")
        } else {
            output_path.to_string()
        };
    
        ffmpeg_next::init()?;

        let inform_about_progress = self.inform_about_progress.clone();
        self.runtime.spawn_blocking(move || {
            let result: Result<(), anyhow::Error> = (|| {
                let mut x264_opts = Dictionary::new();
                x264_opts.set("preset", "medium");

                let mut ictx = format::input(&input_file)
                    .with_context(|| format!("Failed to open input file: {}", input_file))?;
                let mut octx = format::output(&output_file)
                    .with_context(|| format!("Failed to create output file: {}", output_file))?;

                format::context::input::dump(&ictx, 0, Some(&input_file));

                let best_video_stream_index = ictx
                    .streams()
                    .best(media::Type::Video)
                    .map(|stream| stream.index());
                let mut stream_mapping: Vec<isize> = vec![0; ictx.nb_streams() as _];
                let mut ist_time_bases = vec![Rational(0, 0); ictx.nb_streams() as _];
                let mut ost_time_bases = vec![Rational(0, 0); ictx.nb_streams() as _];
                let mut transcoders = HashMap::new();
                let mut ost_index = 0;
                for (ist_index, ist) in ictx.streams().enumerate() {
                    let ist_medium = ist.parameters().medium();
                    if ist_medium != media::Type::Audio
                        && ist_medium != media::Type::Video
                        && ist_medium != media::Type::Subtitle
                    {
                        stream_mapping[ist_index] = -1;
                        continue;
                    }
                    stream_mapping[ist_index] = ost_index;
                    ist_time_bases[ist_index] = ist.time_base();
                    if ist_medium == media::Type::Video {
                        // Initialize transcoder for video stream.
                        transcoders.insert(
                            ist_index,
                            Transcoder::new(
                                &ist,
                                &mut octx,
                                ost_index as _,
                                x264_opts.clone(),
                                Some(ist_index) == best_video_stream_index,
                                target_width,
                                target_height,
                                validated_bitrate,
                                inform_about_progress.clone(),
                            )
                            .with_context(|| format!("Failed to create transcoder for stream {}", ist_index))?,
                        );
                    } else {
                        // Set up for stream copy for non-video stream.
                        let mut ost = octx.add_stream(encoder::find(codec::Id::None))
                            .with_context(|| format!("Failed to add stream for copying stream {}", ist_index))?;
                        ost.set_parameters(ist.parameters());
                        // We need to set codec_tag to 0 lest we run into incompatible codec tag
                        // issues when muxing into a different container format. Unfortunately
                        // there's no high level API to do this (yet).
                        unsafe {
                            (*ost.parameters().as_mut_ptr()).codec_tag = 0;
                        }
                    }
                    ost_index += 1;
                }

                octx.set_metadata(ictx.metadata().to_owned());
                format::context::output::dump(&octx, 0, Some(&output_file));
                octx.write_header()
                    .context("Failed to write output file header")?;

                for (ost_index, _) in octx.streams().enumerate() {
                    ost_time_bases[ost_index] = octx.stream(ost_index as _)
                        .with_context(|| format!("Failed to get stream {}", ost_index))?
                        .time_base();
                }
                for (stream, mut packet) in ictx.packets() {
                    let ist_index = stream.index();
                    let ost_index = stream_mapping[ist_index];
                    if ost_index < 0 {
                        continue;
                    }
                    let ost_time_base = ost_time_bases[ost_index as usize];
                    match transcoders.get_mut(&ist_index) {
                        Some(transcoder) => {
                            transcoder.send_packet_to_decoder(&packet)?;
                            transcoder.receive_and_process_decoded_frames(&mut octx, ost_time_base)?;
                        }
                        None => {
                            // Do stream copy on non-video streams.
                            packet.rescale_ts(ist_time_bases[ist_index], ost_time_base);
                            packet.set_position(-1);
                            packet.set_stream(ost_index as _);
                            packet.write_interleaved(&mut octx)
                                .context("Failed to write packet to output")?;
                        }
                    }
                }

                // Flush encoders and decoders.
                for (ost_index, transcoder) in transcoders.iter_mut() {
                    let ost_time_base = ost_time_bases[*ost_index];
                    transcoder.send_eof_to_decoder()?;
                    transcoder.receive_and_process_decoded_frames(&mut octx, ost_time_base)?;
                    transcoder.send_eof_to_encoder()?;
                    transcoder.receive_and_process_encoded_packets(&mut octx, ost_time_base)?;
                }

                octx.write_trailer()
                    .context("Failed to write output file trailer")?;
                
                Ok(())
            })();

            // Handle the result - you can log errors, call a callback, etc.
            if let Err(e) = result {
                eprintln!("Error during video encoding: {:?}", e);
                // You could also call a callback to inform about the error
                // if let Err(callback_err) = inform_about_progress(0.0, format!("Error: {}", e)) {
                //     eprintln!("Failed to report error: {:?}", callback_err);
                // }
            }
        });
    
        Ok(())
    }
}

// Given an input file, transcode all video streams into H.264 (using libx264)
// while copying audio and subtitle streams.
//
// Invocation:
//
//   transcode-x264 <input> <output> [<x264_opts>]
//
// <x264_opts> is a comma-delimited list of key=val. default is "preset=medium".
// See https://ffmpeg.org/ffmpeg-codecs.html#libx264_002c-libx264rgb and
// https://trac.ffmpeg.org/wiki/Encode/H.264 for available and commonly used
// options.
//
// Examples:
//
//   transcode-x264 input.flv output.mp4
//   transcode-x264 input.mkv output.mkv 'preset=veryslow,crf=18'



struct Transcoder {
    ost_index: usize,
    decoder: decoder::Video,
    input_time_base: Rational,
    encoder: encoder::Video,
    frame_count: usize,
    starting_time: Instant,
    frames: i64,
    should_inform_about_progress: bool,
    inform_about_progress: Arc<Box<dyn Fn(f64, String) -> Result<(), anyhow::Error> + Send + Sync>>,
}

impl Transcoder {
    fn new(
        ist: &format::stream::Stream,
        octx: &mut format::context::Output,
        ost_index: usize,
        x264_opts: Dictionary,
        should_inform_about_progress: bool,
        target_width: u32,
        target_height: u32,
        bitrate: usize,
        inform_about_progress: Arc<Box<dyn Fn(f64, String) -> Result<(), anyhow::Error> + Send + Sync>>,
    ) -> Result<Self, ffmpeg_next::Error> {
        let global_header = octx.format().flags().contains(format::Flags::GLOBAL_HEADER);
        let decoder = ffmpeg_next::codec::context::Context::from_parameters(ist.parameters())?
            .decoder()
            .video()?;

        let frames = ist.frames();
        let codec = encoder::find(codec::Id::H264);
        let mut ost = octx.add_stream(codec)?;

        let mut encoder =
            codec::context::Context::new_with_codec(codec.ok_or(ffmpeg_next::Error::InvalidData)?)
                .encoder()
                .video()?;
        ost.set_parameters(&encoder);
        
        // Use target dimensions instead of original dimensions
        encoder.set_height(target_height);
        encoder.set_width(target_width);
        encoder.set_aspect_ratio(decoder.aspect_ratio());
        encoder.set_format(decoder.format());
        encoder.set_frame_rate(decoder.frame_rate());
        encoder.set_time_base(ist.time_base());
        
        // Set validated bitrate
        encoder.set_bit_rate(bitrate);

        if global_header {
            encoder.set_flags(codec::Flags::GLOBAL_HEADER);
        }

        let opened_encoder = encoder
            .open_with(x264_opts)?;
        ost.set_parameters(&opened_encoder);
        Ok(Self {
            ost_index,
            decoder,
            input_time_base: ist.time_base(),
            encoder: opened_encoder,
            frame_count: 0,
            starting_time: Instant::now(),
            frames,
            should_inform_about_progress,
            inform_about_progress,
        })
    }

    fn send_packet_to_decoder(&mut self, packet: &Packet) -> Result<()> {
        self.decoder.send_packet(packet)
            .context("Failed to send packet to decoder")?;
        Ok(())
    }

    fn send_eof_to_decoder(&mut self) -> Result<()> {
        self.decoder.send_eof()
            .context("Failed to send EOF to decoder")?;
        Ok(())
    }

    fn receive_and_process_decoded_frames(
        &mut self,
        octx: &mut format::context::Output,
        ost_time_base: Rational,
    ) -> Result<()> {
        let mut frame = frame::Video::empty();
        while self.decoder.receive_frame(&mut frame).is_ok() {
            self.frame_count += 1;

            let timestamp = frame.timestamp();
            let inform_about_progress = self.inform_about_progress.clone();
            let input_time_base = self.input_time_base.clone();
            let starting_time = self.starting_time.clone();
            let frame_count = self.frame_count.clone();
            let frames = self.frames.clone();

            if (self.should_inform_about_progress) {
                
                tokio::spawn(async move {
                    let timestamp = Rational(timestamp.unwrap_or(0) as i32, 1) * input_time_base;
                    eprintln!(
                        "time elpased: \t{:8.2}\tframe count: {:8}\ttimestamp: {:8.2}",
                        starting_time.elapsed().as_secs_f64(),
                        frame_count,
                        timestamp
                    );
                    let progress = frame_count as f64 / frames as f64;
            
                    match inform_about_progress.as_ref()(progress, "Abc123".to_string()) {
                        Ok(_) => (),
                        Err(e) => eprintln!("Error informing about progress: {:?}", e),
                    }
                });
            }


            frame.set_pts(timestamp);
            frame.set_kind(picture::Type::None);
            self.send_frame_to_encoder(&frame)?;
            self.receive_and_process_encoded_packets(octx, ost_time_base)?;
        }
        Ok(())
    }

    fn send_frame_to_encoder(&mut self, frame: &frame::Video) -> Result<()> {
        self.encoder.send_frame(frame)
            .context("Failed to send frame to encoder")?;
        Ok(())
    }

    fn send_eof_to_encoder(&mut self) -> Result<()> {
        self.encoder.send_eof()
            .context("Failed to send EOF to encoder")?;
        Ok(())
    }

    fn receive_and_process_encoded_packets(
        &mut self,
        octx: &mut format::context::Output,
        ost_time_base: Rational,
    ) -> Result<()> {
        let mut encoded = Packet::empty();
        while self.encoder.receive_packet(&mut encoded).is_ok() {
            encoded.set_stream(self.ost_index);
            encoded.rescale_ts(self.input_time_base, ost_time_base);
            encoded.write_interleaved(octx)
                .context("Failed to write encoded packet")?;
        }
        Ok(())
    }

    async fn log_progress(&mut self, timestamp: f64) {
        if !self.should_inform_about_progress {
            return;
        }
        eprintln!(
            "time elpased: \t{:8.2}\tframe count: {:8}\ttimestamp: {:8.2}",
            self.starting_time.elapsed().as_secs_f64(),
            self.frame_count,
            timestamp
        );
        let progress = self.frame_count as f64 / self.frames as f64;

        match self.inform_about_progress.as_ref()(progress, "Abc123".to_string()) {
            Ok(_) => (),
            Err(e) => eprintln!("Error informing about progress: {:?}", e),
        }
    }
}
