#!/usr/bin/env bash
#
# plan-clash — harden an existing plan via a fixed N-round cross-model critique→fold loop.
#
#   critic (codex / GPT)  --finds-->  adjudicator (claude / opus) --rules+folds--> plan-vN
#
# This script is a DUMB orchestrator. It does NOT review or edit the plan itself.
# All critique comes from a `codex exec` subprocess; all rulings/edits from a
# `claude -p` subprocess. The orchestrator only assembles prompts, invokes the two
# CLIs, validates their outputs, enforces read-only access to the code, and loops.
#
# It IMPROVES a plan; it never CERTIFIES one. There is no pass/fail verdict, no green
# light, no stop condition. The human is the only judge of "good enough".
#
# Usage:
#   run.sh [options] <plan.md> <code_root>
#
# Options:
#   --rounds N            number of critique→fold rounds (default: 2)
#   --source-context DIR  extra read-only dir of source docs (specs, API snapshots)
#   --out FILE            where to write the hardened plan
#                         (default: <plan-dir>/<plan-stem>.hardened.md)
#
# Config (env overrides):
#   CODEX_BIN       path to the codex binary (else auto-resolved)
#   CLAUDE_BIN      path to the claude binary (else `claude` on PATH)
#   CODEX_EFFORT    codex reasoning effort (default: xhigh)
#   ADJ_MODEL       adjudicator model (default: opus)
#   ADJ_EFFORT      adjudicator reasoning effort (default: xhigh)
#   RETAIN_DAYS     prune run dirs older than this many days (default: 7)
#
set -euo pipefail

# ----------------------------------------------------------------------------- config
CODEX_EFFORT="${CODEX_EFFORT:-xhigh}"
ADJ_MODEL="${ADJ_MODEL:-opus}"
ADJ_EFFORT="${ADJ_EFFORT:-xhigh}"
RETAIN_DAYS="${RETAIN_DAYS:-7}"
RUNS_ROOT="$HOME/.plan-clash/runs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------------------------------------------------------- helpers
die()  { printf 'plan-clash: FATAL: %s\n' "$*" >&2; exit 1; }
log()  { printf 'plan-clash: %s\n'        "$*" >&2; }
warn() { printf 'plan-clash: WARN: %s\n'  "$*" >&2; }

resolve_codex() {
  if [ -n "${CODEX_BIN:-}" ]; then [ -x "$CODEX_BIN" ] && { echo "$CODEX_BIN"; return 0; }; fi
  if command -v codex >/dev/null 2>&1; then command -v codex; return 0; fi
  local bundle="/Applications/Codex.app/Contents/Resources/codex"
  [ -x "$bundle" ] && { echo "$bundle"; return 0; }
  local g
  for g in "$HOME/.vscode/extensions/openai.chatgpt-"*/binaries/codex \
           "$HOME/.cursor/extensions/openai.chatgpt-"*/binaries/codex; do
    [ -x "$g" ] && { echo "$g"; return 0; }
  done
  return 1
}

# A content-level, CODE_ROOT-scoped fingerprint — the read-only-by-assertion tripwire.
# Scoped to the code_root subtree (pathspec '-- .'), NOT the whole enclosing repo, so that
# (a) it matches the workers' real write scope (codex --cd / claude --add-dir are code_root) and
# (b) concurrent edits elsewhere in a parent repo don't false-abort a long run.
# Content-aware: HEAD + porcelain status codes + a hash of the tracked working-tree/staged diff +
# per-file hashes of untracked files. So an in-place edit of an already-dirty or untracked file
# (which porcelain status codes alone would NOT reveal) still changes the fingerprint.
repo_fingerprint() {
  local root="$1"
  git -C "$root" rev-parse HEAD
  ( cd "$root"
    git status --porcelain -- . | LC_ALL=C sort
    printf 'diff-hash: '; { git diff -- .; git diff --cached -- .; } | git hash-object --stdin
    git ls-files --others --exclude-standard -- . | LC_ALL=C sort | while IFS= read -r f; do
      printf '?? %s %s\n' "$(git hash-object "$f" 2>/dev/null || echo MISSING)" "$f"
    done
  )
}

# ----------------------------------------------------------------------------- args
ROUNDS=2
SOURCE_CONTEXT=""
OUT=""
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --rounds)         ROUNDS="${2:?--rounds needs a value}"; shift 2 ;;
    --source-context) SOURCE_CONTEXT="${2:?--source-context needs a value}"; shift 2 ;;
    --out)            OUT="${2:?--out needs a value}"; shift 2 ;;
    -h|--help)        sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*)              die "unknown option: $1" ;;
    *)                POSITIONAL+=("$1"); shift ;;
  esac
