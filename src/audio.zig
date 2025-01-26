const std = @import("std");
const ray = @import("raylib.zig");

/// Copied from Raylib example: https://github.com/raysan5/raylib/blob/5.5/examples/audio/audio_raw_stream.c
const max_samples = 512;
const max_samples_per_update = 4096;
const frequency: f32 = 440;
var sine_idx: f32 = 0;

fn audioInputCallback(buffer: ?*anyopaque, frames: c_uint) callconv(.C) void {
    const incr: f32 = frequency / 44100.0;

    var d: [*c]c_short = @as([*c]c_short, @ptrCast(@alignCast(buffer)));

    for (0..frames) |i| {
        d[i] = @as(c_short, @intFromFloat(32000.0 * std.math.sin(2 * std.math.pi * sine_idx)));
        sine_idx += incr;
        if (sine_idx > 1) {
            sine_idx -= 1;
        }
    }
}

pub fn initAudio() ray.AudioStream {
    ray.InitAudioDevice();

    ray.SetAudioStreamBufferSizeDefault(max_samples_per_update);

    // Init raw audio stream (sample rate: 44100, sample size: 16bit-short, channels: 1-mono)
    const stream = ray.LoadAudioStream(44100, 16, 1);

    ray.SetAudioStreamCallback(stream, audioInputCallback);
    ray.PlayAudioStream(stream);
    ray.PauseAudioStream(stream);

    return stream;
}

pub fn deinitAudio(stream: ray.AudioStream) void {
    ray.UnloadAudioStream(stream);

    ray.CloseAudioDevice();
}

pub fn playAudio(stream: ray.AudioStream) void {
    if (!ray.IsAudioStreamPlaying(stream))
        ray.ResumeAudioStream(stream);
}

pub fn pauseAudio(stream: ray.AudioStream) void {
    if (ray.IsAudioStreamPlaying(stream))
        ray.PauseAudioStream(stream);
}
