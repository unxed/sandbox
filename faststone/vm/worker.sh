#!/bin/sh
cd /work
mkdir -p vm-queue-live
echo GUEST_WORKER_READY
while [ "$(cat vm-queue-live/control 2>/dev/null)" != stop ]; do
 for task_file in vm-queue-live/*.request; do
  [ -f "$task_file" ] || continue
  while [ "$(jobs -p | wc -l)" -ge 4 ]; do sleep 0.2; done
  running_file=${task_file%.request}.running
  # Stale directory entries must not cause the same request to run twice.
  mkdir "${task_file%.request}.claimed" 2>/dev/null || continue
  if ! mv "$task_file" "$running_file"; then
   rmdir "${task_file%.request}.claimed" 2>/dev/null || true
   continue
  fi
  (
   sh "$running_file" > "${running_file%.running}.response" 2>&1
   status=$?
   echo "$status" > "${running_file%.running}.exit"
   mv "$running_file" "${running_file%.running}.done"
  ) &
 done
 sleep 0.2
done
wait
sync
poweroff -f
