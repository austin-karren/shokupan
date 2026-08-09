#!/bin/bash

# Tests for the loaf CLI, which maintains the Shokupan rice.
#
# No framework on purpose. `loaf heal` runs from Omarchy's post-update.d hook, so
# anything needed to test it would become a dependency of the update path. This
# emits TAP and follows the shape of Omarchy's own test/omarchy-cli-test.sh.
#
# Every test builds a throwaway home under $BUILD and points LOAF_HOME at it, so
# nothing here can touch the real one. `pacman` and the Omarchy tree are stubbed;
# `git` and `stow` are real, because what they do to a fixture is exactly what
# they would do to the machine.
#
# Run: test/loaf-test.sh

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

tests=0
failures=0

pass() {
  tests=$((tests + 1))
  printf 'ok %d - %s\n' "$tests" "$1"
}

fail() {
  tests=$((tests + 1))
  failures=$((failures + 1))
  printf 'not ok %d - %s\n' "$tests" "$1"
  local detail
  for detail in "${@:2}"; do printf '  # %s\n' "$detail"; done
}

assert_contains() {
  if [[ $2 == *"$3"* ]]; then
    pass "$1"
  else
    fail "$1" "expected to find: $3" "in output: ${2:-<empty>}"
  fi
}

assert_not_contains() {
  if [[ $2 != *"$3"* ]]; then
    pass "$1"
  else
    fail "$1" "expected NOT to find: $3" "in output: $2"
  fi
}

assert_equals() {
  if [[ $2 == "$3" ]]; then
    pass "$1"
  else
    fail "$1" "expected: $3" "actual:   $2"
  fi
}

assert_symlink() {
  if [[ -L $2 ]]; then
    pass "$1"
  else
    fail "$1" "not a symlink: $2"
  fi
}

assert_file_exists() {
  if [[ -e $2 ]]; then
    pass "$1"
  else
    fail "$1" "missing: $2"
  fi
}

# ---------------------------------------------------------
# Fixture
# ---------------------------------------------------------

# Builds a complete fake machine: a home, a rice repo inside it with one tracked
# config file, a stubbed Omarchy checkout carrying the bridge's CachyOS
# adaptations, and a stubbed pacman that reports every package installed.
# Returns the home path on stdout.
make_home() {
  # mktemp, not a counter: this function is called as $(make_home), so it runs in
  # a subshell and any counter it incremented would be discarded — every fixture
  # would silently be the same directory, and state would leak between tests.
  local home
  home=$(mktemp -d "$BUILD/home-XXXXXX")

  # Everything in here is setup noise, and this function communicates by echoing
  # the home path — so a stray line of git output would be captured as part of
  # the path by the caller. Silence the lot, and echo the path outside the block.
  {
    mkdir -p "$home/.config/hypr" "$home/.local/state"

  # The rice repo
    local repo="$home/shokupan"
    mkdir -p "$repo/.config/hypr" "$repo/packages" "$repo/migrations"
    echo "# tracked config" >"$repo/.config/hypr/looknfeel.conf"
    printf 'bat\n' >"$repo/packages/chosen.packages"
    # Mirrors the real repo: without this, stow symlinks packages/ and
    # migrations/ into the fixture home and doctor correctly reports them as
    # leaks — a fixture artefact rather than the condition under test.
    printf '^/packages$\n^/migrations$\n^/CONTEXT\\.md$\n^/docs$\n' \
      >"$repo/.stow-local-ignore"
    git -C "$repo" init -q 2>/dev/null
    git -C "$repo" config user.email test@example.com
    git -C "$repo" config user.name test
    git -C "$repo" add -A
    git -C "$repo" commit -qm fixture

  # The Omarchy checkout, with the bridge adaptations applied
    local omarchy="$home/.local/share/omarchy"
    mkdir -p "$omarchy/install/preflight" "$omarchy/bin"
    git -C "$omarchy" init -q 2>/dev/null
    printf 'eza\n' >"$omarchy/install/omarchy-base.packages" # tldr correctly absent
    printf 'run_logged other.sh\n' >"$omarchy/install/preflight/all.sh"
    git -C "$omarchy" add -A 2>/dev/null
    git -C "$omarchy" -c user.email=t@e.c -c user.name=t commit -qm base 2>/dev/null

  # The bridge, with the ADR-0001 path fix applied
    mkdir -p "$home/omarchy-on-cachyos/bin"
    # Single quotes on purpose: doctor greps these files for the literal string
    # SCRIPT_DIR/../omarchy, so expanding it here would defeat the test.
    # shellcheck disable=SC2016
    printf 'TARGET_DIR="$SCRIPT_DIR/../omarchy"\n' >"$home/omarchy-on-cachyos/bin/fetch-omarchy.sh"
    # shellcheck disable=SC2016
    printf 'OMARCHY_DIR="$SCRIPT_DIR/../omarchy"\n' >"$home/omarchy-on-cachyos/bin/install-omarchy-on-cachyos.sh"
  } >/dev/null 2>&1

  echo "$home"
}

