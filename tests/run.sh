#!/usr/bin/env bash
# tests/run.sh: fixture-driven tests for scripts/write-op-gate.sh. Each test
# puts the stub `bird` (fixtures/bin/bird) first on PATH, invokes the script
# with stdin from /dev/null (a non-TTY caller), and asserts on the exit code,
# stdout and stderr substrings, and the argv the stub recorded.
#
# The stub writes a body with exit 0 to stdout and a body with a non-zero
# exit to stderr, which is how the real binary splits success envelopes from
# error envelopes, and it refuses an unforced live write off a TTY the way
# bird does.
#
# Run from any working directory:
#     bash tests/run.sh

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GATE="$ROOT/scripts/write-op-gate.sh"
PASSED=0
FAILED=0

DRYRUN_OK='{"data":{"dry_run":true,"would":{"method":"POST","url":"https://api.x.com/2/users/1/likes","body":{"tweet_id":"1234567890"}},"verb":"like"},"meta":{}}'
LIVE_OK='{"data":{"liked":true},"meta":{}}'

# --- Scaffolding -----------------------------------------------------------

_stdout=""
_stderr=""
_exit=0

reset_stub() {
  unset BIRD_STUB_DRYRUN_BODY BIRD_STUB_DRYRUN_EXIT \
    BIRD_STUB_LIVE_BODY BIRD_STUB_LIVE_EXIT
  BIRD_STUB_CALLS=$(mktemp)
  export BIRD_STUB_CALLS
}

cleanup_stub() {
  [ -n "${BIRD_STUB_CALLS:-}" ] && rm -f "$BIRD_STUB_CALLS"
  unset BIRD_STUB_CALLS
}

run_script() {
  local stderr_file
  stderr_file=$(mktemp)
  _stdout=$(PATH="$ROOT/fixtures/bin:$PATH" "$@" 2>"$stderr_file" </dev/null) && _exit=0 || _exit=$?
  _stderr=$(cat "$stderr_file")
  rm -f "$stderr_file"
}

assert_exit() {
  if [ "$_exit" = "$1" ]; then return 0; fi
  printf '    expected exit %s, got %s\n' "$1" "$_exit" >&2
  printf '    actual stderr:\n%s\n' "$_stderr" | sed 's/^/      /' >&2
  return 1
}

assert_stdout_equals() {
  if [ "$_stdout" = "$1" ]; then return 0; fi
  printf '    stdout expected: %s\n' "$1" >&2
  printf '    actual stdout:\n%s\n' "$_stdout" | sed 's/^/      /' >&2
  return 1
}

assert_stdout_empty() {
  if [ -z "$_stdout" ]; then return 0; fi
  printf '    stdout expected empty, got:\n%s\n' "$_stdout" | sed 's/^/      /' >&2
  return 1
}

assert_stderr_contains() {
  if grep -qF -- "$1" <<<"$_stderr"; then return 0; fi
  printf '    stderr missing: %s\n' "$1" >&2
  printf '    actual stderr:\n%s\n' "$_stderr" | sed 's/^/      /' >&2
  return 1
}

# assert_calls N: the stub ran exactly N times.
assert_calls() {
  local n
  n=$(wc -l <"$BIRD_STUB_CALLS" | tr -d '[:space:]')
  if [ "$n" = "$1" ]; then return 0; fi
  printf '    expected %s bird call(s), got %s:\n' "$1" "$n" >&2
  sed 's/^/      /' "$BIRD_STUB_CALLS" >&2
  return 1
}

# assert_call_is N ARGV: the stub's Nth call carried exactly ARGV.
assert_call_is() {
  local got
  got=$(sed -n "${1}p" "$BIRD_STUB_CALLS")
  if [ "$got" = "$2" ]; then return 0; fi
  printf '    call %s expected: %s\n' "$1" "$2" >&2
  printf '    call %s actual:   %s\n' "$1" "$got" >&2
  return 1
}

run_test() {
  local name=$1
  reset_stub
  if "$name"; then
    PASSED=$((PASSED + 1))
    printf 'PASS %s\n' "$name"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %s\n' "$name"
  fi
  cleanup_stub
}

# --- Stub tests --------------------------------------------------------------

test_stub__refuses_an_unforced_write_off_a_tty() {
  export BIRD_STUB_LIVE_BODY="$LIVE_OK"
  run_script bird like 1234567890 --output json
  assert_exit 2 || return 1
  assert_stdout_empty || return 1
  assert_stderr_contains '"error":"requires-confirmation"' || return 1
}

# --- write-op-gate.sh tests ----------------------------------------------------

test_gate__needs_the_separator() {
  run_script bash "$GATE" bird like 1234567890
  assert_exit 2 || return 1
  assert_stderr_contains "unexpected pre-\`--\` arg: bird" || return 1
  assert_calls 0 || return 1
}

