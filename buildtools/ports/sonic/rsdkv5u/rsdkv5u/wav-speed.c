/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 RHH-Ports contributors
 *
 * wav-speed: tempo-change a PCM16 WAV without pitch shift.
 * Usage: wav-speed <ratio> <in.wav> <out.wav>
 *
 * ratio = 1.2 plays back 1.2x faster.
 *
 * Approach: linear-interpolate the sample buffer to emit ceil(src_frames/ratio)
 * frames at the ORIGINAL sample rate. The output is the same format as the
 * input (channels, bit depth, sample rate preserved) with fewer/more frames.
 * Pitch is preserved because sample rate is unchanged; only duration shrinks
 * by the ratio, so playback reaches the end sooner — that's tempo-change.
 *
 * This is a naive resample (no anti-aliasing), which is fine for music that
 * will be re-encoded to Vorbis by oggenc afterward.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

static uint32_t rd32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static uint16_t rd16(const uint8_t *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}
static void wr16(uint8_t *p, uint16_t v) { p[0] = v & 0xff; p[1] = (v >> 8) & 0xff; }
static void wr32(uint8_t *p, uint32_t v) {
    p[0] = v & 0xff; p[1] = (v >> 8) & 0xff; p[2] = (v >> 16) & 0xff; p[3] = (v >> 24) & 0xff;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "usage: %s <ratio> <in.wav> <out.wav>\n", argv[0]);
        return 1;
    }
    double ratio = atof(argv[1]);
    if (ratio <= 0.01 || ratio > 100.0) {
        fprintf(stderr, "bad ratio (must be > 0)\n"); return 1;
    }
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
    if (data_off < 0 || bits != 16 || channels < 1 || channels > 8) {
        fprintf(stderr, "unsupported (need PCM16)\n"); return 1;
    }

    int16_t *src = (int16_t *)(buf + data_off);
    size_t src_frames = data_size / (sizeof(int16_t) * channels);
    size_t out_frames = (size_t)((double)src_frames / ratio);
    if (out_frames < 1) out_frames = 1;

    /* Resample: out[i] interpolates src at position i * ratio. */
    int16_t *out = malloc(out_frames * channels * sizeof(int16_t));
    if (!out) { fprintf(stderr, "oom\n"); return 1; }

    for (size_t i = 0; i < out_frames; i++) {
        double src_pos = (double)i * ratio;
        size_t i0 = (size_t)src_pos;
        size_t i1 = i0 + 1;
        if (i1 >= src_frames) i1 = src_frames - 1;
        if (i0 >= src_frames) i0 = src_frames - 1;
        double frac = src_pos - (double)(size_t)src_pos;
        for (int c = 0; c < channels; c++) {
            double a = (double)src[i0 * channels + c];
            double b = (double)src[i1 * channels + c];
            double v = a * (1.0 - frac) + b * frac;
            if (v > 32767.0) v = 32767.0;
            if (v < -32768.0) v = -32768.0;
            out[i * channels + c] = (int16_t)v;
        }
    }

    uint32_t out_data_bytes = (uint32_t)(out_frames * channels * sizeof(int16_t));
    uint32_t block_align = channels * sizeof(int16_t);
    uint32_t byte_rate = sample_rate * block_align;
    uint32_t riff_size = 36 + out_data_bytes;

    uint8_t hdr[44];
    memcpy(hdr, "RIFF", 4);       wr32(hdr + 4, riff_size);
    memcpy(hdr + 8, "WAVE", 4);
    memcpy(hdr + 12, "fmt ", 4);  wr32(hdr + 16, 16);
    wr16(hdr + 20, 1);                       /* PCM */
    wr16(hdr + 22, channels);
    wr32(hdr + 24, sample_rate);
    wr32(hdr + 28, byte_rate);
    wr16(hdr + 32, (uint16_t)block_align);
    wr16(hdr + 34, 16);                      /* bits */
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