# Stubbed pacman, so tests never consult the real package database.
mkdir -p "$BUILD/stub"
cat >"$BUILD/stub/pacman" <<'STUB'
#!/bin/bash
case "$1" in
  -Qq) exit 0 ;;    # every package is installed
  -Qqe) echo bat ;; # the record
esac
STUB
chmod +x "$BUILD/stub/pacman"

# Run a rice command against a fixture home.
loaf_run() {
  local home=$1 cmd=$2
  shift 2
  LOAF_HOME="$home" LOAF_ROOT="$home/shokupan" \
    OMARCHY_PATH="$home/.local/share/omarchy" \
    BRIDGE_ROOT="$home/omarchy-on-cachyos" \
    XDG_STATE_HOME="$home/.local/state" \
    PATH="$BUILD/stub:$ROOT/.local/bin:$PATH" \
    "loaf-$cmd" "$@" 2>&1
}

# ---------------------------------------------------------
# doctor
# ---------------------------------------------------------

home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)

out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: clean fixture reports no problems" "$out" "No problems"
assert_equals "doctor: clean fixture exits 0" "$status" "0"
assert_contains "doctor: confirms bridge patch intact" "$out" "path fix intact"
assert_contains "doctor: confirms cachyos adaptations intact" "$out" "adaptations intact"

# A displaced symlink — the failure the whole thing exists for. Note git stays
# clean throughout, which is why nothing else would catch this.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
rm "$home/.config/hypr/looknfeel.conf"
echo "upstream default" >"$home/.config/hypr/looknfeel.conf"

out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: detects a displaced symlink" "$out" "replaced by real files"
assert_equals "doctor: exits non-zero on drift" "$status" "1"

# A repo-only path leaked into $HOME by stow
home=$(make_home)
touch "$home/CONTEXT.md"
out=$(loaf_run "$home" doctor)
assert_contains "doctor: detects a leaked repo-only path" "$out" "repo-only path"

# A reverted CachyOS adaptation
home=$(make_home)
printf 'tldr\n' >>"$home/.local/share/omarchy/install/omarchy-base.packages"
out=$(loaf_run "$home" doctor)
assert_contains "doctor: detects a reverted bridge adaptation" "$out" "conflicts with tealdeer"

# The stale clone ADR-0001 warns about
home=$(make_home)
mkdir -p "$home/omarchy"
out=$(loaf_run "$home" doctor)
assert_contains "doctor: detects the stale ~/omarchy clone" "$out" "stale clone"

# Read-only by construction: a dirty fixture must be unchanged afterwards.
home=$(make_home)
touch "$home/CONTEXT.md"
before=$(find "$home" -not -path '*/.git/*' | sort | md5sum)
loaf_run "$home" doctor >/dev/null
after=$(find "$home" -not -path '*/.git/*' | sort | md5sum)
assert_equals "doctor: changes nothing on disk" "$before" "$after"

# ---------------------------------------------------------
# heal
# ---------------------------------------------------------

# The critical one. A bug here costs real data, so it is asserted directly:
# the displaced file must still exist, with its contents, after healing.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
rm "$home/.config/hypr/looknfeel.conf"
echo "upstream default" >"$home/.config/hypr/looknfeel.conf"

out=$(loaf_run "$home" heal)
assert_symlink "heal: restores the displaced symlink" "$home/.config/hypr/looknfeel.conf"
displaced=$(find "$home/.config/hypr" -name 'looknfeel.conf.displaced.*' | head -1)
assert_file_exists "heal: NEVER deletes the file it displaced" "$displaced"
assert_equals "heal: displaced file keeps its contents" "$(cat "$displaced" 2>/dev/null)" "upstream default"
assert_equals "heal: restored symlink points at the repo" \
  "$(cat "$home/.config/hypr/looknfeel.conf")" "# tracked config"