test_gate__refuses_a_binary_other_than_bird() {
  run_script bash "$GATE" --yes -- xr like 1234567890
  assert_exit 2 || return 1
  assert_stderr_contains "must be \`bird\` (got xr)" || return 1
  assert_calls 0 || return 1
}

test_gate__refuses_a_flag_it_controls() {
  local flag
  for flag in --dry-run --force --yes --output --output=json --json --jsonl; do
    run_script bash "$GATE" --yes -- bird like 1234567890 "$flag"
    assert_exit 2 || return 1
    assert_stderr_contains "refuse to pass-through \`$flag\`" || return 1
  done
  assert_calls 0 || return 1
}

test_gate__names_the_envelope_of_a_rejected_dry_run() {
  export BIRD_STUB_DRYRUN_BODY='{"error":"auth-required","kind":"auth","message":"no credential for oauth2_user","exit_code":77,"meta":{}}'
  export BIRD_STUB_DRYRUN_EXIT=77
  run_script bash "$GATE" --yes -- bird like 1234567890
  assert_exit 1 || return 1
  assert_stdout_empty || return 1
  assert_stderr_contains 'dry-run rejected (exit 77)' || return 1
  assert_stderr_contains 'kind=auth exit_code=77 error=auth-required' || return 1
  assert_calls 1 || return 1
  assert_call_is 1 'like 1234567890 --dry-run --output json --quiet' || return 1
}

test_gate__refuses_a_non_tty_caller_without_yes() {
  export BIRD_STUB_DRYRUN_BODY="$DRYRUN_OK"
  export BIRD_STUB_LIVE_BODY="$LIVE_OK"
  run_script bash "$GATE" -- bird like 1234567890
  assert_exit 3 || return 1
  assert_stdout_empty || return 1
  assert_stderr_contains 'non-TTY caller needs --yes' || return 1
  assert_calls 1 || return 1
}

test_gate__runs_the_confirmed_live_call_with_force() {
  export BIRD_STUB_DRYRUN_BODY="$DRYRUN_OK"
  export BIRD_STUB_LIVE_BODY="$LIVE_OK"
  run_script bash "$GATE" --yes -- bird like 1234567890
  assert_exit 0 || return 1
  assert_stdout_equals "$LIVE_OK" || return 1
  assert_stderr_contains 'preflight ok. About to run:' || return 1
  assert_stderr_contains '"dry_run": true' || return 1
  assert_calls 2 || return 1
  assert_call_is 1 'like 1234567890 --dry-run --output json --quiet' || return 1
  assert_call_is 2 'like 1234567890 --force --output json' || return 1
}

test_gate__passes_text_that_starts_with_a_dash() {
  export BIRD_STUB_DRYRUN_BODY='{"data":{"dry_run":true,"would":{"method":"POST","url":"https://api.x.com/2/tweets","body":{"text":"-1 for this"}},"verb":"tweet"},"meta":{}}'
  export BIRD_STUB_LIVE_BODY='{"data":{"id":"1"},"meta":{}}'
  run_script bash "$GATE" --yes -- bird tweet '-1 for this'
  assert_exit 0 || return 1
  assert_call_is 2 'tweet -1 for this --force --output json' || return 1
}

test_gate__propagates_the_live_exit_code() {
  export BIRD_STUB_DRYRUN_BODY="$DRYRUN_OK"
  export BIRD_STUB_LIVE_BODY='{"error":"rate-limited","kind":"general","message":"HTTP 429","exit_code":3,"meta":{}}'
  export BIRD_STUB_LIVE_EXIT=3
  run_script bash "$GATE" --yes -- bird like 1234567890
  assert_exit 3 || return 1
  assert_stdout_empty || return 1
  assert_stderr_contains '"error":"rate-limited"' || return 1
}

test_gate__keeps_no_preflight_file_at_a_fixed_path() {
  local fixed=/tmp/write-op-gate.preflight.err
  if [ -e "$fixed" ]; then
    printf '    skipped: %s exists from an earlier run; remove it to run this test\n' "$fixed" >&2
    return 0
  fi
  export BIRD_STUB_DRYRUN_BODY='{"error":"invalid-tweet-id","kind":"usage","message":"not a post id","exit_code":2,"meta":{}}'
  export BIRD_STUB_DRYRUN_EXIT=2
  run_script bash "$GATE" --yes -- bird like nope
  assert_exit 1 || return 1
  if [ -e "$fixed" ]; then
    printf '    the gate wrote %s\n' "$fixed" >&2
    rm -f "$fixed"
    return 1
  fi
}

# --- Runner --------------------------------------------------------------------

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  run_test "$t"
done

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
