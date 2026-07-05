/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 RHH-Ports contributors
 *
 * wav-normalize: normalize PCM16 WAV to target dBFS, mono, 44.1kHz.
 * Usage: wav-normalize <target_dbfs> <in.wav> <out.wav>
 *
 * Origins SFX are stereo 48kHz and mastered ~8dB below mobile levels.
 * RSDKv4 S1 was built for mobile's mono 44.1kHz and the mixer's sample
 * advance assumes mono frames — stereo SFX cause a segfault downstream.
 * This tool:
 *   1. Downmixes stereo -> mono (average both channels)
 *   2. Resamples to 44100 Hz (linear interpolation)
 *   3. Peak-normalizes to target_dbfs
 *   4. Writes a clean PCM16 WAV with fmt + data only
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#define OUT_RATE 44100

static uint32_t rd32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static uint16_t rd16(const uint8_t *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}
static void wr16(uint8_t *p, uint16_t v) {
    p[0] = v & 0xff; p[1] = (v >> 8) & 0xff;
}
static void wr32(uint8_t *p, uint32_t v) {
    p[0] = v & 0xff; p[1] = (v >> 8) & 0xff; p[2] = (v >> 16) & 0xff; p[3] = (v >> 24) & 0xff;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "usage: %s <target_dbfs> <in.wav> <out.wav>\n", argv[0]);
        return 1;
    }
    double target_db = atof(argv[1]);
    const char *in_path = argv[2];
    const char *out_path = argv[3];

    FILE *f = fopen(in_path, "rb");
    if (!f) { perror(in_path); return 1; }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *buf = malloc(size);
    if (!buf) { fprintf(stderr, "oom\n"); return 1; }
    if (fread(buf, 1, size, f) != (size_t)size) { fprintf(stderr, "read fail\n"); return 1; }
    fclose(f);

    if (size < 44 || memcmp(buf, "RIFF", 4) != 0 || memcmp(buf + 8, "WAVE", 4) != 0) {
        fprintf(stderr, "not a RIFF/WAVE file\n"); return 1;
    }

    long off = 12;
    long data_off = -1;
    uint32_t data_size = 0;
    uint16_t channels = 0, bits = 0;
    uint32_t sample_rate = 0;
    while (off + 8 <= size) {
        const uint8_t *ck = buf + off;
        uint32_t csz = rd32(ck + 4);
        if (memcmp(ck, "fmt ", 4) == 0) {
            channels    = rd16(ck + 8 + 2);
            sample_rate = rd32(ck + 8 + 4);
            bits        = rd16(ck + 8 + 14);
        } else if (memcmp(ck, "data", 4) == 0) {
            data_off = off + 8;
            data_size = csz;
            break;
        }
        off += 8 + csz + (csz & 1);
    }
    if (data_off < 0 || bits != 16 || channels < 1 || channels > 2) {
        fprintf(stderr, "unsupported (need PCM16 mono/stereo)\n"); return 1;
    }

    int16_t *src = (int16_t *)(buf + data_off);
    size_t src_frames = data_size / 2 / channels;

    /* Downmix to mono: average channels into float for precision. */
    float *mono = malloc(src_frames * sizeof(float));
    if (!mono) { fprintf(stderr, "oom\n"); return 1; }
    for (size_t i = 0; i < src_frames; i++) {
        int32_t sum = 0;
        for (int c = 0; c < channels; c++) sum += src[i * channels + c];
        mono[i] = (float)sum / (float)channels;
    }

    /* Resample to OUT_RATE via linear interpolation. */
    size_t out_frames;
    float *resamp;
    if (sample_rate == OUT_RATE) {
        out_frames = src_frames;
        resamp = mono;   /* keep pointer; don't free mono */
    } else {
        double ratio = (double)OUT_RATE / (double)sample_rate;
        out_frames = (size_t)((double)src_frames * ratio);
        resamp = malloc(out_frames * sizeof(float));
        if (!resamp) { fprintf(stderr, "oom\n"); return 1; }
        double inv_ratio = 1.0 / ratio;
        for (size_t i = 0; i < out_frames; i++) {
            double src_pos = (double)i * inv_ratio;
            size_t i0 = (size_t)src_pos;
            size_t i1 = i0 + 1;
            if (i1 >= src_frames) i1 = src_frames - 1;
            double frac = src_pos - (double)i0;
            resamp[i] = (float)(mono[i0] * (1.0 - frac) + mono[i1] * frac);
        }
        free(mono);
    }

    /* Find peak. */
    double peak = 1.0;
    for (size_t i = 0; i < out_frames; i++) {
        double v = fabs(resamp[i]);
        if (v > peak) peak = v;
    }

    /* Compute gain to target dBFS. */
    double target_lin = pow(10.0, target_db / 20.0) * 32767.0;
    double gain = target_lin / peak;

    /* Apply gain + clamp + quantize to int16. */
    int16_t *out = malloc(out_frames * sizeof(int16_t));
    if (!out) { fprintf(stderr, "oom\n"); return 1; }
    for (size_t i = 0; i < out_frames; i++) {
        double v = resamp[i] * gain;
        if (v > 32767.0) v = 32767.0;
        if (v < -32768.0) v = -32768.0;
        out[i] = (int16_t)lrint(v);
    }
    free(resamp);

    /* Write minimal RIFF/WAVE with PCM16 mono 44.1kHz. */
    uint32_t out_data_bytes = (uint32_t)(out_frames * sizeof(int16_t));
    uint32_t riff_size = 36 + out_data_bytes;
    uint8_t hdr[44];
    memcpy(hdr, "RIFF", 4);       wr32(hdr + 4, riff_size);
    memcpy(hdr + 8, "WAVE", 4);
    memcpy(hdr + 12, "fmt ", 4);  wr32(hdr + 16, 16);
    wr16(hdr + 20, 1);            /* PCM */
    wr16(hdr + 22, 1);            /* mono */
    wr32(hdr + 24, OUT_RATE);
    wr32(hdr + 28, OUT_RATE * 2); /* byte rate = rate * channels * bytes/sample */
    wr16(hdr + 32, 2);            /* block align */
    wr16(hdr + 34, 16);           /* bits */
    memcpy(hdr + 36, "data", 4);  wr32(hdr + 40, out_data_bytes);

    FILE *o = fopen(out_path, "wb");
    if (!o) { perror(out_path); return 1; }
    if (fwrite(hdr, 1, 44, o) != 44 ||
        fwrite(out, 1, out_data_bytes, o) != out_data_bytes) {
        fprintf(stderr, "write fail\n"); return 1;
    }
    fclose(o);
    free(buf);
    free(out);
    return 0;
}