# Dry run must not touch anything
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
rm "$home/.config/hypr/looknfeel.conf"
echo "upstream default" >"$home/.config/hypr/looknfeel.conf"
before=$(find "$home" -not -path '*/.git/*' | sort | md5sum)
out=$(loaf_run "$home" heal --dry-run)
after=$(find "$home" -not -path '*/.git/*' | sort | md5sum)
assert_equals "heal: --dry-run changes nothing" "$before" "$after"
assert_contains "heal: --dry-run still reports what it would do" "$out" "would restore"

# Migrations: applied once, recorded, never re-applied
home=$(make_home)
cat >"$home/shokupan/migrations/1000000000.sh" <<'M'
echo "test migration"
echo ran >>"$LOAF_HOME/migration-ran"
M
out=$(loaf_run "$home" heal)
assert_contains "heal: applies a pending migration" "$out" "applied 1000000000.sh"
assert_equals "heal: migration ran exactly once" "$(wc -l <"$home/migration-ran")" "1"

out=$(loaf_run "$home" heal)
assert_contains "heal: second run reports none pending" "$out" "none pending"
assert_equals "heal: migration still ran only once" "$(wc -l <"$home/migration-ran")" "1"
assert_contains "heal: records the migration in the ledger" \
  "$(cat "$home/.local/state/loaf/applied")" "1000000000.sh"

# A failing migration must not be recorded, so it retries
home=$(make_home)
printf 'exit 1\n' >"$home/shokupan/migrations/1000000001.sh"
out=$(loaf_run "$home" heal)
status=$?
assert_contains "heal: reports a failed migration" "$out" "will retry"
assert_equals "heal: exits non-zero when a migration fails" "$status" "1"
assert_not_contains "heal: does NOT record a failed migration" \
  "$(cat "$home/.local/state/loaf/applied" 2>/dev/null)" "1000000001.sh"

# Idempotence: healing a healthy machine is a no-op
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
loaf_run "$home" heal >/dev/null
before=$(find "$home" -not -path '*/.git/*' -not -name last-heal | sort | md5sum)
out=$(loaf_run "$home" heal)
after=$(find "$home" -not -path '*/.git/*' -not -name last-heal | sort | md5sum)
assert_equals "heal: is idempotent" "$before" "$after"
assert_contains "heal: says so" "$out" "Nothing to heal"

# ---------------------------------------------------------
# dispatch
# ---------------------------------------------------------

home=$(make_home)
out=$(LOAF_HOME="$home" PATH="$ROOT/.local/bin:$PATH" loaf 2>&1)
assert_contains "loaf: lists doctor" "$out" "doctor"
assert_contains "loaf: lists heal" "$out" "heal"
assert_contains "loaf: shows summaries from the loaf:summary= line" "$out" "without changing anything"

out=$(LOAF_HOME="$home" PATH="$ROOT/.local/bin:$PATH" loaf nonesuch 2>&1)
status=$?
assert_contains "loaf: rejects an unknown command" "$out" "no such command"
assert_equals "loaf: exits non-zero on an unknown command" "$status" "1"

# ---------------------------------------------------------
# no stale command name
# ---------------------------------------------------------

# The CLI used to carry the old name, and the rename left seven separate stale
# strings that only turned up by reading output — a usage line, a prefix strip,
# and several suggestions pointing at a command that no longer exists, including
# one in the post-update hook. Nothing else would have caught them.
#
# This comment deliberately avoids spelling the old command forms, since the
# check below greps every tracked file and would otherwise match itself.
#
# Only the command forms are checked. The bare word "rice" is still correct
# English here: CONTEXT.md defines it as the common noun for any customized
# desktop, so prose like "the rice" and "this rice's own commands" must survive.
stale=()
while IFS= read -r hit; do
  stale+=("$hit")
done < <(
  cd "$ROOT" && git ls-files |
    xargs grep -nE "rice (doctor|heal|packages)|rice-(doctor|heal|packages)|RICE_[A-Z]" 2>/dev/null
)