done
set -- ${POSITIONAL[@]+"${POSITIONAL[@]}"}
[ $# -eq 2 ] || die "usage: run.sh [options] <plan.md> <code_root>  (got $# positional args)"
PLAN_IN="$1"
CODE_ROOT="$2"

case "$ROUNDS" in (*[!0-9]*|"") die "--rounds must be a positive integer";; esac
[ "$ROUNDS" -ge 1 ] || die "--rounds must be >= 1"

# ----------------------------------------------------------------------------- preflight
log "preflight..."
CODEX_BIN_RESOLVED="$(resolve_codex)" || die "codex binary not found. Install codex-cli and log in, or set CODEX_BIN=/path/to/codex."
CODEX_BIN="$CODEX_BIN_RESOLVED"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || true)}"
[ -n "$CLAUDE_BIN" ] && [ -x "$CLAUDE_BIN" ] || die "claude binary not found. Install Claude Code, or set CLAUDE_BIN=/path/to/claude."
command -v jq      >/dev/null 2>&1 || die "jq not found (brew install jq)."
command -v openssl >/dev/null 2>&1 || die "openssl not found."
command -v git     >/dev/null 2>&1 || die "git not found."

[ -f "$PLAN_IN" ] || die "plan not found: $PLAN_IN"
[ -d "$CODE_ROOT" ] || die "code_root not a directory: $CODE_ROOT"
git -C "$CODE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || die "code_root is not a git repo: $CODE_ROOT (the read-only assertion needs git; run 'git init' there if appropriate)."
if [ -n "$SOURCE_CONTEXT" ]; then [ -d "$SOURCE_CONTEXT" ] || die "--source-context not a directory: $SOURCE_CONTEXT"; fi

# We want the children to bill the CLI subscriptions, not the metered API. Surface, don't silently fix.
[ -n "${ANTHROPIC_API_KEY:-}" ] && warn "ANTHROPIC_API_KEY is set; it will be unset for the adjudicator subprocess (subscription billing)."
[ -n "${OPENAI_API_KEY:-}" ]    && warn "OPENAI_API_KEY is set; it will be unset for the critic subprocess (subscription billing)."

PLAN_IN_ABS="$(cd "$(dirname "$PLAN_IN")" && pwd)/$(basename "$PLAN_IN")"
CODE_ROOT="$(cd "$CODE_ROOT" && pwd)"
[ -n "$SOURCE_CONTEXT" ] && SOURCE_CONTEXT="$(cd "$SOURCE_CONTEXT" && pwd)"
PLAN_DIR="$(dirname "$PLAN_IN_ABS")"
PLAN_BASE="$(basename "$PLAN_IN_ABS")"
PLAN_STEM="${PLAN_BASE%.md}"
[ -z "$OUT" ] && OUT="$PLAN_DIR/$PLAN_STEM.hardened.md"

# optional --add-dir args (portable empty-array expansion for bash 3.2)
CODEX_ADD=(); CLAUDE_ADD=()
if [ -n "$SOURCE_CONTEXT" ]; then CODEX_ADD=(--add-dir "$SOURCE_CONTEXT"); CLAUDE_ADD=(--add-dir "$SOURCE_CONTEXT"); fi

# ----------------------------------------------------------------------------- workdir + GC
mkdir -p "$RUNS_ROOT"
# prune cold runs (older than RETAIN_DAYS); never auto-delete the current one.
find "$RUNS_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime "+$RETAIN_DAYS" -exec rm -rf {} + 2>/dev/null || true

STAMP="$(date +%Y-%m-%d-%H%M%S)"
SLUG="$(printf '%s' "$PLAN_STEM" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-60)"
WORKDIR="$RUNS_ROOT/$STAMP-$SLUG"
mkdir -p "$WORKDIR/prompts" "$WORKDIR/raw" "$WORKDIR/schemas"
cp "$SCRIPT_DIR/schemas/review.schema.json" "$WORKDIR/schemas/review.schema.json"
cp "$PLAN_IN_ABS" "$WORKDIR/plan-v0.md"
NONCE="$(openssl rand -hex 8)"
METRICS="$WORKDIR/.metrics.tsv"   # round \t label \t seconds \t cost \t turns
: > "$METRICS"
START=$SECONDS

