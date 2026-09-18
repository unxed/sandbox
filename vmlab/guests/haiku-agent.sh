#!/bin/sh
# Guest-side agent for Haiku (shell: sh/bash). Polls the host for job.sh, runs it, uploads the output.
# Host side: VMLAB_AGENT_EXT=sh ctl.py sh CMD...   (job.sh's first line is a unique nonce comment).
# The host serves /tmp/vmlab/payload at http://10.0.2.2:8000/ and accepts PUT uploads there.
last=""
while true; do
    if curl -sf -o /tmp/job.sh http://10.0.2.2:8000/job.sh; then
        cur=$(head -n 1 /tmp/job.sh)
        if [ "$cur" != "$last" ]; then
            last="$cur"
            sh /tmp/job.sh > /tmp/job.out 2>&1
            echo "exit=$?" >> /tmp/job.out
            curl -s -T /tmp/job.out http://10.0.2.2:8000/job.out
        fi
    fi
    sleep 1
done
