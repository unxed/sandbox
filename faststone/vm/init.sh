#!/bin/sh
/bin/busybox --install -s /bin
export PATH=/bin:/usr/bin:/usr/sbin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts /var/cache/fontconfig /root/.cache/fontconfig
mount -t devpts devpts /dev/pts
for m in netfs 9pnet 9pnet_virtio 9p; do insmod /modules/$m.ko; done
mount -t 9p -o trans=virtio,version=9p2000.L,cache=none work /work
hostname faststone-test
ifconfig lo 127.0.0.1 up
export WINEDEBUG=-all
export WINEDLLOVERRIDES='mscoree,mshtml,winemenubuilder.exe='
export DISPLAY=:0
export LD_LIBRARY_PATH=/work/vm-root/usr/lib/x86_64-linux-gnu:/work/vm-root/lib/x86_64-linux-gnu
Xvfb :0 -screen 0 1280x800x24 -nolisten tcp -ac -extension GLX >/work/evidence/guest-xvfb.log 2>&1 &
exec sh /work/patch-export/faststone/vm/worker.sh