log "workdir:    $WORKDIR"
log "plan:       $PLAN_IN_ABS ($(wc -c < "$PLAN_IN_ABS" | tr -d ' ') bytes)"
log "code_root:  $CODE_ROOT @ $(git -C "$CODE_ROOT" rev-parse --short HEAD)"
log "context:    ${SOURCE_CONTEXT:-NONE (code-only)}"
log "rounds:     $ROUNDS  |  critic: codex(effort=$CODEX_EFFORT)  adjudicator: claude($ADJ_MODEL, effort=$ADJ_EFFORT)"

# ----------------------------------------------------------------------------- subprocess wrappers
# critic: review $1 (a plan file), emit clean JSON to $2
run_critic() {
  local plan_file="$1" out_json="$2" prompt_file="$3" log_file="$4"
  {
    cat "$SCRIPT_DIR/prompts/critic.md"
    if [ -n "$SOURCE_CONTEXT" ]; then
      printf '\nSource-context docs are available at the additional read-only path provided; consult them to verify external claims.\n'
    fi
    printf '\nThe plan to review is in the UNTRUSTED block below.\n\n<<UNTRUSTED-%s>>\n' "$NONCE"
    cat "$plan_file"
    printf '\n<</UNTRUSTED-%s>>\n' "$NONCE"
  } > "$prompt_file"

  ( unset ANTHROPIC_API_KEY OPENAI_API_KEY
    "$CODEX_BIN" exec \
      -c model_reasoning_effort="$CODEX_EFFORT" \
      --sandbox read-only \
      --skip-git-repo-check \
      --cd "$CODE_ROOT" \
      ${CODEX_ADD[@]+"${CODEX_ADD[@]}"} \
      --output-schema "$WORKDIR/schemas/review.schema.json" \
      --output-last-message "$out_json" \
      --json \
      < "$prompt_file" > "$log_file" 2>&1
  ) || die "codex critic exited non-zero (see ${log_file#$WORKDIR/})"

  [ -s "$out_json" ] || die "codex produced no review JSON (see ${log_file#$WORKDIR/})"
  jq -e '.findings | type == "array"' "$out_json" >/dev/null 2>&1 \
    || die "critic output is not valid review JSON (see ${out_json#$WORKDIR/})"
}

# adjudicator: rule on review $review, fold into plan copy $plan (edited in place), write $decisions
run_adjudicator() {
  local r="$1" plan="$2" decisions="$3" review="$4" prompt_file="$5"
  # plan/decisions are interpolated into the prompt via sed and must be plain basenames (no sed metachars).
  case "$plan$decisions" in (*[!A-Za-z0-9._-]*) die "internal: unsafe filename for prompt templating ($plan / $decisions)";; esac
  sed -e "s/{{PLAN_FILE}}/$plan/g" \
      -e "s/{{DECISIONS_FILE}}/$decisions/g" \
      -e "s/{{ROUND}}/$r/g" \
      "$SCRIPT_DIR/prompts/adjudicator.md" > "$prompt_file"
  {
    printf '\n<<UNTRUSTED-%s>>\n' "$NONCE"
    cat "$review"
    printf '\n<</UNTRUSTED-%s>>\n' "$NONCE"
  } >> "$prompt_file"

  # snapshot CODE_ROOT before; assert byte-identical after.
  repo_fingerprint "$CODE_ROOT" > "$WORKDIR/.snap-before-$r"
  # the review is the adjudicator's INPUT; it must not rewrite it (that would defeat the bijection gate).
  local review_sig; review_sig="$(git hash-object "$review")"

  ( cd "$WORKDIR"
    unset ANTHROPIC_API_KEY OPENAI_API_KEY
    "$CLAUDE_BIN" -p \
      --model "$ADJ_MODEL" \
      --effort "$ADJ_EFFORT" \
      --output-format json \
      --add-dir "$CODE_ROOT" \
      ${CLAUDE_ADD[@]+"${CLAUDE_ADD[@]}"} \
      --allowedTools "Read,Grep,Glob,Edit,Write" \
      < "prompts/$(basename "$prompt_file")" \
      > "raw/adj-$r.json" 2> "raw/adj-$r.err"
  ) || die "claude adjudicator exited non-zero (see raw/adj-$r.err)"

  [ "$(git hash-object "$review")" = "$review_sig" ] \
    || die "adjudicator modified its input review file ($review) — refusing (bijection integrity compromised)."

  repo_fingerprint "$CODE_ROOT" > "$WORKDIR/.snap-after-$r"
  if ! diff "$WORKDIR/.snap-before-$r" "$WORKDIR/.snap-after-$r" >/dev/null; then
    echo "plan-clash: FATAL: CODE_ROOT changed during round $r (adjudicator write, or your own concurrent edit inside $CODE_ROOT). Fingerprint diff:" >&2
    diff "$WORKDIR/.snap-before-$r" "$WORKDIR/.snap-after-$r" >&2 || true
    echo "plan-clash: CODE_ROOT was NOT auto-restored — it may hold your own uncommitted work. Inspect and revert manually." >&2
    exit 1
  fi

  # adjudicator self-reported status (claude --output-format json).
  # Positive assertion so unparseable/empty JSON also fails (jq -e errors -> die), not only is_error:true.
  jq -e '.is_error == false' "$WORKDIR/raw/adj-$r.json" >/dev/null 2>&1 \
    || die "adjudicator did not report clean success (is_error true, or unparseable JSON — see raw/adj-$r.json)"
}

