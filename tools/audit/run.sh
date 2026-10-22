#!/bin/sh
# Fetches the corpora and runs the audit of the whole history of HEAD with the profile of the repository.
# Environment: CORPORA (cache directory, default ~/.cache/tv3-corpora), AUDIT_JSON (report, default audit.json).
set -e
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
CORPORA=${CORPORA:-$HOME/.cache/tv3-corpora}
export CORPORA
python3 "$here/corpora.py"
python3 "$here/audit.py" --corpora "$CORPORA" --repo "$repo" \
    --raw 16 --ren 60 --ren-ident-percent 40 --lit 12 --lit-distinct 6 \
    --out "${AUDIT_JSON:-audit.json}"
