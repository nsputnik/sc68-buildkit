#!/usr/bin/env bash
#
# Build libsc68 (Benjamin Gerard's Atari ST / Amiga music player) as static
# libraries, working around the problems in its SVN/GitHub source tree. Cross-
# builds inside a Debian container matching the target's CPU + glibc, so the
# result runs on the target unchanged.
#
# Usage:
#   ./build.sh [docker-platform] [debian-suite]
#
#   default:  linux/arm/v7  buster    # Raspberry Pi OS / armv7 / glibc 2.28
#   others:   ./build.sh linux/arm64  bookworm    # aarch64
#             ./build.sh linux/amd64  bookworm    # x86-64
#
# Output: ../prebuilt/<platform>-<suite>/{lib,include}
#
set -euo pipefail
PLATFORM="${1:-linux/arm/v7}"
SUITE="${2:-buster}"
HERE="$(cd "$(dirname "$0")" && pwd)"
tag="$(echo "$PLATFORM" | tr '/' '-')-$SUITE"
[ "$tag" = "linux-arm-v7-buster" ] && tag="linux-armv7-glibc2.28"   # nice name for the Pi
OUT="$HERE/../prebuilt/$tag"
SRC="$HERE/sc68-src"

command -v docker >/dev/null || { echo "error: docker is required"; exit 1; }

# 1. sc68 source (GitHub mirror of Benjamin Gerard's SourceForge SVN) + the
#    version-script stub the mirror is missing.
if [ ! -d "$SRC" ]; then
  echo "==> fetching sc68 source"
  curl -fL https://github.com/Zeinok/sc68/archive/refs/heads/master.tar.gz | tar xz
  mv sc68-master "$SRC"
fi
cp "$HERE/vcversion.sh" "$SRC/tools/vcversion.sh"; chmod +x "$SRC/tools/vcversion.sh"

mkdir -p "$OUT/lib" "$OUT/include"
echo "==> building libsc68 for $PLATFORM ($SUITE) -> $OUT"

# 2. build the sub-packages standalone inside a matching container. The meta-
#    package bootstrap is broken (SOURCE_UNICE68 AM_CONDITIONAL), so build
#    as68 -> unice68 -> file68 -> libsc68 in order. as68 (sc68's own 68k
#    assembler) must come first: libsc68 assembles its TOS trap emulator with it.
docker run --rm --platform "$PLATFORM" -v "$SRC":/src -v "$OUT":/out \
  debian:"$SUITE"-slim bash -euo pipefail -c '
  export DEBIAN_FRONTEND=noninteractive
  # EOL Debian suites (e.g. buster) live on archive.debian.org now
  sed -i "s|deb.debian.org|archive.debian.org|g; s|security.debian.org|archive.debian.org|g" \
      /etc/apt/sources.list 2>/dev/null || true
  echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf.d/99no-check
  apt-get update -qq
  apt-get install -y -qq build-essential libtool automake autoconf pkg-config \
      zlib1g-dev libao-dev bsdmainutils
  cd /src; I=/tmp/inst; mkdir -p "$I"
  export PKG_CONFIG_PATH="$I/lib/pkgconfig" PATH="$I/bin:$PATH"
  for p in as68 unice68 file68 libsc68; do
    echo "==> building $p"
    cp -f tools/vcversion.sh "$p/vcversion.sh" 2>/dev/null || true
    ( cd "$p"
      autoreconf -fi -I ../aclocal68
      ./configure --enable-static --disable-shared --prefix="$I"
      make -j"$(nproc)"
      make install )
  done
  # collect the static libs (emu68/io68/dial68 are internal, not installed) + headers
  find /src -name "lib*.a" -path "*/.libs/*" -exec cp {} /out/lib/ \;
  cp "$I"/lib/*.a /out/lib/ 2>/dev/null || true
  rm -rf /out/include/sc68; cp -R /src/libsc68/sc68 /out/include/sc68
  cp /src/unice68/unice68.h /out/include/
'
echo "==> done. Static libs in $OUT/lib:"
ls "$OUT/lib"
