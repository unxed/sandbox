# FastStone with a private Wine runtime

`faststone-wine.run` is one Linux x86_64 executable. Default: FastStone Image
Viewer 5.6. `--latest` selects the pinned 8.5 release. Each version has separate
application files, settings and Wine prefixes. The launcher does not use or
remove `~/.wine`.

On the first run, it verifies and extracts its bundled runtime into the user's
cache, downloads FastStone only from the Internet Archive, verifies SHA-256 and
extracts the application. Later starts work offline. The vendor executable and
DLLs are not patched. Existing unrecognized application directories are kept.

```sh
chmod +x faststone-wine.run
./faststone-wine.run /absolute/path/to/picture.jpg
./faststone-wine.run --latest /absolute/path/to/pictures
FASTSTONE_ARCHIVE=/absolute/path/FSViewerSetup56.exe ./faststone-wine.run --prepare
FASTSTONE_ARCHIVE=/absolute/path/FSViewer85.zip ./faststone-wine.run --prepare --latest
```

`--prepare` needs neither a display nor wineserver. `--self-test` verifies the
bundled loader can run Wine, curl and 7-Zip; it is not an application GUI test.
`--wine` runs diagnostics in the private prefix without downloading FastStone.

## Files and parallel tests

| Purpose | Default |
| --- | --- |
| Runtime | `$XDG_CACHE_HOME/faststone-wine/<payload-sha256>` |
| FastStone 5.6 | `$XDG_DATA_HOME/faststone-wine/5.6/app` |
| FastStone 8.5 | `$XDG_DATA_HOME/faststone-wine/8.5/app` |
| Prefixes | `<version>/prefix` |
| Original archives | `$XDG_DATA_HOME/faststone-wine/downloads` |

Unset XDG variables use `~/.cache` and `~/.local/share`. `FASTSTONE_CACHE_HOME`
and `FASTSTONE_DATA_HOME` override the respective roots; both must be absolute.
Parallel GUI workers should have independent data roots and displays, while
sharing the runtime cache. Advisory locks and atomic directory moves prevent
partial first-run installations from becoming visible to another worker.

The 5.6 NSIS installer is unpacked with 7-Zip. A newly generated small bitmap
`Portable.db` marker requests portable mode. Its effect on settings locations
must be tested with the actual application; extraction alone cannot prove it.

## Compatibility boundary

The static ELF bootstrap and busybox do not depend on host Wine, 32-bit Linux
libraries, FUSE, root, Python, curl, 7-Zip or tar. Wine and other dynamic binaries
use a bundled glibc loader. The bootstrap rewrites reserved ELF interpreter
fields to the extracted loader's absolute path, avoiding a dependency on the
host's glibc version solely because the build host was Ubuntu 24.04.

A Linux x86_64 kernel supporting this Wine build and a working X11 display are
still needed. Wayland requires XWayland and `DISPLAY`; the current Wine build
has no native Wayland driver. Fonts, font configuration, locales and certificate
trust stores come from the host. GPU drivers, desktop services and device access
remain host services. The optional ODBC provider is excluded. Ordinary image
viewing must not depend on video codecs. No claim is made about every kernel,
architecture, display configuration or image format.

The runtime includes available configured `SONAME_*` libraries and transitive
ELF dependencies, NSS providers and iconv `gconv` modules. GPU loaders are
included, but native vendor drivers are not copied from the build machine.

## Build

Finish Wine and install it to a fresh DESTDIR before packaging. An incomplete
build tree does not provide Wine's complete installed resource layout.

```sh
JOBS=8 sh sandbox/faststone/build-wine.sh
make -C wine-image-build install DESTDIR="$PWD/wine-stage"
python3 sandbox/faststone/bundle/build.py \
  --wine-prefix "$PWD/wine-stage/opt/faststone-wine" \
  --wine-source "$PWD/wine" --config "$PWD/wine-image-build/include/config.h" \
  --wine-revision "$(git -C wine rev-parse HEAD)" \
  --busybox /usr/bin/busybox --patchelf /usr/bin/patchelf \
  --output "$PWD/faststone-wine.run"
```

The authoritative `build-wine.sh` disables the shader-stack DLL families and
configures Wine without Vulkan, OpenGL, GStreamer, native Wayland and audio
backends. It retains required AVI/Quartz imports. The exact flags are saved in
`evidence/wine-image-configure.flags`. Source is not patched by the build script.
The latest viewer's optional SVG/PDF paths still need format-specific GUI tests.

`bundle/image_build.py` preserves an earlier experimental module-only strategy
for a separate build with reused objects. It is not the release build command;
its broader optional-module exclusions have not been validated by GUI tests.

Build tools: Python 3.9+, a static-capable C compiler, patchelf, GNU/PE strip,
curl, full 7-Zip with its plugin, util-linux flock and the libraries selected by
Wine's configure. Output metadata includes Wine revision, library list and final
checksums.

## Licensing and provenance

FastStone itself is not embedded in the redistributable launcher. Its 5.6
license permits personal/educational use and copies, and prohibits modifying the
program. It does not explicitly resolve public redistribution of a repackaged
Wine bundle. Downloading the original archive on the user's machine avoids
assuming broader rights. Commercial use still needs the vendor's license.

| Archive | SHA-256 |
| --- | --- |
| 5.6 installer | `1f6d5826d05046462ceec503812a89e8347a68bc382678db1d88baedc070c604` |
| 8.5 portable ZIP | `685282a063b91daf4388b84be9e0daf3c5feed4073651137eb9fe9421cf39439` |

The payload hash detects corruption; it is not a publisher signature. Preserve
runtime notices and supply the exact corresponding Wine source, patch series,
and other sources/build information required by bundled-library licenses before
public distribution. `licenses/` records package notices and source package
versions. The bootstrap's own source is embedded too. This is a bundled private
runtime, not a claim of static-everywhere Profile H conformance.

## Verification status after environment reset

The original environment and all original logs/binaries were lost. The previous
synthetic bundle used `/bin/echo` and `/bin/true` in place of Wine, had a 21 MB
launcher, bundled 70 shared libraries and relocated seven ELF interpreters.
Historical successful checks were: four parallel first starts; a single complete
cache; relocation and filenames with spaces; no default `~/.wine`; offline
extraction of both archives with unchanged vendor executable checksums; repeated
preparation; wrong archive rejection; corrupted payload rejection; and a clear
missing-display error before downloading. The bundled curl also successfully
downloaded the pinned 8.5 ZIP directly from the Internet Archive.

Those historical results are not current verification. Restored `bootstrap.c`
has been compiled again with `-static -Wall -Wextra -Werror`; the shell and Python
syntax checks pass. Rebuild the synthetic and real runtime and rerun:

```sh
python3 sandbox/faststone/bundle/test_bundle.py ./faststone-wine.run \
  --archive56 downloads/FSViewerSetup56.exe --archive85 downloads/FSViewer85.zip
```

GUI behavior, actual portable settings, multimedia graceful failure and
cross-distribution compatibility require the independent application tests.

### Revalidation in the restored environment

A new synthetic `.run` was built with the restored code and current configure
header: 21,407,385 bytes, 65 shared libraries, seven relocated interpreters.
SHA-256: `a3d96cc8090acaa648f3b463fa61ca878e199731fc8cf8c9524f1a4416635ff5`.
All seven groups in `test_bundle.py` passed again, including concurrent first
starts and offline preparation of both pinned archives with unchanged vendor
executables. Current logs are `evidence/bundle-smoke-build.json` and
`evidence/bundle-smoke-tests.txt`. This is packaging verification with a fake
Wine command, not evidence of a working FastStone GUI or a complete real runtime.
