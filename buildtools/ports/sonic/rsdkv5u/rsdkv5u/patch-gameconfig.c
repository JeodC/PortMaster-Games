/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 RHH-Ports contributors
 *
 * patch-gameconfig: post-extraction GameConfig.bin fixups for Sonic 1/2 Origins.
 *
 *   1. Flip global variable "game.playMode" from 0 (Classic) to 1 (Anniversary)
 *      so Drop Dash + Plus-mode scripted behavior is enabled.
 *   2. Flip "game.hasPlusDLC" to 1 so Sonic 2's Amy / Knuckles+Tails character
 *      selection is unlocked at script level.
 *   3. Expand the Players list from 4 entries (Origins' standard trim) to the
 *      full 7-entry Plus roster so Plus-enabled rebuilds of RSDKv4 show Amy 
 *      correctly in the dev menu.
 *      With Plus-disabled (stock port), the extra entries are parsed but not
 *      spawnable — harmless, matches the Plus-ready wiki guidance.
 *
 * Usage: patch-gameconfig <GameConfig.bin>
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

static int read_all(const char *path, uint8_t **out, size_t *out_sz) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); return 0; }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *buf = malloc(n);
    if (!buf) { fclose(f); return 0; }
    if (fread(buf, 1, n, f) != (size_t)n) { fclose(f); free(buf); return 0; }
    fclose(f);
    *out = buf;
    *out_sz = n;
    return 1;
}

static int write_all(const char *path, const uint8_t *buf, size_t sz) {
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); return 0; }
    if (fwrite(buf, 1, sz, f) != sz) { fclose(f); return 0; }
    fclose(f);
    return 1;
}

// Skip a <len:u8><bytes:len> pascal string.
static size_t skip_pstr(const uint8_t *buf, size_t off) {
    return off + 1 + buf[off];
}

/* Find the Players section by parsing the GameConfig structure forward.
 * Sets *count_off to the location of the plrCount byte.
 * Sets *end_off to one past the last player entry. */
static int locate_players(const uint8_t *buf, size_t sz,
                          size_t *count_off, size_t *end_off) {
    size_t off = 0;

    // title
    off = skip_pstr(buf, off);
    // description
    off = skip_pstr(buf, off);
    // palette: 96 RGB triples = 288 bytes
    off += 0x60 * 3;

    // objects: <count:u8> then count names then count paths
    uint8_t obj_count = buf[off++];
    for (int i = 0; i < obj_count; i++) off = skip_pstr(buf, off);
    for (int i = 0; i < obj_count; i++) off = skip_pstr(buf, off);

    // globals: <count:u8> then count (name + u32)
    uint8_t var_count = buf[off++];
    for (int i = 0; i < var_count; i++) {
        off = skip_pstr(buf, off);
        off += 4;
    }

    // global SFX: <count:u8> then count names then count paths
    uint8_t sfx_count = buf[off++];
    for (int i = 0; i < sfx_count; i++) off = skip_pstr(buf, off);
    for (int i = 0; i < sfx_count; i++) off = skip_pstr(buf, off);

    // players
    if (off >= sz) return 0;
    *count_off = off;
    uint8_t plr_count = buf[off++];
    for (int i = 0; i < plr_count; i++) off = skip_pstr(buf, off);
    *end_off = off;
    return 1;
}

// Flip value of global variable by name. Returns 1 on success.
static int flip_global_var(uint8_t *buf, size_t sz, const char *name, uint32_t value) {
    size_t off = 0;
    off = skip_pstr(buf, off);
    off = skip_pstr(buf, off);
    off += 0x60 * 3;
    uint8_t obj_count = buf[off++];
    for (int i = 0; i < obj_count; i++) off = skip_pstr(buf, off);
    for (int i = 0; i < obj_count; i++) off = skip_pstr(buf, off);
    uint8_t var_count = buf[off++];
    size_t name_len = strlen(name);
    for (int i = 0; i < var_count; i++) {
        uint8_t l = buf[off];
        if (l == name_len && memcmp(buf + off + 1, name, name_len) == 0) {
            off += 1 + l;
            buf[off + 0] = (uint8_t)(value & 0xff);
            buf[off + 1] = (uint8_t)((value >> 8) & 0xff);
            buf[off + 2] = (uint8_t)((value >> 16) & 0xff);
            buf[off + 3] = (uint8_t)((value >> 24) & 0xff);
            return 1;
        }
        off = skip_pstr(buf, off);
        off += 4;
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <GameConfig.bin>\n", argv[0]);
        return 1;
    }
    const char *path = argv[1];
    uint8_t *buf = NULL;
    size_t sz = 0;
    if (!read_all(path, &buf, &sz)) return 1;

    /* 1. game.playMode = 1 */
    if (flip_global_var(buf, sz, "game.playMode", 1)) {
        printf("  game.playMode -> 1 (Anniversary mode)\n");
    } else {
        fprintf(stderr, "  WARNING: game.playMode not found; Drop Dash disabled\n");
    }

    // game.hasPlusDLC = 1, user still has to build RSDKv4 themselves
    if (flip_global_var(buf, sz, "game.hasPlusDLC", 1)) {
        printf("  game.hasPlusDLC -> 1 (unlocks Plus roster)\n");
    } else {
        fprintf(stderr, "  WARNING: game.hasPlusDLC not found; Amy may not work\n");
    }

    // Expand players list to full Plus roster
    size_t count_off = 0, end_off = 0;
    if (!locate_players(buf, sz, &count_off, &end_off)) {
        fprintf(stderr, "  ERROR: could not locate Players section\n");
        free(buf);
        return 1;
    }
    uint8_t plr_count = buf[count_off];
    if (plr_count >= 7) {
        printf("  Players list already has %u entries; skipping roster expansion\n", plr_count);
        if (!write_all(path, buf, sz)) { free(buf); return 1; }
        free(buf);
        return 0;
    }

    // Append missing entries in expected slot order. Current = 4 entries
    // (SONIC, TAILS, KNUCKLES, SONIC AND TAILS). Need to add slots 4, 5, 6.
    static const char *extra[] = {
        "KNUCKLES AND TAILS",
        "AMY",
        "AMY AND TAILS",
    };
    size_t ins_sz = 0;
    for (int i = 0; i < 3; i++) ins_sz += 1 + strlen(extra[i]);

    uint8_t *nbuf = malloc(sz + ins_sz);
    if (!nbuf) { free(buf); return 1; }

    // Copy head up to and including existing player entries
    memcpy(nbuf, buf, end_off);
    // Update count byte in copied head
    nbuf[count_off] = 7;
    // Insert new entries
    size_t w = end_off;
    for (int i = 0; i < 3; i++) {
        size_t l = strlen(extra[i]);
        nbuf[w++] = (uint8_t)l;
        memcpy(nbuf + w, extra[i], l);
        w += l;
    }
    // Copy tail (stage lists etc.)
    memcpy(nbuf + w, buf + end_off, sz - end_off);
    size_t nsz = sz + ins_sz;

    if (!write_all(path, nbuf, nsz)) { free(buf); free(nbuf); return 1; }
    printf("  Players list expanded: 4 -> 7 entries (Plus roster)\n");

    free(buf);
    free(nbuf);
    return 0;
}
