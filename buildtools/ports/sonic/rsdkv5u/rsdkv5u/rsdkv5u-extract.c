/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 RHH-Ports contributors
 *
 * rsdkv5u-extract — extract files from a Sonic Origins (RSDKv5U) datapack.
 *
 * Reads the outer RSDKv4-format container header, looks each file up in a
 * supplied filelist by MD5 hash, decrypts payloads with RSDKv5U's XOR/
 * nibble-swap algorithm, writes the loose files out.
 *
 * Usage: rsdkv5u-extract <input.rsdk> <filelist.txt> <output-dir>
 *
 * Algorithm source: RSDKv5-Decompilation/RSDKv5/RSDK/Core/Reader.cpp
 *   GenerateELoadKeys + DecryptBytes.
 *
 * Compiled against nothing but libc. MD5 implementation is RFC 1321 adapted.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>
#include <errno.h>
#include <sys/stat.h>

/* ======================================================================== */
/* MD5 (compact, public domain Colin Plumb implementation, trimmed)         */
/* ======================================================================== */

typedef struct {
    uint32_t state[4];
    uint32_t count[2];
    uint8_t buffer[64];
} md5_ctx_t;

#define F1(x,y,z) (z ^ (x & (y ^ z)))
#define F2(x,y,z) F1(z, x, y)
#define F3(x,y,z) (x ^ y ^ z)
#define F4(x,y,z) (y ^ (x | ~z))
#define MD5STEP(f,w,x,y,z,data,s) (w += f(x,y,z) + data, w = (w<<s)|(w>>(32-s)), w += x)

static void md5_transform(uint32_t state[4], const uint8_t block[64]) {
    uint32_t a=state[0], b=state[1], c=state[2], d=state[3], in[16];
    for (int i=0; i<16; i++)
        in[i] = (uint32_t)block[i*4] | ((uint32_t)block[i*4+1]<<8)
              | ((uint32_t)block[i*4+2]<<16) | ((uint32_t)block[i*4+3]<<24);
    MD5STEP(F1,a,b,c,d,in[ 0]+0xd76aa478, 7);  MD5STEP(F1,d,a,b,c,in[ 1]+0xe8c7b756,12);
    MD5STEP(F1,c,d,a,b,in[ 2]+0x242070db,17); MD5STEP(F1,b,c,d,a,in[ 3]+0xc1bdceee,22);
    MD5STEP(F1,a,b,c,d,in[ 4]+0xf57c0faf, 7); MD5STEP(F1,d,a,b,c,in[ 5]+0x4787c62a,12);
    MD5STEP(F1,c,d,a,b,in[ 6]+0xa8304613,17); MD5STEP(F1,b,c,d,a,in[ 7]+0xfd469501,22);
    MD5STEP(F1,a,b,c,d,in[ 8]+0x698098d8, 7); MD5STEP(F1,d,a,b,c,in[ 9]+0x8b44f7af,12);
    MD5STEP(F1,c,d,a,b,in[10]+0xffff5bb1,17); MD5STEP(F1,b,c,d,a,in[11]+0x895cd7be,22);
    MD5STEP(F1,a,b,c,d,in[12]+0x6b901122, 7); MD5STEP(F1,d,a,b,c,in[13]+0xfd987193,12);
    MD5STEP(F1,c,d,a,b,in[14]+0xa679438e,17); MD5STEP(F1,b,c,d,a,in[15]+0x49b40821,22);
    MD5STEP(F2,a,b,c,d,in[ 1]+0xf61e2562, 5); MD5STEP(F2,d,a,b,c,in[ 6]+0xc040b340, 9);
    MD5STEP(F2,c,d,a,b,in[11]+0x265e5a51,14); MD5STEP(F2,b,c,d,a,in[ 0]+0xe9b6c7aa,20);
    MD5STEP(F2,a,b,c,d,in[ 5]+0xd62f105d, 5); MD5STEP(F2,d,a,b,c,in[10]+0x02441453, 9);
    MD5STEP(F2,c,d,a,b,in[15]+0xd8a1e681,14); MD5STEP(F2,b,c,d,a,in[ 4]+0xe7d3fbc8,20);
    MD5STEP(F2,a,b,c,d,in[ 9]+0x21e1cde6, 5); MD5STEP(F2,d,a,b,c,in[14]+0xc33707d6, 9);
    MD5STEP(F2,c,d,a,b,in[ 3]+0xf4d50d87,14); MD5STEP(F2,b,c,d,a,in[ 8]+0x455a14ed,20);
    MD5STEP(F2,a,b,c,d,in[13]+0xa9e3e905, 5); MD5STEP(F2,d,a,b,c,in[ 2]+0xfcefa3f8, 9);
    MD5STEP(F2,c,d,a,b,in[ 7]+0x676f02d9,14); MD5STEP(F2,b,c,d,a,in[12]+0x8d2a4c8a,20);
    MD5STEP(F3,a,b,c,d,in[ 5]+0xfffa3942, 4); MD5STEP(F3,d,a,b,c,in[ 8]+0x8771f681,11);
    MD5STEP(F3,c,d,a,b,in[11]+0x6d9d6122,16); MD5STEP(F3,b,c,d,a,in[14]+0xfde5380c,23);
    MD5STEP(F3,a,b,c,d,in[ 1]+0xa4beea44, 4); MD5STEP(F3,d,a,b,c,in[ 4]+0x4bdecfa9,11);
    MD5STEP(F3,c,d,a,b,in[ 7]+0xf6bb4b60,16); MD5STEP(F3,b,c,d,a,in[10]+0xbebfbc70,23);
    MD5STEP(F3,a,b,c,d,in[13]+0x289b7ec6, 4); MD5STEP(F3,d,a,b,c,in[ 0]+0xeaa127fa,11);
    MD5STEP(F3,c,d,a,b,in[ 3]+0xd4ef3085,16); MD5STEP(F3,b,c,d,a,in[ 6]+0x04881d05,23);
    MD5STEP(F3,a,b,c,d,in[ 9]+0xd9d4d039, 4); MD5STEP(F3,d,a,b,c,in[12]+0xe6db99e5,11);
    MD5STEP(F3,c,d,a,b,in[15]+0x1fa27cf8,16); MD5STEP(F3,b,c,d,a,in[ 2]+0xc4ac5665,23);
    MD5STEP(F4,a,b,c,d,in[ 0]+0xf4292244, 6); MD5STEP(F4,d,a,b,c,in[ 7]+0x432aff97,10);
    MD5STEP(F4,c,d,a,b,in[14]+0xab9423a7,15); MD5STEP(F4,b,c,d,a,in[ 5]+0xfc93a039,21);
    MD5STEP(F4,a,b,c,d,in[12]+0x655b59c3, 6); MD5STEP(F4,d,a,b,c,in[ 3]+0x8f0ccc92,10);
    MD5STEP(F4,c,d,a,b,in[10]+0xffeff47d,15); MD5STEP(F4,b,c,d,a,in[ 1]+0x85845dd1,21);
    MD5STEP(F4,a,b,c,d,in[ 8]+0x6fa87e4f, 6); MD5STEP(F4,d,a,b,c,in[15]+0xfe2ce6e0,10);
    MD5STEP(F4,c,d,a,b,in[ 6]+0xa3014314,15); MD5STEP(F4,b,c,d,a,in[13]+0x4e0811a1,21);
    MD5STEP(F4,a,b,c,d,in[ 4]+0xf7537e82, 6); MD5STEP(F4,d,a,b,c,in[11]+0xbd3af235,10);
    MD5STEP(F4,c,d,a,b,in[ 2]+0x2ad7d2bb,15); MD5STEP(F4,b,c,d,a,in[ 9]+0xeb86d391,21);
    state[0]+=a; state[1]+=b; state[2]+=c; state[3]+=d;
}

