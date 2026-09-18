#!/bin/sh
# usage: vm_run.sh <script-in-out-dir> <logfile> [kernel-file]   (out dir: $PKGOUT, default /tmp/pkg/out)
# First lets redoxer build its base image (tar of the
# installed packages, in ~/.redoxer), then swaps /boot/kernel inside that tar
# for the given kernel before running the real command.
script=$1; log=$2; kernel=$3
docker pull redoxos/redoxer >/dev/null
: > $log
kvmdev=""; [ -c /dev/kvm ] && kvmdev="--device /dev/kvm"
kmount=""; [ -n "$kernel" ] && kmount="-v $(dirname $kernel):/kdir"
( timeout 540 docker run --name f4vm --rm -e REDOXER_QEMU_ARGS="${QEMU_ARGS:--smp 2}" $kvmdev -v ${PKGOUT:-/tmp/pkg/out}:/mnt $kmount \
    redoxos/redoxer sh -c '
  D=/root/.redoxer/x86_64-unknown-redox
  if [ -n "'"$kernel"'" ]; then
    redoxer exec -- true >/tmp/prep.log 2>&1 &
    p=$!
    i=0
    while [ $i -lt 240 ]; do
      if ls $D/*.tar >/dev/null 2>&1 && ! ls $D/*.partial >/dev/null 2>&1; then break; fi
      sleep 2; i=$((i+2))
    done
    kill $p 2>/dev/null; pkill qemu 2>/dev/null; sleep 2
    echo "== base image after $i s:"; ls -la $D
    B=$(ls $D/*.tar | head -1)
    mkdir /tmp/b && tar -xpf $B -C /tmp/b
    K=$(find /tmp/b -path "*boot/kernel" -type f | head -1)
    echo "== kernel in image: $K"; ls -la $K; sha1sum $K
    cp /kdir/'"$(basename "$kernel")"' $K
    echo "== swapped in:"; ls -la $K; sha1sum $K
    tar -cpf $B.new -C /tmp/b . && mv $B.new $B
  fi
  redoxer exec -f /mnt -- sh /root/mnt/'"$script"'
' > $log 2>&1 ) &
dpid=$!
last=0; idle=0
while kill -0 $dpid 2>/dev/null; do
  sleep 5
  size=$(stat -c %s $log)
  if [ "$size" = "$last" ]; then idle=$((idle+5)); else idle=0; last=$size; fi
  grep -aq "LADDER DONE" $log && break
  if [ $idle -ge 240 ]; then
    echo "VM FROZE: no output for ${idle}s; last line: $(tail -c 200 $log | tr -d '\r' | tail -1)" | tee -a $log
    docker kill f4vm 2>/dev/null
    break
  fi
done
docker kill f4vm 2>/dev/null; wait $dpid 2>/dev/null
tail -5 $log
