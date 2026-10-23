#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu
runtime=${FASTSTONE_RUNTIME:?missing bundle runtime}
bb=$runtime/bin/busybox
version=5.6
wine_mode=0
archive_override=${FASTSTONE_ARCHIVE:-}
case "${1:-}" in
 --help)
  "$bb" cat <<'EOF'
FastStone + patched Wine, Linux x86_64
Usage: faststone-wine.run [--latest | --5.6] [image-or-directory]
       faststone-wine.run --wine [Wine arguments]
       faststone-wine.run --self-test
       faststone-wine.run --prepare [--latest | --5.6]

Default: FastStone 5.6. --latest selects the pinned FastStone 8.5 release.
First use downloads the selected application only from web.archive.org.
For offline use, set FASTSTONE_ARCHIVE=/absolute/path/to/the/pinned/archive.
Runtime cache: FASTSTONE_CACHE_HOME or XDG_CACHE_HOME/faststone-wine.
Settings and application: FASTSTONE_DATA_HOME or XDG_DATA_HOME/faststone-wine.
No host Wine, root access, FUSE, or 32-bit Linux libraries are needed.
An x86_64 Linux kernel and X11/XWayland display are required for the GUI.
EOF
  exit 0;;
 --self-test)
  "$runtime/wine/bin/wine" --version
  "$runtime/bin/curl" --version
  "$runtime/bin/7z" i >/dev/null
  printf '%s\n' 'Runtime loader, downloader and extractor: OK'
  exit 0;;
 --wine) wine_mode=1; shift;;
esac
prepare=0
if [ "${1:-}" = --prepare ]; then prepare=1; shift; fi
case "${1:-}" in
 --latest) version=8.5; shift;;
 --5.6) shift;;
esac
if [ "$prepare" -eq 0 ] && [ "$wine_mode" -eq 0 ] && [ -z "${DISPLAY:-}" ]; then
 printf '%s\n' 'FastStone needs an X11 display (DISPLAY). On Wayland, enable XWayland.' >&2
 exit 1
fi
case "$version" in
 5.6)
  url='https://web.archive.org/web/20261022225527id_/https://2g0.ru/fs/FSViewerSetup56.exe'
  sha='1f6d5826d05046462ceec503812a89e8347a68bc382678db1d88baedc070c604'
  filename=FSViewerSetup56.exe;;
 8.5)
  url='https://web.archive.org/web/20260624231629id_/https://www.faststonesoft.net/DN/FSViewer85.zip'
  sha='685282a063b91daf4388b84be9e0daf3c5feed4073651137eb9fe9421cf39439'
  filename=FSViewer85.zip;;
esac
if [ -n "${FASTSTONE_DATA_HOME:-}" ]; then data=$FASTSTONE_DATA_HOME
elif [ -n "${XDG_DATA_HOME:-}" ]; then data=$XDG_DATA_HOME/faststone-wine
else data=${HOME:?HOME must be set}/.local/share/faststone-wine
fi
case "$data" in /*) ;; *) printf '%s\n' 'Data directory must be an absolute path.' >&2; exit 1;; esac
umask 077
"$bb" mkdir -p "$data/$version" "$data/downloads"
export WINEPREFIX=$data/$version/prefix
export WINEDEBUG=${FASTSTONE_WINEDEBUG:--all}
export WINEDLLOVERRIDES='winemenubuilder.exe,mscoree,mshtml='
if [ "$wine_mode" -eq 1 ]; then exec "$runtime/wine/bin/wine" "$@"; fi
exec 9>"$data/$version/prepare.lock"
"$runtime/bin/flock" -x 9
app=$data/$version/app
if [ ! -f "$app/.archive-$sha" ]; then
 archive=$data/downloads/$filename
 if [ -n "$archive_override" ]; then
  archive=$archive_override
 elif ! printf '%s  %s\n' "$sha" "$archive" | "$bb" sha256sum -c - >/dev/null 2>&1; then
  printf 'Downloading FastStone %s from the Internet Archive...\n' "$version" >&2
  partial=$data/downloads/.$filename.$$.part
  trap '"$bb" rm -f "$partial"' EXIT HUP INT TERM
  ca=
  for ca_path in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem; do
   if [ -r "$ca_path" ]; then ca=$ca_path; break; fi
  done
  if [ -n "$ca" ]; then export CURL_CA_BUNDLE=$ca; fi
  "$runtime/bin/curl" --fail --location --retry 2 --connect-timeout 25 --max-time 300 \
    --proto '=https' --proto-redir '=https' --output "$partial" "$url"
  printf '%s  %s\n' "$sha" "$partial" | "$bb" sha256sum -c - >/dev/null
  "$bb" mv "$partial" "$archive"
  trap - EXIT HUP INT TERM
 fi
 printf '%s  %s\n' "$sha" "$archive" | "$bb" sha256sum -c - >/dev/null || {
  printf '%s\n' 'Wrong application archive. Only the exact pinned archive is accepted.' >&2; exit 1;
 }
 stage=$("$bb" mktemp -d "$data/$version/.prepare-XXXXXX")
 trap '"$bb" rm -rf "$stage"' EXIT HUP INT TERM
 "$runtime/bin/7z" x -y "-o$stage/unpacked" "$archive" >/dev/null
 if [ "$version" = 8.5 ]; then extracted=$stage/unpacked/FSViewer85
 else extracted=$stage/unpacked
 fi
 [ -f "$extracted/FSViewer.exe" ] || { printf '%s\n' 'Application archive layout changed.' >&2; exit 1; }
 if [ "$version" = 5.6 ]; then
  "$bb" cp "$runtime/portable-marker.bmp" "$extracted/Portable.db"
  "$bb" rm -rf "$extracted/\$PLUGINSDIR"
 fi
 : > "$extracted/.archive-$sha"
 if [ -e "$app" ]; then
  printf '%s\n' 'Existing application directory is unrecognized; it has been preserved.' >&2
  exit 1
 fi
 "$bb" mv "$extracted" "$app"
 "$bb" rm -rf "$stage"
 trap - EXIT HUP INT TERM
fi
"$runtime/bin/flock" -u 9
exec 9>&-
[ "$prepare" -eq 0 ] || { printf 'Prepared FastStone %s: %s\n' "$version" "$app"; exit 0; }
remaining=$#
while [ "$remaining" -gt 0 ]; do
 argument=$1
 shift
 if [ -e "$argument" ]; then argument=$("$runtime/wine/bin/wine" winepath -w "$argument"); fi
 set -- "$@" "$argument"
 remaining=$((remaining - 1))
done
cd "$app"
exec "$runtime/wine/bin/wine" "$app/FSViewer.exe" "$@"