static void md5_init(md5_ctx_t *c) {
    c->state[0] = 0x67452301; c->state[1] = 0xefcdab89;
    c->state[2] = 0x98badcfe; c->state[3] = 0x10325476;
    c->count[0] = c->count[1] = 0;
}

static void md5_update(md5_ctx_t *c, const void *data, size_t len) {
    const uint8_t *p = data;
    uint32_t t = c->count[0];
    if ((c->count[0] = t + ((uint32_t)len << 3)) < t) c->count[1]++;
    c->count[1] += (uint32_t)(len >> 29);
    t = (t >> 3) & 0x3f;
    if (t) {
        uint8_t *dst = c->buffer + t;
        t = 64 - t;
        if (len < t) { memcpy(dst, p, len); return; }
        memcpy(dst, p, t); md5_transform(c->state, c->buffer);
        p += t; len -= t;
    }
    while (len >= 64) { md5_transform(c->state, p); p += 64; len -= 64; }
    memcpy(c->buffer, p, len);
}

static void md5_final(md5_ctx_t *c, uint8_t out[16]) {
    uint32_t count = (c->count[0] >> 3) & 0x3f;
    uint8_t *p = c->buffer + count;
    *p++ = 0x80;
    count = 63 - count;
    if (count < 8) { memset(p, 0, count); md5_transform(c->state, c->buffer); memset(c->buffer, 0, 56); }
    else { memset(p, 0, count - 8); }
    for (int i=0; i<4; i++) { c->buffer[56+i] = (c->count[0] >> (8*i)) & 0xff; c->buffer[60+i] = (c->count[1] >> (8*i)) & 0xff; }
    md5_transform(c->state, c->buffer);
    for (int i=0; i<4; i++) for (int j=0; j<4; j++) out[i*4+j] = (c->state[i] >> (8*j)) & 0xff;
}

