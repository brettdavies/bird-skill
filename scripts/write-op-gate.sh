#!/usr/bin/env bash
# shellcheck disable=SC2016
# write-op-gate.sh - dry-run + confirm + live wrapper for bird write verbs.
#
# Usage:
#   write-op-gate.sh [--yes] -- bird <write-verb> [args...]
#
# What it does:
#   1. Runs the verb with `--dry-run --output json --quiet` and inspects the envelope.
#   2. If the envelope is an error (kind != "command" success OR exit code != 0), surfaces it and exits non-zero.
#   3. On a TTY, prompts [y/N]. Off-TTY, requires --yes or refuses.
#   4. Execs the verb again with `--output json` (no --dry-run) so the live response lands on stdout.
#
# Exit codes:
#   0  live call succeeded
#   1  dry-run rejected the call (envelope error)
#   2  argv usage error (missing --, missing verb, forbidden flags in args)
#   3  off-TTY without --yes
#   4  user declined the [y/N] prompt
#   *  whatever the live bird call exited with (propagated)
#
# Forbidden in <args>: --dry-run, --force, --yes, --output, --json, --jsonl.
# The script controls these; refusing avoids accidental double-dry-runs or hidden output overrides.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
write-op-gate.sh [--yes] -- bird <write-verb> [args...]

Wraps a bird write op with a --dry-run preflight and explicit confirmation.

Forbidden in <args>: --dry-run --force --yes --output --json --jsonl
EOF
  exit 2
}

YES=0
while (($#)); do
  case "$1" in
    --yes|-y) YES=1; shift ;;
    --) shift; break ;;
    -h|--help) usage ;;
    *) printf 'write-op-gate: unexpected pre-`--` arg: %s\n' "$1" >&2; usage ;;
  esac
done

if (($# < 2)); then
  printf 'write-op-gate: need at least `bird <verb>` after `--`\n' >&2
  usage
fi

if [[ "$1" != "bird" ]]; then
  printf 'write-op-gate: first positional after `--` must be `bird` (got %s)\n' "$1" >&2
  usage
fi

VERB="$2"
shift 2

for arg in "$@"; do
  case "$arg" in
    --dry-run|--force|--yes|--output|--output=*|--json|--jsonl)
      printf 'write-op-gate: refuse to pass-through `%s` - the gate controls it\n' "$arg" >&2
      exit 2
      ;;
  esac
done

JQ_BIN=""
if command -v jaq >/dev/null 2>&1; then
  JQ_BIN=jaq
elif command -v jq >/dev/null 2>&1; then
  JQ_BIN=jq
else
  printf 'write-op-gate: need `jaq` (preferred) or `jq` on PATH\n' >&2
  exit 2
fi

# Preflight: dry-run, capture envelope, never fail-fast on non-zero (we read the kind/exit_code from JSON).
DRY_OUT=""
DRY_ERR=""
DRY_RC=0
DRY_OUT=$(bird "$VERB" "$@" --dry-run --output json --quiet 2>/tmp/write-op-gate.preflight.err) || DRY_RC=$?
DRY_ERR=$(cat /tmp/write-op-gate.preflight.err 2>/dev/null || true)

if (( DRY_RC != 0 )); then
  printf 'write-op-gate: dry-run rejected (exit %d)\n' "$DRY_RC" >&2
  if [[ -n "$DRY_ERR" ]]; then
    printf '%s\n' "$DRY_ERR" | "$JQ_BIN" -r '"  kind=" + (.kind // "?") + " exit_code=" + ((.exit_code // 0) | tostring) + " error=" + (.error // "")' >&2 || printf '%s\n' "$DRY_ERR" >&2
  fi
  exit 1
fi

# Surface what's about to happen.
{
  printf 'write-op-gate: preflight ok. About to run:\n'
  printf '  bird %s' "$VERB"
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
  if [[ -n "$DRY_OUT" ]]; then
    printf 'preflight envelope (data block):\n'
    printf '%s\n' "$DRY_OUT" | "$JQ_BIN" '.data' 2>/dev/null || printf '%s\n' "$DRY_OUT"
  fi
} >&2

# Confirm.
if [[ -t 0 && -t 2 ]]; then
  printf 'Proceed? [y/N] ' >&2
  read -r ANSWER
  case "$ANSWER" in
    y|Y|yes|YES) : ;;
    *) printf 'write-op-gate: declined\n' >&2; exit 4 ;;
  esac
else
  if (( YES != 1 )); then
    printf 'write-op-gate: non-TTY caller needs --yes to proceed\n' >&2
    exit 3
  fi
fi

# Live call. exec replaces the shell so the live exit code is what the caller sees.
exec bird "$VERB" "$@" --output json