# ----------------------------------------------------------------------------- per-round validation
validate_round() {
  local r="$1" prev="$2" cur="$3" review="$4" decisions="$5"

  jq empty "$decisions" 2>/dev/null || die "round $r: decisions JSON invalid (${decisions#$WORKDIR/})"
  [ -f "$cur" ] || die "round $r: hardened plan copy missing ($cur)"

  # bijection: review finding ids === decision finding_ids (each exactly once; none invented/dropped/duplicated)
  if ! diff <(jq -r '.findings[].id'    "$review"    | LC_ALL=C sort) \
            <(jq -r '.decisions[].finding_id' "$decisions" | LC_ALL=C sort) >/dev/null; then
    echo "plan-clash: round $r: decisions are not a bijection over findings:" >&2
    diff <(jq -r '.findings[].id' "$review" | LC_ALL=C sort) \
         <(jq -r '.decisions[].finding_id' "$decisions" | LC_ALL=C sort) >&2 || true
    die "round $r: coverage check failed"
  fi

  # every ruling needs a reason (hard); accept/partial should carry a plan_edit (warn).
  jq -e '[.decisions[] | select((.reason // "") == "")] | length == 0' "$decisions" >/dev/null \
    || die "round $r: a decision is missing a reason"
  if ! jq -e '[.decisions[] | select((.ruling=="accept" or .ruling=="partial") and ((.plan_edit // "none")=="none" or (.plan_edit // "")==""))] | length == 0' "$decisions" >/dev/null; then
    warn "round $r: an accept/partial ruling has no plan_edit description (folded edit may be missing)."
  fi

  # size band: a >40% shrink signals truncation or an off-spec full rewrite.
  local pb cb; pb="$(wc -c < "$prev")"; cb="$(wc -c < "$cur")"
  [ $((cb * 10)) -ge $((pb * 6)) ] || die "round $r: plan shrank >40% ($pb→$cb bytes) — truncation/rewrite suspected"

  # fold integrity: claimed edits must actually land; a rejected-only round must not silently rewrite the plan.
  local n_edits; n_edits="$(jq -r '[.decisions[] | select((.ruling=="accept" or .ruling=="partial") and ((.plan_edit // "none")!="none") and ((.plan_edit // "")!=""))] | length' "$decisions")"
  if [ "$n_edits" -gt 0 ]; then
    if diff -q "$prev" "$cur" >/dev/null; then
      die "round $r: $n_edits accept/partial ruling(s) claim a plan_edit, but plan-v$r is byte-identical to the prior version — folds did not land"
    fi
  elif ! diff -q "$prev" "$cur" >/dev/null; then
    warn "round $r: no accept/partial carried a plan_edit, yet the plan changed — unexpected edit."
  fi

  # structural hygiene — only flag missing frontmatter if the ORIGINAL plan actually had it.
  if head -n1 "$WORKDIR/plan-v0.md" | grep -q '^---'; then
    head -n1 "$cur" | grep -q '^---' || warn "round $r: hardened plan no longer starts with frontmatter (original had it)."
  fi
  grep -qi 'contested concerns' "$cur" && warn "round $r: hardened plan contains a 'Contested concerns' section (rejected findings should not leak into the plan)."

  return 0
}