static void md5_bytes(const char *s, size_t n, uint8_t out[16]) {
    md5_ctx_t c; md5_init(&c); md5_update(&c, s, n); md5_final(&c, out);
}

/* ======================================================================== */
/* RSDKv5U datapack format                                                  */
/* ======================================================================== */

/* Per RSDKv5/RSDK/Core/Reader.cpp::GenerateELoadKeys: for each state word,
 * reverse the 4 bytes ((j^3) mapping). */
static void swap_hash_words(uint8_t out[16], const uint8_t in[16]) {
    for (int i=0; i<4; i++)
        for (int j=0; j<4; j++)
            out[i*4 + j] = in[i*4 + (j ^ 3)];
}

typedef struct {
    uint8_t keyA[16];
    uint8_t keyB[16];
    uint8_t keyNo;
    uint8_t posA;
    uint8_t posB;
    uint8_t nybbleSwap;
} decrypt_state_t;

/* key1 = filename (uppercased inside), key2 = fileSize */
static void gen_load_keys(decrypt_state_t *s, const char *filename, uint32_t fileSize) {
    char buf[0x400];
    /* Uppercase the filename */
    size_t len = strlen(filename);
    if (len >= sizeof(buf)) len = sizeof(buf) - 1;
    for (size_t i=0; i<len; i++) buf[i] = (char)toupper((unsigned char)filename[i]);
    buf[len] = 0;

    uint8_t hash[16];
    md5_bytes(buf, len, hash);
    swap_hash_words(s->keyA, hash);

    int n = snprintf(buf, sizeof(buf), "%u", (unsigned)fileSize);
    md5_bytes(buf, (size_t)n, hash);
    swap_hash_words(s->keyB, hash);

    /* Initial state per Reader.cpp's LoadFile path for encrypted files:
     *   info->eKeyNo   = (fileSize & 0x1FC) >> 2;
     *   info->eKeyPosA = 0;
     *   info->eKeyPosB = 8;
     *   info->eNybbleSwap = 0;
     */
    s->keyNo = (uint8_t)((fileSize & 0x1FC) >> 2);
    s->posA = 0;
    s->posB = 8;
    s->nybbleSwap = 0;
}

/* Per Reader.cpp::DecryptBytes, decrypt ciphertext into place. */
static void decrypt_bytes(decrypt_state_t *s, uint8_t *data, size_t size) {
    for (size_t i=0; i<size; i++) {
        uint8_t b = data[i];
        b ^= (uint8_t)(s->keyNo ^ s->keyB[s->posB]);
        if (s->nybbleSwap) b = (uint8_t)(((b << 4) | (b >> 4)) & 0xff);
        b ^= s->keyA[s->posA];
        data[i] = b;

        s->posA++;
        s->posB++;
        if (s->posA <= 15) {
            if (s->posB > 12) {
                s->posB = 0;
                s->nybbleSwap ^= 1;
            }
        } else if (s->posB <= 8) {
            s->posA = 0;
            s->nybbleSwap ^= 1;
        } else {
            s->keyNo = (uint8_t)((s->keyNo + 2) & 0x7F);
            if (s->nybbleSwap) {
                s->nybbleSwap = 0;
                s->posA = (uint8_t)(s->keyNo % 7);
                s->posB = (uint8_t)((s->keyNo % 12) + 2);
            } else {
                s->nybbleSwap = 1;
                s->posA = (uint8_t)((s->keyNo % 12) + 3);
                s->posB = (uint8_t)(s->keyNo % 7);
            }
        }
    }
}

/* ======================================================================== */
/* Main                                                                     */
/* ======================================================================== */

typedef struct {
    uint8_t hash[16];   /* bytes as stored in the pack header */
    uint32_t offset;
    uint32_t size;
    int encrypted;
} entry_t;

/* Hash the way the pack stores it: raw MD5 bytes, each 4-byte word reversed. */
static void compute_entry_hash(const char *filename, uint8_t out[16]) {
    /* RSDKv5U hashes lowercased filenames (StringLowerCase). */
    char buf[0x400];
    size_t len = strlen(filename);
    if (len >= sizeof(buf)) len = sizeof(buf) - 1;
    for (size_t i=0; i<len; i++) buf[i] = (char)tolower((unsigned char)filename[i]);
    buf[len] = 0;

    uint8_t md5[16];
    md5_bytes(buf, len, md5);
    /* Pack header stores hash bytes with the same swap as the key — each
     * 4-byte word reversed. */
    swap_hash_words(out, md5);
}