if ((${#stale[@]})); then
  fail "no stale 'rice' command names remain" "${stale[@]}"
else
  pass "no stale 'rice' command names remain"
fi

# ---------------------------------------------------------
# repo-only paths
# ---------------------------------------------------------

# .stow-local-ignore and the scripts' REPO_ONLY answer the same question from
# opposite ends: what is repo furniture rather than config. When they disagree,
# doctor reports a file as missing that stow was never going to install — which
# is exactly what happened when test/ was added to one and not the other.
missing_from_scripts=()
while IFS= read -r line; do
  # Only the top-level anchored entries; the rest are Stow's own defaults.
  [[ $line =~ ^\^/([A-Za-z_.\\]+)\$$ ]] || continue
  name=${BASH_REMATCH[1]//\\/}
  for s in loaf-doctor loaf-heal; do
    grep -q "REPO_ONLY=.*${name%%.*}" "$ROOT/.local/bin/$s" ||
      missing_from_scripts+=("$name missing from $s")
  done
done <"$ROOT/.stow-local-ignore"

if ((${#missing_from_scripts[@]})); then
  fail "repo-only lists agree between .stow-local-ignore and the scripts" \
    "${missing_from_scripts[@]}"
else
  pass "repo-only lists agree between .stow-local-ignore and the scripts"
fi

# ---------------------------------------------------------
# menu extension
# ---------------------------------------------------------
#
# The Omarchy menu rows we add are icon-plus-label, and the icons are Nerd Font
# codepoints in the U+E000-F8FF private use area. Those do not survive every
# editing path — a round trip through the wrong tool silently empties some of
# them while leaving others intact. Nothing reports it: the shell renders a row
# with a blank icon column and no error, so the first notice is visual.
#
# Deliberately a presence check, not a codepoint check. Which glyph an entry
# should carry is a design decision that belongs in the file's own comments;
# what a test can usefully hold is that none of them silently became nothing.
menu_jsonc=$ROOT/.config/omarchy/extensions/omarchy-menu.jsonc

if [[ -f $menu_jsonc ]]; then
  # Entry lines only — the header comments discuss "icon" in prose.
  rows=$(grep -c '^  "[a-z][a-z.-]*": {"icon":' "$menu_jsonc")
  blank=$(grep -c '^  "[a-z][a-z.-]*": {"icon":"",' "$menu_jsonc")

  assert_equals "menu: every entry carries a glyph" "$blank" "0"
  # A floor, not an equality: adding a row should not have to touch this test,
  # but the file emptying out or losing its shape should still be caught.
  if ((rows >= 10)); then
    pass "menu: extension file still defines its entries"
  else
    fail "menu: extension file still defines its entries" "expected: >= 10 rows" "actual:   $rows"
  fi
else
  fail "menu: extension file exists" "missing: $menu_jsonc"
fi

# ---------------------------------------------------------
# lint
# ---------------------------------------------------------
#
# Note the section header above says "lint", not the tool's name: a comment
# consisting of just "# shellcheck" is read as a malformed directive and fails
# the parse.

# Every tracked shell script, not just the rice CLI — these are what keybindings
# and bar modules call, so a quoting bug here breaks the desktop rather than a
# test. Kept at zero findings on purpose: a linter that tolerates known noise
# stops being read, so anything genuinely intentional carries a disable comment
# with a reason rather than being left to accumulate.
if command -v shellcheck &>/dev/null; then
  mapfile -t scripts < <(
    cd "$ROOT" && git ls-files |
      grep -E '^(\.local/bin/|migrations/|test/|\.config/omarchy/hooks/)'
  )
  findings=0
  for s in "${scripts[@]}"; do
    # Match on the shebang rather than an extension: nothing in .local/bin has one.
    head -1 "$ROOT/$s" | grep -q '^#!.*\(bash\|sh\)' || continue
    # Run from the repo root so findings quote a relative path, rather than
    # stripping a prefix afterwards — the obvious ${out//$ROOT\//} is a
    # construct shellcheck itself cannot parse.
    if ! out=$(cd "$ROOT" && shellcheck -f gcc "$s" 2>&1); then
      findings=$((findings + 1))
      printf '  # %s\n' "$out"
    fi
  done
  assert_equals "shellcheck: no findings across every tracked script" "$findings" "0"
else
  # Not a silent skip: an absent linter should be visible in the output.
  printf '# skip - shellcheck not installed, %d checks not run\n' 1
fi

# ---------------------------------------------------------

printf '\n1..%d\n' "$tests"
if ((failures)); then
    printf '\n%d of %d failed.\n' "$failures" "$tests"
  exit 1
fi
printf '\nAll %d passed.\n' "$tests"