# ----------------------------------------------------------------------------- the loop
for r in $(seq 1 "$ROUNDS"); do
  prev=$((r - 1))
  log "=== round $r/$ROUNDS: critic (codex) reviewing plan-v$prev.md ==="
  t0=$SECONDS
  run_critic "$WORKDIR/plan-v$prev.md" "$WORKDIR/review-$r.json" \
             "$WORKDIR/prompts/critic-$r.md" "$WORKDIR/raw/critic-$r.log"
  printf '%s\tcritic\t%s\tsubscription\t-\n' "$r" "$((SECONDS - t0))" >> "$METRICS"
  nf=$(jq -r '.findings | length' "$WORKDIR/review-$r.json")
  log "round $r: critic verdict $(jq -r '.verdict' "$WORKDIR/review-$r.json"), $nf findings"

  cp "$WORKDIR/plan-v$prev.md" "$WORKDIR/plan-v$r.md"
  log "=== round $r/$ROUNDS: adjudicator (claude) ruling + folding into plan-v$r.md ==="
  t0=$SECONDS
  run_adjudicator "$r" "plan-v$r.md" "decisions-$r.json" \
                  "$WORKDIR/review-$r.json" "$WORKDIR/prompts/adj-$r.md"
  adj_dt=$((SECONDS - t0))
  cost=$(jq -r '.total_cost_usd // "?"' "$WORKDIR/raw/adj-$r.json" 2>/dev/null || echo "?")
  turns=$(jq -r '.num_turns // "?"'     "$WORKDIR/raw/adj-$r.json" 2>/dev/null || echo "?")
  printf '%s\tadjudicator\t%s\t%s\t%s\n' "$r" "$adj_dt" "$cost" "$turns" >> "$METRICS"

  validate_round "$r" "$WORKDIR/plan-v$prev.md" "$WORKDIR/plan-v$r.md" \
                 "$WORKDIR/review-$r.json" "$WORKDIR/decisions-$r.json"
  log "round $r: folded — $(jq -r '[.decisions[]|select(.ruling=="accept")]|length' "$WORKDIR/decisions-$r.json") accept / $(jq -r '[.decisions[]|select(.ruling=="partial")]|length' "$WORKDIR/decisions-$r.json") partial / $(jq -r '[.decisions[]|select(.ruling=="reject")]|length' "$WORKDIR/decisions-$r.json") reject  ($(wc -c < "$WORKDIR/plan-v$r.md" | tr -d ' ') bytes)"
done

# ----------------------------------------------------------------------------- final informational critic read
log "=== final critic read on plan-v$ROUNDS.md (informational; gates nothing) ==="
t0=$SECONDS
run_critic "$WORKDIR/plan-v$ROUNDS.md" "$WORKDIR/final-review.json" \
           "$WORKDIR/prompts/final-critic.md" "$WORKDIR/raw/final-critic.log"
printf 'final\tcritic\t%s\tsubscription\t-\n' "$((SECONDS - t0))" >> "$METRICS"

# ----------------------------------------------------------------------------- synthesize artifacts (mechanical)
DLOG="$WORKDIR/decision-log.md"
{
  printf '# Decision log — %s\n\n' "$PLAN_BASE"
  printf '_Per-finding trail. This is the real product of the run; the hardened plan is the summary._\n'
} > "$DLOG"
for r in $(seq 1 "$ROUNDS"); do
  rev="$WORKDIR/review-$r.json"; dec="$WORKDIR/decisions-$r.json"
  {
    printf '\n## Round %s\n\n' "$r"
    printf '**Critic verdict:** %s — %s findings (P0:%s / P1:%s / P2:%s)\n' \
      "$(jq -r '.verdict' "$rev")" "$(jq -r '.findings|length' "$rev")" \
      "$(jq -r '[.findings[]|select(.severity=="P0")]|length' "$rev")" \
      "$(jq -r '[.findings[]|select(.severity=="P1")]|length' "$rev")" \
      "$(jq -r '[.findings[]|select(.severity=="P2")]|length' "$rev")"
    printf '\n_Plan change summary:_ %s\n' "$(jq -r '.plan_change_summary // "(none)"' "$dec")"
  } >> "$DLOG"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    {
      printf '\n### [%s] %s — %s\n\n' \
        "$(jq -r --arg i "$id" '.findings[]|select(.id==$i)|.severity' "$rev")" \
        "$id" \
        "$(jq -r --arg i "$id" '.findings[]|select(.id==$i)|.title' "$rev")"
      printf -- '- **Critic fix:** %s\n'  "$(jq -r --arg i "$id" '.findings[]|select(.id==$i)|.fix' "$rev")"
      printf -- '- **Ruling:** %s — %s\n' \
        "$(jq -r --arg i "$id" '.decisions[]|select(.finding_id==$i)|.ruling' "$dec")" \
        "$(jq -r --arg i "$id" '.decisions[]|select(.finding_id==$i)|.reason' "$dec")"
      printf -- '- **Plan edit:** %s\n'   "$(jq -r --arg i "$id" '.decisions[]|select(.finding_id==$i)|.plan_edit' "$dec")"
    } >> "$DLOG"
  done < <(jq -r '.findings[].id' "$rev")
