#!/bin/sh
set -eu
cd "$(dirname "$0")/../../.."
mkdir -p vm-queue-live
printf 'run\n' > vm-queue-live/control
# Keep guest ownership in xattrs instead of exposing the host runner UID.
# Wine rejects a prefix when the guest process does not own it.
exec timeout 7200 qemu-system-x86_64 -machine q35,accel=tcg -cpu qemu64 \
 -smp 4 -m 3072 -nodefaults -display none -monitor none -serial stdio -no-reboot \
 -kernel vm-kernel-verified/boot/vmlinuz-6.8.0-138-generic -initrd vm-initrd-v2.gz \
 -append 'console=ttyS0 loglevel=3 rdinit=/init panic=1' \
 -virtfs "local,path=$PWD,mount_tag=work,security_model=mapped-xattr,id=work"
