#!/bin/bash

# Tests for the loaf CLI, which maintains the Shokupan rice.
#
# No framework on purpose. `loaf heal` runs from Omarchy's post-update.d hook, so
# anything needed to test it would become a dependency of the update path. This
# emits TAP and follows the shape of Omarchy's own test/omarchy-cli-test.sh.
#
# Every test builds a throwaway home under $BUILD and points LOAF_HOME at it, so
# nothing here can touch the real one. `pacman` and the files doctor reads under
# /etc are stubbed; `git` and `stow` are real, because what they do to a fixture
# is exactly what they would do to the machine.
#
# The /etc stubs matter more than they look. Omarchy became package-backed
# (ADR-0035) and doctor's base checks now assert things about pacman's config and
# NetworkManager's, so a suite reading the real /etc would pass or fail on how the
# machine running it happens to be set up — and would have gone red on the very
# machine whose broken wifi backend prompted the check.
#
# Run: test/loaf-test.sh

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

tests=0
failures=0

# What the stubbed pacman reports for `pacman -Q omarchy`. Declared up here rather
# than beside the stub because the fixture writes it into packages/omarchy.pin, and
# the two agreeing is what makes the pin check pass on a healthy fixture.
STUB_OMARCHY_VERSION='4.0.0.r1046.gd570d99-1'

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
# config file and a version pin matching the stubbed pacman, a stubbed /etc
# holding the three files doctor's base checks read, and a stubbed pacman that
# reports every package installed. Returns the home path on stdout.
#
# The fixture is deliberately the HEALTHY state for every check — a test that
# wants a broken one breaks it explicitly afterwards, so what it is asserting is
# visible at the point of the assertion.
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
    # The healthy state for the debloat manifest is the launcher being absent,
    # which a fresh fixture home already is — so listing one here exercises
    # doctor's debloat check on every clean fixture.
    printf 'HEY\n' >"$repo/packages/removed.webapps"
    # Must match what the stubbed pacman reports for `pacman -Q omarchy`, or every
    # fixture warns about version drift.
    printf '%s\n' "$STUB_OMARCHY_VERSION" >"$repo/packages/omarchy.pin"
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

  # The /etc files doctor's base checks read. There is no Omarchy checkout to
  # build any more — it is a package, and the stubbed pacman reports it.
    mkdir -p "$home/etc/pacman.d"
    # Single quotes on purpose: pacman's own config uses $repo and $arch as its
    # literal placeholders, so expanding them here would not be a pacman.conf.
    # shellcheck disable=SC2016
    printf '[cachyos-znver4]\nServer = https://cdn.cachyos.org/repo/$arch_v4/$repo\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n' \
      >"$home/etc/pacman.conf"
    # shellcheck disable=SC2016  # same: pacman's placeholders, not shell variables
    printf 'Server = https://archlinux.cachyos.org/repo/$repo/os/$arch\n' \
      >"$home/etc/pacman.d/mirrorlist"
    # No [device] stanza: NetworkManager falls back to wpa_supplicant, which is
    # what quattro leaves it on and therefore the healthy default here.
    printf '# Configuration file for NetworkManager.\n' \
      >"$home/etc/NetworkManager.conf"
  } >/dev/null 2>&1

  echo "$home"
}

# Stubbed pacman, so tests never consult the real package database.
#
# `pacman -Q omarchy` reports omarchy-DEV, matching this machine: the real package
# installed here is omarchy-dev, which `Provides: omarchy`, and pacman resolves the
# provide. doctor relies on that, so the stub has to reproduce it rather than
# answering to the plain name.
#
# Everything is installed by default; $STUB_ABSENT names packages that are not, so
# a test can express "the configured wifi backend is missing" without also having
# to describe every package that is present.
mkdir -p "$BUILD/stub"
cat >"$BUILD/stub/pacman" <<STUB
#!/bin/bash
absent=" \${STUB_ABSENT:-} "
case "\$1" in
  -Q)
    [[ \$absent == *" \$2 "* ]] && exit 1
    [[ \$2 == omarchy ]] && echo "omarchy-dev $STUB_OMARCHY_VERSION"
    exit 0
    ;;
  -Qq)
    [[ \$absent == *" \$2 "* ]] && exit 1
    exit 0
    ;;
  -Qqe) echo bat ;; # the record
  -S)
    # loaf-install's writes. Recorded rather than performed, so a test can
    # assert WHAT would have been installed.
    echo "pacman \$*" >>"\${STUB_LOG:-/dev/null}"
    ;;