done

RESULT="$WORKDIR/RESULT.md"
fr="$WORKDIR/final-review.json"
{
  printf '# plan-clash run — %s\n\n' "$PLAN_BASE"
  printf '**This is NOT a certification.** The plan was hardened over %s round(s); the residual concerns below are a reading aid, not blockers. You decide whether the hardened plan is good enough to adopt.\n\n' "$ROUNDS"
  printf -- '- **Target:** `%s`\n' "$PLAN_IN_ABS"
  printf -- '- **Hardened plan:** `%s`\n' "$OUT"
  printf -- '- **code_root:** `%s` @ `%s`\n' "$CODE_ROOT" "$(git -C "$CODE_ROOT" rev-parse --short HEAD)"
  printf -- '- **source-context:** %s\n' "${SOURCE_CONTEXT:-NONE (code-only)}"
  printf -- '- **run dir:** `%s`\n\n' "$WORKDIR"

  printf '## Blocker trajectory\n\n'
  printf '| Round | Verdict | Findings | P0/P1/P2 | Rulings (acc/part/rej) |\n'
  printf '|---|---|---|---|---|\n'
  for r in $(seq 1 "$ROUNDS"); do
    rev="$WORKDIR/review-$r.json"; dec="$WORKDIR/decisions-$r.json"
    printf '| %s | %s | %s | %s/%s/%s | %s/%s/%s |\n' "$r" \
      "$(jq -r '.verdict' "$rev")" "$(jq -r '.findings|length' "$rev")" \
      "$(jq -r '[.findings[]|select(.severity=="P0")]|length' "$rev")" \
      "$(jq -r '[.findings[]|select(.severity=="P1")]|length' "$rev")" \
      "$(jq -r '[.findings[]|select(.severity=="P2")]|length' "$rev")" \
      "$(jq -r '[.decisions[]|select(.ruling=="accept")]|length' "$dec")" \
      "$(jq -r '[.decisions[]|select(.ruling=="partial")]|length' "$dec")" \
      "$(jq -r '[.decisions[]|select(.ruling=="reject")]|length' "$dec")"
  done
  printf '| final | %s | %s | %s/%s/%s | — (informational) |\n\n' \
    "$(jq -r '.verdict' "$fr")" "$(jq -r '.findings|length' "$fr")" \
    "$(jq -r '[.findings[]|select(.severity=="P0")]|length' "$fr")" \
    "$(jq -r '[.findings[]|select(.severity=="P1")]|length' "$fr")" \
    "$(jq -r '[.findings[]|select(.severity=="P2")]|length' "$fr")"

  printf '## Residual concerns (final critic on the hardened plan — your reading aid, NOT blockers)\n\n'
  jq -r '.findings[] | "\(.severity) **\(.id) — \(.title)**\n  - fix: \(.fix)\n  - evidence: \(.evidence)\n"' "$fr"

  printf '\n## Cost / wall-clock\n\n'
  printf '| Round | Call | Seconds | Cost (USD) | Turns |\n'
  printf '|---|---|---|---|---|\n'
  while IFS=$'\t' read -r rr label secs cst trns; do
    printf '| %s | %s | %s | %s | %s |\n' "$rr" "$label" "$secs" "$cst" "$trns"
  done < "$METRICS"
  printf '\n_End-to-end: %ss. codex critic calls bill the ChatGPT subscription (no USD captured)._\n' "$((SECONDS - START))"
  printf '\nSee `decision-log.md` for the full per-finding trail, `plan-v*.md` for each round, `raw/` for CLI logs.\n'
} > "$RESULT"

# ----------------------------------------------------------------------------- land the deliverable
if [ -e "$OUT" ]; then warn "overwriting existing $OUT"; fi
cp "$WORKDIR/plan-v$ROUNDS.md" "$OUT"

log ""
log "DONE. Hardened plan → $OUT"
log "Full trail (decision-log, RESULT, per-round JSON, logs) → $WORKDIR"
log "Final critic: $(jq -r '.verdict' "$fr") with $(jq -r '.findings|length' "$fr") residual concern(s) — advisory; read RESULT.md and decide."

# stdout: machine-readable pointer for the calling skill
printf '%s\n' "$WORKDIR"
