/* config.h — XyDesk: konfigurasi libopus generik (float, tanpa asm arsitektur).
 *
 * Disetarakan dengan keluaran configure untuk build MSVC x64/arm64:
 * - FIXED_POINT TIDAK didefinisikan (build float — akurat & cepat di
 *   x86_64/aarch64 modern).
 * - Tanpa jalur asm (SSE/NEON) — kode C generik, portabel antar runner CI.
 * - USE_ALLOCA untuk MSVC (_alloca dari <malloc.h>); Unix memakai HAVE_ALLOCA_H.
 */
#ifndef OPUS_CONFIG_H
#define OPUS_CONFIG_H

#define OPUS_VERSION "1.5.2"
#define OPUS_PACKAGE_VERSION "1.5.2"
#define OPUS_BUILD

#if defined(_MSC_VER)
# define USE_ALLOCA
#else
# define HAVE_ALLOCA_H 1
#endif

#define HAVE_LRINT 1
#define HAVE_LRINTF 1
#define HAVE_MEMORY_H 1
#define HAVE_STRING_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_MATH_H 1

#endif /* OPUS_CONFIG_H */