static int make_dirs(const char *path) {
    char buf[1024];
    strncpy(buf, path, sizeof(buf)-1); buf[sizeof(buf)-1] = 0;
    for (char *p = buf + 1; *p; p++) {
        if (*p == '/') {
            *p = 0;
            if (mkdir(buf, 0755) != 0 && errno != EEXIST) return -1;
            *p = '/';
        }
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <input.rsdk> <filelist.txt> <output-dir>\n", argv[0]);
        return 2;
    }
    const char *inpath = argv[1];
    const char *listpath = argv[2];
    const char *outdir = argv[3];

    FILE *f = fopen(inpath, "rb");
    if (!f) { perror(inpath); return 1; }
    fseek(f, 0, SEEK_END);
    long filesize = ftell(f);
    fseek(f, 0, SEEK_SET);

    uint8_t header[8];
    if (fread(header, 1, 8, f) != 8) { fprintf(stderr, "short read\n"); return 1; }

    /* Accept RSDKv4 (Sonic 1/2 Origins), RSDKv3 (Sonic CD Origins, same v5U
     * payload layout with a v3-branded outer header), or RSDKvB (mobile-style
     * older decomp containers). All use the same 24-byte entry layout. */
    if (memcmp(header, "RSDKv4", 6) != 0
     && memcmp(header, "RSDKv3", 6) != 0
     && memcmp(header, "RSDKvB", 6) != 0) {
        fprintf(stderr, "Not an RSDKv3/v4/v5U datapack (bad signature)\n");
        return 1;
    }
    uint16_t filecount = (uint16_t)(header[6] | (header[7] << 8));
    fprintf(stderr, "pack: sig=%.6s, %u files\n", header, filecount);

    entry_t *entries = calloc(filecount, sizeof(entry_t));
    if (!entries) { perror("calloc"); return 1; }
    for (int i=0; i<filecount; i++) {
        uint8_t buf[24];
        if (fread(buf, 1, 24, f) != 24) { fprintf(stderr, "short read entry %d\n", i); return 1; }
        memcpy(entries[i].hash, buf, 16);
        entries[i].offset = (uint32_t)buf[16] | ((uint32_t)buf[17]<<8) | ((uint32_t)buf[18]<<16) | ((uint32_t)buf[19]<<24);
        uint32_t raw = (uint32_t)buf[20] | ((uint32_t)buf[21]<<8) | ((uint32_t)buf[22]<<16) | ((uint32_t)buf[23]<<24);
        entries[i].encrypted = (raw & 0x80000000u) ? 1 : 0;
        entries[i].size = raw & 0x7fffffffu;
    }

    /* Load filelist and match hashes. */
    FILE *lf = fopen(listpath, "r");
    if (!lf) { perror(listpath); return 1; }

    int matched = 0, failed = 0;
    char line[1024];
    while (fgets(line, sizeof(line), lf)) {
        /* strip trailing whitespace */
        size_t ln = strlen(line);
        while (ln > 0 && (line[ln-1] == '\n' || line[ln-1] == '\r' || line[ln-1] == ' ' || line[ln-1] == '\t'))
            line[--ln] = 0;
        if (ln == 0 || line[0] == '#') continue;

        uint8_t want[16];
        compute_entry_hash(line, want);

        entry_t *e = NULL;
        for (int i=0; i<filecount; i++) {
            if (memcmp(entries[i].hash, want, 16) == 0) { e = &entries[i]; break; }
        }
        if (!e) continue;

        /* Read the payload */
        if (e->offset + e->size > (uint32_t)filesize) {
            fprintf(stderr, "WARN %s: offset+size past EOF\n", line);
            failed++; continue;
        }
        if (fseek(f, e->offset, SEEK_SET) != 0) { perror("fseek"); failed++; continue; }
        uint8_t *buf = malloc(e->size);
        if (!buf) { perror("malloc"); failed++; continue; }
        if (fread(buf, 1, e->size, f) != e->size) { fprintf(stderr, "short read %s\n", line); free(buf); failed++; continue; }

        if (e->encrypted) {
            decrypt_state_t s;
            gen_load_keys(&s, line, e->size);
            decrypt_bytes(&s, buf, e->size);
        }

        /* Write to outdir/line */
        char outpath[2048];
        snprintf(outpath, sizeof(outpath), "%s/%s", outdir, line);
        if (make_dirs(outpath) != 0) { fprintf(stderr, "mkdir failed for %s\n", outpath); free(buf); failed++; continue; }
        FILE *of = fopen(outpath, "wb");
        if (!of) { perror(outpath); free(buf); failed++; continue; }
        fwrite(buf, 1, e->size, of);
        fclose(of);
        free(buf);
        matched++;
    }
    fclose(lf);
    fclose(f);
    free(entries);

    fprintf(stderr, "extracted %d, failed %d, unknown hashes: %d\n",
            matched, failed, (int)filecount - matched - failed);
    return (matched == 0) ? 1 : 0;
}
