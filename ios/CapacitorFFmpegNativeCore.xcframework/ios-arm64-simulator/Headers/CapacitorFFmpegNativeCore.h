#ifndef CAPACITOR_FFMPEG_NATIVE_CORE_H
#define CAPACITOR_FFMPEG_NATIVE_CORE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct CResult {
    bool ok;
    char *error_message;
} CResult;

void *init_ffmpeg_plugin(void);
void deinit_ffmpeg_plugin(void *plugin);
void free_c_result(CResult *result);

CResult *reencode_video(
    void *plugin,
    const char *input_path,
    const char *output_path,
    int32_t target_width,
    int32_t target_height,
    int32_t bitrate,
    void *swift_internal_data_structure_pointer,
    int32_t (*inform_about_progress)(double progress, void *swift_internal_data_structure_pointer)
);

#ifdef __cplusplus
}
#endif

#endif
