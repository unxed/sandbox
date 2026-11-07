#!/bin/sh
# Run the initial GUI scenarios in isolated pairs. The caller initializes
# GUI_SUITE_GOLDEN_PREFIX once for this exact Wine build first.
set -eu
script_dir=$(cd "$(dirname "$0")" && pwd)
run_tag=${GUI_SUITE_RUN_TAG-initial}
case "$run_tag" in *[!a-zA-Z0-9_-]*|'') echo 'Run tag must be a simple name' >&2; exit 2 ;; esac
export GUI_SUITE_RUN_TAG=$run_tag
results=/work/evidence/gui-$run_tag
mkdir -p "$results"
run_one() {
  job_version=$1
  job_scenario=$2
  job_display=$3
  job_plan=${4-}
  set +e
  sh "$script_dir/gui-suite-guest.sh" "$job_version" "$job_scenario" "$job_display" "$job_plan" \
    >"$results/$job_version-$job_scenario.launch.log" 2>&1
  job_status=$?
  set -e
  printf '%s\n' "$job_status" >"$results/$job_version-$job_scenario.exit"
  printf '%s %s exit=%s\n' "$job_version" "$job_scenario" "$job_status"
  return "$job_status"
}
failed=0
run_one 5.6 edges 20 &
pid_one=$!
run_one 8.5 edges 21 &
pid_two=$!
# Bound concurrency to two guest applications. Four instances under TCG stalled
# each other (CI run 40679671563: SendMessageTimeout failures, white captures).
for job_pid in "$pid_one" "$pid_two"; do wait "$job_pid" || failed=$((failed+1)); done
if test "${GUI_SUITE_PAIRS-0}" = 1; then
  run_one 5.6 top 24 || failed=$((failed+1))
  run_one 8.5 top 25 || failed=$((failed+1))
else
  run_one 5.6 top 24 &
  pid_five=$!
  run_one 8.5 top 25 &
  pid_six=$!
  wait "$pid_five" || failed=$((failed+1))
  wait "$pid_six" || failed=$((failed+1))
fi
run_one 5.6 lefttools 22 "$script_dir/gui-suite-initial-lefttools.tsv" &
pid_three=$!
run_one 8.5 lefttools 23 "$script_dir/gui-suite-initial-lefttools.tsv" &
pid_four=$!
for job_pid in "$pid_three" "$pid_four"; do
  wait "$job_pid" || failed=$((failed+1))
done
printf 'INITIAL_SMOKE_FAILED_JOBS=%s\n' "$failed"
test "$failed" -eq 0