esac
STUB
chmod +x "$BUILD/stub/pacman"

# Stubbed hyprctl, so doctor's emergency-mode check answers to the test rather
# than to whatever compositor the machine running the suite has. $STUB_HYPR_ERRORS
# is what `configerrors` reports; empty means a clean config.
cat >"$BUILD/stub/hyprctl" <<'STUB'
#!/bin/bash
[[ $1 == configerrors ]] || exit 1
printf '%s' "${STUB_HYPR_ERRORS:-}"
STUB
chmod +x "$BUILD/stub/hyprctl"

# Stubbed sudo: loaf-install prefixes its pacman calls with it when not root.
# Exec the command as-is, so the stubbed pacman is still what runs.
printf '#!/bin/bash\nexec "$@"\n' >"$BUILD/stub/sudo"
chmod +x "$BUILD/stub/sudo"

# Run a rice command against a fixture home.
#
# $OMARCHY_PATH is deliberately NOT set: doctor defaults it to /usr/share/omarchy
# and warns when it points anywhere else, so setting it to a fixture path would
# make every test emit the dev-checkout warning. The one test that wants that
# warning sets it itself.
loaf_run() {
  local home=$1 cmd=$2
  shift 2
  LOAF_HOME="$home" LOAF_ROOT="$home/shokupan" \
    PACMAN_CONF="$home/etc/pacman.conf" \
    MIRRORLIST="$home/etc/pacman.d/mirrorlist" \
    NM_CONF="$home/etc/NetworkManager.conf" \
    STUB_ABSENT="${STUB_ABSENT:-}" \
    STUB_LOG="${STUB_LOG:-}" \
    XDG_STATE_HOME="$home/.local/state" \
    WAYLAND_DISPLAY='' \
    HYPR_RUNTIME_DIR="$home/hypr-runtime" \
    STUB_HYPR_ERRORS="${STUB_HYPR_ERRORS:-}" \
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
assert_contains "doctor: reports the installed omarchy package version" \
  "$out" "package        omarchy $STUB_OMARCHY_VERSION"
assert_contains "doctor: confirms the version pin matches" \
  "$out" "verified against $STUB_OMARCHY_VERSION"
assert_contains "doctor: confirms the CachyOS repos" "$out" "CachyOS repo section(s)"
assert_contains "doctor: confirms the mirrorlist is not Omarchy's" "$out" "none from omarchy.org"
assert_contains "doctor: accepts NetworkManager's default wifi backend" \
  "$out" "NetworkManager default"

# The retired bridge (ADR-0035) took three checks with it, and a package-backed
# Omarchy took a fourth. Asserted by absence: leaving one behind would mean doctor
# reporting on an installer that can no longer run, which is exactly the noise
# ADR-0028 says to delete rather than tolerate.
for gone in "bridge patch" "stale clone" "walker hold" "cachyos patch" "checkout"; do
  assert_not_contains "doctor: no longer reports '$gone'" "$out" "$gone"
done

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

# Omarchy is packages now (ADR-0035), so "the desktop layer is gone" means the
# package is gone rather than a checkout being absent.
home=$(make_home)
out=$(STUB_ABSENT=omarchy loaf_run "$home" doctor)
status=$?
assert_contains "doctor: detects a missing omarchy package" "$out" "no omarchy package installed"
assert_equals "doctor: exits non-zero when omarchy is not installed" "$status" "1"
assert_not_contains "doctor: does not compare a pin against a missing package" \
  "$out" "verified against"

# `omarchy dev link` repoints OMARCHY_PATH at a source checkout. Legitimate, but
# the package version doctor just reported is then not what is running.
#
# Stowed, unlike most fixtures here: this asserts the exit CODE, and an unstowed
# fixture always has uninstalled symlinks to fail on. The stow is what narrows the
# assertion down to the check under test.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
out=$(OMARCHY_PATH="$home/omarchy-src" loaf_run "$home" doctor)
status=$?
assert_contains "doctor: warns when a dev checkout is live instead of the package" \
  "$out" "a dev checkout is live, not the package"
assert_equals "doctor: a dev checkout is a warning, not a failure" "$status" "0"

# The version pin. Compared by equality against the installed package version,
# because quattro's `4.0.0.r1046.gd570d99-1` cannot be meaningfully ordered against
# the old `v3.8.4` shape — which is how the previous sort -V logic came to pick the
# omarchy-v3.8.4-prequattro ROLLBACK tag as the pin.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null) # asserts the exit code
printf '3.8.4\n' >"$home/shokupan/packages/omarchy.pin"
# Committed, not just written: the pin lives in the repo, so leaving it dirty would
# trip doctor's `git` check and this test would pass on the wrong problem.
git -C "$home/shokupan" commit -qam 'pin an older Omarchy' 2>/dev/null
out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: warns when the pin and the installed version differ" \
  "$out" "verified against 3.8.4, Omarchy is $STUB_OMARCHY_VERSION"
assert_equals "doctor: version drift is a warning, not a failure" "$status" "0"

# Comments and blank lines are stripped, so the pin file can explain itself the
# way every other manifest in packages/ does.
home=$(make_home)
printf '# which Omarchy this was verified against\n\n  %s  \n' "$STUB_OMARCHY_VERSION" \
  >"$home/shokupan/packages/omarchy.pin"
out=$(loaf_run "$home" doctor)
assert_contains "doctor: reads a commented pin file" "$out" "verified against $STUB_OMARCHY_VERSION"

home=$(make_home)
rm "$home/shokupan/packages/omarchy.pin"
out=$(loaf_run "$home" doctor)
assert_contains "doctor: warns when nothing records the verified version" \
  "$out" "no packages/omarchy.pin"

# The wifi backend. NetworkManager does not provide the backend it delegates to and
# says nothing when it is absent — the device just reports unavailable and never
# scans. Measured on this machine after quattro removed iwd while the stanza naming
# it stayed behind, which the old check reported as ✓.
home=$(make_home)
printf '[device]\nwifi.backend=iwd\n' >>"$home/etc/NetworkManager.conf"
out=$(STUB_ABSENT=iwd loaf_run "$home" doctor)
status=$?
assert_contains "doctor: fails when the configured wifi backend is not installed" \
  "$out" "wifi.backend=iwd, but iwd is not installed"
assert_equals "doctor: a backendless NetworkManager is a failure, not a warning" "$status" "1"

# The same stanza is fine when the backend is actually there, so a machine that
# deliberately kept iwd is not nagged for it.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null) # asserts the exit code
printf '[device]\nwifi.backend=iwd\n' >>"$home/etc/NetworkManager.conf"
out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: accepts an installed wifi backend" "$out" "wifi backend   iwd"
assert_equals "doctor: an installed backend is not a problem" "$status" "0"

# The mirrorlist. ADR-0035's measured root cause: Omarchy pins a frozen Arch
# snapshot, CachyOS is rolling, and the two skew permanently. Note the fixture's
# pacman.conf still has its [cachyos*] section — the repo list surviving is exactly
# what makes this failure look fine until pacman starts refusing downgrades.
home=$(make_home)
# shellcheck disable=SC2016  # pacman's own $repo/$arch placeholders, kept literal
printf 'Server = https://stable-mirror.omarchy.org/$repo/os/$arch\n' \
  >"$home/etc/pacman.d/mirrorlist"
out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: detects an Omarchy mirror in the mirrorlist" \
  "$out" "points at an Omarchy mirror"
assert_contains "doctor: still sees the CachyOS repos while the mirrorlist is wrong" \
  "$out" "CachyOS repo section(s)"
assert_equals "doctor: a frozen mirror is a failure" "$status" "1"

# The base is gone entirely — stock Arch pacman.conf.
home=$(make_home)
printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n' >"$home/etc/pacman.conf"
out=$(loaf_run "$home" doctor)
assert_contains "doctor: detects a base replaced with stock Arch" "$out" "no CachyOS repos"

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
# debloat
# ---------------------------------------------------------

# A launcher on the removed list, resurrected the way omarchy-refresh-applications
# does it: the .desktop file plus its icon.
home=$(make_home)
mkdir -p "$home/.local/share/applications" "$home/.local/share/icons/hicolor/256x256/apps"
touch "$home/.local/share/applications/HEY.desktop"
touch "$home/.local/share/icons/hicolor/256x256/apps/hey.png"

out=$(loaf_run "$home" debloat)
assert_contains "debloat: removes a listed launcher" "$out" "removed HEY"
if [[ -e $home/.local/share/applications/HEY.desktop ]]; then
  fail "debloat: the .desktop file is gone"
else
  pass "debloat: the .desktop file is gone"
fi
if [[ -e $home/.local/share/icons/hicolor/256x256/apps/hey.png ]]; then
  fail "debloat: the icon goes with it"
else
  pass "debloat: the icon goes with it"
fi

out=$(loaf_run "$home" debloat)
assert_equals "debloat: second run is silent — idempotent" "$out" ""

# --dry-run reports without touching
home=$(make_home)
mkdir -p "$home/.local/share/applications"
touch "$home/.local/share/applications/HEY.desktop"
out=$(loaf_run "$home" debloat --dry-run)
assert_contains "debloat: --dry-run says what it would do" "$out" "would remove HEY"
assert_file_exists "debloat: --dry-run touches nothing" "$home/.local/share/applications/HEY.desktop"

# A repo with no manifest has decided nothing
home=$(make_home)
rm "$home/shokupan/packages/removed.webapps"
out=$(loaf_run "$home" debloat)
status=$?
assert_equals "debloat: no manifest is a silent no-op" "$out" ""
assert_equals "debloat: no manifest exits 0" "$status" "0"

# doctor flags a resurrected launcher; heal re-removes it
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
mkdir -p "$home/.local/share/applications"
touch "$home/.local/share/applications/HEY.desktop"
out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: detects a resurrected launcher" "$out" "removed launcher(s) are back"
assert_equals "doctor: a resurrected launcher is a failure" "$status" "1"

out=$(loaf_run "$home" heal)
assert_contains "heal: re-removes a resurrected launcher" "$out" "debloat: removed HEY"
if [[ -e $home/.local/share/applications/HEY.desktop ]]; then
  fail "heal: the launcher is gone afterwards"
else
  pass "heal: the launcher is gone afterwards"
fi

# ---------------------------------------------------------
# forks
# ---------------------------------------------------------

# A recorded fork whose upstream is unchanged is healthy.
home=$(make_home)
mkdir -p "$home/shokupan/.config/omarchy/plugins"
echo "fork" >"$home/shokupan/.config/omarchy/plugins/Fork.qml"
echo "upstream v1" >"$home/upstream.qml"
printf '.config/omarchy/plugins/Fork.qml %s %s\n' "$home/upstream.qml" \
  "$(sha256sum "$home/upstream.qml" | awk '{print $1}')" \
  >"$home/shokupan/packages/forks"
out=$(loaf_run "$home" forks)
status=$?
assert_contains "forks: unchanged upstream is healthy" "$out" "upstream unchanged"
assert_equals "forks: healthy exits 0" "$status" "0"

# Upstream moving under the fork is the whole point of the check (ADR-0042).
echo "upstream v2 - a fix the fork never got" >"$home/upstream.qml"
out=$(loaf_run "$home" forks)
status=$?
assert_contains "forks: detects upstream moving under a fork" "$out" "upstream moved under the fork"
assert_equals "forks: drift exits non-zero" "$status" "1"

out=$(loaf_run "$home" doctor)
assert_contains "doctor: surfaces fork drift" "$out" "upstream moved under a fork or watch"

# --record re-stamps and the board goes green again.
loaf_run "$home" forks --record >/dev/null
out=$(loaf_run "$home" forks)
assert_contains "forks: --record re-stamps the verification" "$out" "upstream unchanged"

# A renamed upstream file is worse than a changed one.
rm "$home/upstream.qml"
out=$(loaf_run "$home" forks)
status=$?
assert_contains "forks: detects a renamed-away upstream file" "$out" "no longer exists"
assert_equals "forks: a missing upstream is a failure" "$status" "1"

# A `watch` line covers an upstream file the rice references rather than
# copies (hosted-widget couplings). Drift is still red, but the message asks
# for a re-verify of the coupling, not a re-diff of a copy.
home=$(make_home)
mkdir -p "$home/shokupan/.config/omarchy/bar/modules"
echo "hosts upstream" >"$home/shokupan/.config/omarchy/bar/modules/hosted.qml"
echo "upstream v1" >"$home/hosted-upstream.qml"
printf '.config/omarchy/bar/modules/hosted.qml %s %s watch\n' \
  "$home/hosted-upstream.qml" \
  "$(sha256sum "$home/hosted-upstream.qml" | awk '{print $1}')" \
  >"$home/shokupan/packages/forks"
out=$(loaf_run "$home" forks)
status=$?
assert_contains "forks: unchanged watched upstream is healthy" "$out" "upstream unchanged"
assert_equals "forks: healthy watch exits 0" "$status" "0"

echo "upstream v2 - restructured" >"$home/hosted-upstream.qml"
out=$(loaf_run "$home" forks)
status=$?
assert_contains "forks: detects a changed watched upstream" "$out" "watched upstream file changed"
assert_contains "forks: a changed watch asks for re-verify, not re-diff" \
  "$out" "re-verify the module still applies"
assert_equals "forks: watch drift exits non-zero" "$status" "1"

# --record keeps the watch marker, so the line stays a watch after re-stamping.
loaf_run "$home" forks --record >/dev/null
assert_contains "forks: --record preserves the watch marker" \
  "$(cat "$home/shokupan/packages/forks")" " watch"
out=$(loaf_run "$home" forks)
assert_contains "forks: a re-stamped watch is healthy again" "$out" "upstream unchanged"

# Absolute upstream paths referenced from the rice's QML must exist
# (ADR-0042 want 2) — hosted widgets fail silently when a rename lands.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
mkdir -p "$home/shokupan/.config/omarchy/bar/modules"
printf 'source: "file:///usr/share/omarchy/shell/definitely-renamed-away.qml"\n' \
  >"$home/shokupan/.config/omarchy/bar/modules/hosted.qml"
git -C "$home/shokupan" add -A && git -C "$home/shokupan" commit -qm 'bar module' 2>/dev/null
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: detects a broken upstream QML reference" \
  "$out" "referenced upstream path(s) missing"
assert_equals "doctor: a broken upstream reference is a failure" "$status" "1"

# ---------------------------------------------------------
# hyprland emergency mode
# ---------------------------------------------------------

# Emergency mode outlives its cause (a restow window left hyprland.lua absent
# for a minute; the banner stayed after the file returned), so doctor asks the
# compositor rather than the filesystem.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
mkdir -p "$home/hypr-runtime/some-instance-signature"
out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: reports a clean hyprland config" "$out" "no config errors"
assert_equals "doctor: a clean compositor is not a problem" "$status" "0"

out=$(STUB_HYPR_ERRORS='cannot open /home/x/.config/hypr/hyprland.lua: No such file or directory' \
  loaf_run "$home" doctor)
status=$?
assert_contains "doctor: surfaces hyprland config errors" "$out" "emergency mode is likely active"
assert_contains "doctor: says how to recover" "$out" "hyprctl reload"
assert_equals "doctor: a wedged compositor is a failure" "$status" "1"

# No runtime dir means no compositor — a TTY or SSH session, not a problem.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
out=$(loaf_run "$home" doctor)
status=$?
assert_not_contains "doctor: says nothing about hyprland without a compositor" "$out" "hyprland"
assert_equals "doctor: no compositor is not a problem" "$status" "0"

# ---------------------------------------------------------
# heal reporting honesty (ADR-0042 want 4, and want 3's restart)
# ---------------------------------------------------------

# A foreign symlink at a tracked path: section 1 skips it (it IS a link), stow
# then refuses the conflict. That used to be reported as a green change.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
rm "$home/.config/hypr/looknfeel.conf"
ln -s /nonexistent "$home/.config/hypr/looknfeel.conf"
out=$(loaf_run "$home" heal)
status=$?
assert_contains "heal: reports a failed stow as a failure" "$out" "stow failed"
assert_equals "heal: exits non-zero when stow fails" "$status" "1"

# Placing a bar module is unfinished until the shell restarts — the shell only
# registers bar/modules/ files at startup.
home=$(make_home)
mkdir -p "$home/shokupan/.config/omarchy/bar/modules"
echo "// module" >"$home/shokupan/.config/omarchy/bar/modules/new.qml"
git -C "$home/shokupan" add -A && git -C "$home/shokupan" commit -qm 'bar module' 2>/dev/null
out=$(loaf_run "$home" heal)
assert_contains "heal: says the shell must restart after placing a bar module" \
  "$out" "bar/modules changed"

# ---------------------------------------------------------
# install
# ---------------------------------------------------------

# The version binding is the point: a rice verified against one Omarchy must
# refuse to install onto another.
home=$(make_home)
printf '3.8.4\n' >"$home/shokupan/packages/omarchy.pin"
git -C "$home/shokupan" commit -qam 'pin an older Omarchy' 2>/dev/null
out=$(loaf_run "$home" install)
status=$?
assert_contains "install: refuses an Omarchy the rice was not verified against" \
  "$out" "not the version this rice was verified against"
assert_equals "install: a pin mismatch is a hard stop" "$status" "1"

out=$(loaf_run "$home" install --force)
assert_contains "install: --force accepts the mismatch out loud" \
  "$out" "continuing under --force"

# Happy path: pin matches, everything installed — install stows, heals and ends
# with a clean doctor.
home=$(make_home)
out=$(loaf_run "$home" install)
status=$?
assert_contains "install: confirms the pin matches" "$out" "matches the pin"
assert_contains "install: ends with a clean doctor" "$out" "No problems"
assert_equals "install: exits 0 on a healthy machine" "$status" "0"
assert_symlink "install: stowed the rice" "$home/.config/hypr/looknfeel.conf"

# A missing chosen package is installed via pacman, through sudo, with quattro's
# direct-pacman guard variable satisfied by construction (env sets it).
home=$(make_home)
out=$(STUB_ABSENT=bat STUB_LOG="$home/pacman.log" loaf_run "$home" install)
assert_contains "install: installs missing chosen packages" "$out" "installing 1 chosen package(s)"
assert_contains "install: hands pacman the missing package" \
  "$(cat "$home/pacman.log" 2>/dev/null)" "pacman -S --needed --noconfirm bat"

# No CachyOS base, no install.
home=$(make_home)
printf '[core]\nInclude = /etc/pacman.d/mirrorlist\n' >"$home/etc/pacman.conf"
out=$(loaf_run "$home" install)
status=$?
assert_contains "install: refuses a base that is not CachyOS" "$out" "not CachyOS"
assert_equals "install: a foreign base is a hard stop" "$status" "1"

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
# widevine
# ---------------------------------------------------------
#
# The donation is machine-side bytes claimed by ADR-0038, like the wallpaper
# pool: loaf-widevine copies a Chrome-sourced CDM layout into Helium's profile
# and writes the pointer file Helium reads. HELIUM_BIN=bash stands in for the
# browser (the check is command presence, not behaviour); CHROME_BUNDLED_CDM is
# pointed away from /opt so a machine that happens to have Chrome installed
# does not donate into the refusal test.

home=$(make_home)
mkdir -p "$home/.config/net.imput.helium"
src="$home/cdm-source"
mkdir -p "$src/_platform_specific/linux_x64"
printf '{"name":"WidevineCdm","version":"4.10.9999.0"}\n' >"$src/manifest.json"
printf 'stub library\n' >"$src/_platform_specific/linux_x64/libwidevinecdm.so"

out=$(HELIUM_BIN=bash CHROME_BUNDLED_CDM="$home/nope" WIDEVINE_SOURCE="$src" \
  loaf_run "$home" widevine)
status=$?
assert_equals "widevine: donates from a source CDM" "$status" "0"
donated="$home/.config/net.imput.helium/WidevineCdm/4.10.9999.0"
assert_file_exists "widevine: library copied into a versioned dir" \
  "$donated/_platform_specific/linux_x64/libwidevinecdm.so"
pointer="$home/.config/net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm"
assert_contains "widevine: pointer names the donated dir" \
  "$(cat "$pointer" 2>/dev/null)" "\"Path\":\"$donated\""

# A present donation is never touched — after the first copy Helium's component
# updater owns currency — so a second run must succeed without a source at all.
out=$(HELIUM_BIN=bash CHROME_BUNDLED_CDM="$home/nope" loaf_run "$home" widevine)
status=$?
assert_contains "widevine: a present donation is left alone" "$out" "nothing to do"
assert_equals "widevine: idempotent run exits 0" "$status" "0"

out=$(HELIUM_BIN=bash CHROME_BUNDLED_CDM="$home/nope" loaf_run "$home" doctor)
assert_contains "doctor: reports the donation version-consistent" "$out" \
  "CDM 4.10.9999.0 donated and version-consistent"

# Gut the donation but leave the pointer: the exact state a half-finished copy
# or an overzealous cleanup produces.
rm "$donated/_platform_specific/linux_x64/libwidevinecdm.so"
out=$(HELIUM_BIN=bash CHROME_BUNDLED_CDM="$home/nope" loaf_run "$home" doctor)
status=$?
assert_contains "doctor: detects a broken donation" "$out" "CDM files are not there"
assert_equals "doctor: a broken donation is a failure" "$status" "1"

home=$(make_home)
mkdir -p "$home/.config/net.imput.helium"
out=$(HELIUM_BIN=bash CHROME_BUNDLED_CDM="$home/nope" loaf_run "$home" widevine)
status=$?
assert_contains "widevine: refuses when no source CDM exists" "$out" \
  "no source Widevine CDM"
assert_equals "widevine: refusal exits non-zero" "$status" "1"

out=$(HELIUM_BIN=surely-not-a-command CHROME_BUNDLED_CDM="$home/nope" \
  loaf_run "$home" widevine)
status=$?
assert_contains "widevine: refuses when helium is absent" "$out" "helium is not installed"
assert_equals "widevine: helium absence exits non-zero" "$status" "1"

# No profile dir means Helium has never run here — doctor makes no claim.
home=$(make_home)
out=$(HELIUM_BIN=bash CHROME_BUNDLED_CDM="$home/nope" loaf_run "$home" doctor)
assert_not_contains "doctor: silent about widevine when helium never ran" "$out" "widevine"

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
