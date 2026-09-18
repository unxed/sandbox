#!/bin/bash
# Run in the f4 checkout with GOOS=redox etc. exported and go on PATH.
# Copies third-party modules out of the module cache, makes Redox join their
# illumos/solaris build-tag lists where needed, swaps in the x/sys/unix shim,
# and points go.mod at the copies.
set -euo pipefail
W="$GITHUB_WORKSPACE/f4-redox"
mkdir -p /tmp/mods

# modules that only need the "redox joins illumos/solaris" tag rule
TAGGED="github.com/unxed/vtui github.com/unxed/vtinput github.com/unxed/zip github.com/unxed/tar github.com/tetratelabs/wazero github.com/ncruces/go-sqlite3"
for m in $TAGGED; do
  go mod download "$m"
  d=$(go list -m -f '{{.Dir}}' "$m")
  n=$(echo "$m" | tr / _)
  rm -rf "/tmp/mods/$n"; cp -r "$d" "/tmp/mods/$n"; chmod -R u+w "/tmp/mods/$n"
  echo "== tags: $m"
  python3 "$W/scripts/redox_tags.py" "/tmp/mods/$n"
  go mod edit -replace "$m=/tmp/mods/$n"
done

# x/sys: keep everything except unix/, which is replaced by the redox shim
go mod download golang.org/x/sys
d=$(go list -m -f '{{.Dir}}' golang.org/x/sys)
rm -rf /tmp/mods/xsys; cp -r "$d" /tmp/mods/xsys; chmod -R u+w /tmp/mods/xsys
rm -f /tmp/mods/xsys/unix/*.go /tmp/mods/xsys/unix/*.s
cp "$W"/xsys-redox/unix/* /tmp/mods/xsys/unix/
python3 "$W/scripts/gen_zconst.py" "$GOROOT" /tmp/mods/xsys/unix
go mod edit -replace "golang.org/x/sys=/tmp/mods/xsys"

# f4 itself: same tag rule over the whole tree, plus what the rule cannot express
python3 "$W/scripts/redox_tags.py" .
sed -i 's#^//go:build linux || darwin || freebsd#//go:build linux || redox || darwin || freebsd#' internal/terminal/pty_logical_lines_unix.go
cp -r "$W"/overlay/f4/. .
git status --short | head -40
