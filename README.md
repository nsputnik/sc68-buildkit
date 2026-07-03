# sc68-buildkit

**Prebuilt static `libsc68` + a one-command recipe to build more targets.**

`libsc68` is the engine of **sc68** — Benjamin Gerard's Atari ST / Amiga music
player (Motorola 68000 CPU + YM-2149 / Paula emulation) that plays **SNDH** and
`.sc68` files. sc68 is a ~2016 autotools project whose source tree **no longer
builds cleanly** on modern systems. This kit packages the fixes and ships the
resulting libraries so you don't have to rediscover them.

> **Upstream:** sc68 © **Benjamin Gerard** (*Ben/OVR*) — <http://sc68.atari.org>,
> source <https://sourceforge.net/p/sc68> (mirror
> <https://github.com/Zeinok/sc68>), **GPLv3**. This repo only builds/repackages
> it — see *Credit & license* below.

## Just grab the prebuilt libs — no build needed

`prebuilt/<target>/` has ready-to-link static libraries + headers:

| target | CPU / libc | good for |
|---|---|---|
| `linux-armv7-glibc2.28` | 32-bit ARM, glibc 2.28 | Raspberry Pi OS "Buster", Pi Zero 2 W / 3 / 4 |

Link them into your program:

```sh
L=prebuilt/linux-armv7-glibc2.28
cc your_player.c -I"$L/include" \
  -Wl,--start-group "$L"/lib/lib{sc68,dial68,io68,emu68,file68,unice68}.a -Wl,--end-group \
  -lao -lz -lm -lpthread -ldl -o your_player
```

Runtime dependency: **libao** (`apt install libao-dev`). See
[`example/sndhtest.c`](example/sndhtest.c) for a minimal loader (opens an SNDH,
renders a few seconds, reports whether there's sound).

### Music to play

Grab SNDH tunes to feed it from the **[SNDH Archive](https://sndh.atari.org/)** —
the full, curated collection of Atari ST YM-2149 music (~9,900 tunes, organised
by composer). Download the whole set here:

> **<https://sndh.atari.org/download.php>**

Every `.sndh` there plays with these libraries.

## Build for another target

[`build/build.sh`](build/build.sh) cross-builds inside a Debian container that
matches the target's CPU **and** glibc, so the output runs there unchanged.
Needs Docker.

```sh
cd build
./build.sh                       # default: linux/arm/v7 buster (the Pi)
./build.sh linux/arm64 bookworm  # aarch64
./build.sh linux/amd64 bookworm  # x86-64
```

Results land in `prebuilt/<target>/`. PRs adding prebuilt targets welcome.

## What the build has to work around

The sc68 SVN/mirror tree won't configure or compile as-is. `build.sh` applies:

- **`tools/vcversion.sh` is missing** (it's SVN-generated). `configure.ac` runs
  it via `esyscmd`, so it's stubbed — emitting the revision with **no trailing
  newline** (a newline ends up inside `AC_INIT`'s version string and breaks
  every generated `configure` with *"missing terminating `"`"*).
- **The meta-package bootstrap fails** (`Makefile.am: SOURCE_UNICE68 does not
  appear in AM_CONDITIONAL`), so the sub-packages are built **standalone** in
  order: **`as68 → unice68 → file68 → libsc68`**. `as68` (sc68's own 68000
  assembler) must be built first and be on `PATH` — libsc68 assembles its TOS
  trap emulator (`trapfunc.s → trap68.h`) with it.
- **`hexdump` is required** by the bootstrap → install `bsdmainutils`.
- **EOL Debian suites** (buster) → point apt at `archive.debian.org`.

## Credit & license

`libsc68` and everything under `prebuilt/` are part of **sc68**, © **Benjamin
Gerard**, licensed **GPLv3** — full text in [`COPYING-sc68`](COPYING-sc68).
Please keep that attribution; sc68 is his work, this kit just makes it buildable
again.

The build tooling and docs in this repo (`build/`, `example/`, this README) are
dedicated to the public domain (CC0). Note that anything you **distribute** that
includes the prebuilt libraries is a derivative of sc68 and therefore **GPLv3**.
