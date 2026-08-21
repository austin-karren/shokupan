#!/bin/bash

# Tests for the loaf CLI, which maintains the Shokupan rice. No framework on
# purpose. `loaf heal` runs from Omarchy's post-update.d hook, so anything
# needed to test it would become a dependency of the update path. This emits TAP
# and follows the shape of Omarchy's own test/omarchy-cli-test.sh. Every test
# builds a throwaway home under $BUILD and points LOAF_HOME at it, so nothing
# here can touch the real one. `pacman` and the files doctor reads under /etc
# are stubbed; `git` and `stow` are real, because what they do to a fixture is
# exactly what they would do to the machine. The /etc stubs matter more than
# they look. Omarchy became package-backed (omarchy-desktop-on-cachyos ADR-0035)
# and doctor's base checks now assert things about pacman's config and
# NetworkManager's, so a suite reading the real /etc would pass or fail on how
# the machine running it happens to be set up — and would have gone red on the
# very machine whose broken wifi backend prompted the check. Run:
# test/loaf-test.sh

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

  # The plugins checkout, which the rice consumes rather than carries since the
  # 2026-08-18 split. Doctor asserts every plugin it ships is linked into the
  # desktop, so a fixture needs both halves or every clean-fixture test reds.
    local plugins="$home/.local/share/shokupan-plugins"
    mkdir -p "$plugins/plugins/shokupan-fixture" "$home/.config/omarchy/plugins"
    echo '{"id":"shokupan.fixture"}' >"$plugins/plugins/shokupan-fixture/manifest.json"
    ln -sfn "$plugins/plugins/shokupan-fixture" \
      "$home/.config/omarchy/plugins/shokupan-fixture"

  # The rice repo
    local repo="$home/shokupan"
    mkdir -p "$repo/.config/hypr" "$repo/packages" "$repo/migrations"
    echo "# tracked config" >"$repo/.config/hypr/looknfeel.conf"
    printf 'bat\n' >"$repo/packages/chosen.packages"
    # The healthy state for the debloat manifest is the launcher being absent,
    # which a fresh fixture home already is — so listing one here exercises
    # doctor's debloat check on every clean fixture.
    printf 'HEY\n' >"$repo/packages/removed.webapps"
    # The plugin index (packages/plugins) records the standalone repo each
    # plugin is published from. The healthy state is it agreeing with the
    # checkout built above, so listing the one fixture plugin here exercises
    # doctor's index check on every clean fixture.
    printf 'shokupan.fixture https://github.com/austin-karren/omarchy-fixture.git\n' \
      >"$repo/packages/plugins"
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

# Stubbed udevadm, so a test that exercises loaf-install's qmk step cannot
# reload udev rules on the machine running the suite. Recorded, not performed,
# so a test can assert the reload WAS asked for.
cat >"$BUILD/stub/udevadm" <<'STUB'
#!/bin/bash
echo "udevadm $*" >>"${STUB_LOG:-/dev/null}"
STUB
chmod +x "$BUILD/stub/udevadm"

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
  # $LOAF_ROOT defaults to the fixture's rice repo, but a caller may point it
  # elsewhere in the fixture home — the worktree tests run doctor against a
  # linked worktree of that repo rather than the repo itself.
  LOAF_HOME="$home" LOAF_ROOT="${LOAF_ROOT:-$home/shokupan}" \
    PLUGINS_ROOT="$home/.local/share/shokupan-plugins" \
    PACMAN_CONF="$home/etc/pacman.conf" \
    MIRRORLIST="$home/etc/pacman.d/mirrorlist" \
    NM_CONF="$home/etc/NetworkManager.conf" \
    QMK_RULES="$home/etc/udev/rules.d/50-qmk.rules" \
    QMK_PKG_RULES="$home/usr/lib/udev/rules.d/50-qmk.rules" \
    QMK_EXTRA_RULES="$home/etc/udev/rules.d/51-qmk-extra.rules" \
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

# The retired bridge (omarchy-desktop-on-cachyos ADR-0035) took three checks
# with it, and a package-backed Omarchy took a fourth. Asserted by absence:
# leaving one behind would mean doctor reporting on an installer that can no
# longer run, which is exactly the noise omarchy-desktop-on-cachyos ADR-0028
# says to delete rather than tolerate.
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

# A linked git worktree. `.git` there is a FILE holding a `gitdir:` pointer, not
# a directory — doctor used to test for the directory and report the tree as not
# a checkout, which made it useless in exactly the place every lane of a
# worktree-based workflow runs. Built for real rather than faked: the worktree is
# what stow installs from, so the whole run is against it.
home=$(make_home)
git -C "$home/shokupan" worktree add -q -b lane "$home/lane" >/dev/null 2>&1
(cd "$home/lane" && stow --no-folding -t "$home" . 2>/dev/null)
assert_file_exists "doctor: the worktree fixture has a .git file, not a directory" \
  "$home/lane/.git"
out=$(LOAF_ROOT="$home/lane" loaf_run "$home" doctor)
status=$?
assert_not_contains "doctor: accepts a linked worktree as a checkout" \
  "$out" "is not a git checkout"
assert_contains "doctor: a linked worktree reports no problems" "$out" "No problems"
assert_equals "doctor: exits 0 in a linked worktree" "$status" "0"

# The other half: the normal-checkout case still passes, and a directory that is
# no checkout at all is still caught.
home=$(make_home)
rm -rf "$home/shokupan/.git"
out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: still rejects a directory that is not a checkout" \
  "$out" "is not a git checkout"
assert_equals "doctor: exits non-zero when the rice is not a checkout" "$status" "1"

# Omarchy is packages now (omarchy-desktop-on-cachyos ADR-0035), so "the desktop
# layer is gone" means the package is gone rather than a checkout being absent.
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

# The mirrorlist. omarchy-desktop-on-cachyos ADR-0035's measured root cause:
# Omarchy pins a frozen Arch snapshot, CachyOS is rolling, and the two skew
# permanently. Note the fixture's pacman.conf still has its [cachyos*] section
# — the repo list surviving is exactly what makes this failure look fine until
# pacman starts refusing downgrades.
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

# The TRACKED manifest, not the fixture's. make_home writes its own
# packages/removed.webapps holding only HEY, so every test above passes no
# matter what the real one says — Basecamp could be deleted from the tracked
# list and the whole suite would stay green. It was, and it did.
#
# Basecamp is an Omarchy default web app (upstream ships
# applications/Basecamp.desktop) that this machine has decided against, and
# omarchy-refresh-applications copies it back on every update. The manifest
# entry is the only thing that keeps it gone, so the entry itself is pinned.
tracked_removed=$ROOT/packages/removed.webapps
assert_file_exists "debloat: the tracked manifest is present" "$tracked_removed"
if grep -qx 'Basecamp' "$tracked_removed"; then
  pass "debloat: the tracked manifest keeps Basecamp removed"
else
  fail "debloat: the tracked manifest keeps Basecamp removed" \
    "Basecamp is not listed in packages/removed.webapps" \
    "without it, every Omarchy update restores ~/.local/share/applications/Basecamp.desktop"
fi

# And that the entry actually drives a removal, rather than merely being a
# string in a file. Driven by the tracked manifest copied into the fixture, so
# this fails if Basecamp is dropped from it OR if debloat stops acting on it.
home=$(make_home)
cp "$tracked_removed" "$home/shokupan/packages/removed.webapps"
mkdir -p "$home/.local/share/applications" "$home/.local/share/icons/hicolor/256x256/apps"
touch "$home/.local/share/applications/Basecamp.desktop"
touch "$home/.local/share/icons/hicolor/256x256/apps/basecamp.png"
out=$(loaf_run "$home" debloat)
assert_contains "debloat: the tracked manifest removes Basecamp" "$out" "removed Basecamp"
if [[ -e $home/.local/share/applications/Basecamp.desktop ]]; then
  fail "debloat: Basecamp's launcher is gone"
else
  pass "debloat: Basecamp's launcher is gone"
fi
if [[ -e $home/.local/share/icons/hicolor/256x256/apps/basecamp.png ]]; then
  fail "debloat: Basecamp's icon goes with it"
else
  pass "debloat: Basecamp's icon goes with it"
fi

# ---------------------------------------------------------
# forks
# ---------------------------------------------------------

# A recorded fork whose upstream is unchanged is healthy.
home=$(make_home)
mkdir -p "$home/.local/share/shokupan-plugins/plugins"
echo "fork" >"$home/.local/share/shokupan-plugins/plugins/Fork.qml"
echo "upstream v1" >"$home/upstream.qml"
printf 'plugins/Fork.qml %s %s\n' "$home/upstream.qml" \
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
mkdir -p "$home/.local/share/shokupan-plugins/bar/modules"
echo "hosts upstream" >"$home/.local/share/shokupan-plugins/bar/modules/hosted.qml"
echo "upstream v1" >"$home/hosted-upstream.qml"
printf 'bar/modules/hosted.qml %s %s watch\n' \
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
mkdir -p "$home/.local/share/shokupan-plugins/bar/modules"
printf 'source: "file:///usr/share/omarchy/shell/definitely-renamed-away.qml"\n' \
  >"$home/.local/share/shokupan-plugins/bar/modules/hosted.qml"
git -C "$home/shokupan" add -A && git -C "$home/shokupan" commit -qm 'bar module' 2>/dev/null
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: detects a broken upstream QML reference" \
  "$out" "referenced upstream path(s) missing"
assert_equals "doctor: a broken upstream reference is a failure" "$status" "1"

# ---------------------------------------------------------
# plugin index
# ---------------------------------------------------------

# The index resolves a recorded id to the plugin in the checkout that declares
# it. Resolution goes through manifest.json on purpose: the repo is named
# `omarchy-<function>` while the id stays `shokupan.*`, so the directory name is
# NOT derivable from the id and a path guess would pass for the wrong reason.
home=$(make_home)
out=$(loaf_run "$home" plugins --index)
status=$?
assert_contains "index: resolves a recorded id to its plugin" "$out" "shokupan.fixture"
assert_contains "index: reports the publish URL" \
  "$out" "https://github.com/austin-karren/omarchy-fixture.git"
assert_contains "index: a resolving index is healthy" "$out" "resolve to the checkout"
assert_equals "index: healthy exits 0" "$status" "0"

# --index must not install anything — it is the read-only direction, and doctor
# calls it. A run against a checkout with nothing linked leaves it unlinked.
home=$(make_home)
rm -rf "$home/.config/omarchy/plugins/shokupan-fixture"
loaf_run "$home" plugins --index >/dev/null
assert_equals "index: does not link anything" \
  "$(ls "$home/.config/omarchy/plugins" 2>/dev/null)" ""

# A line for a plugin the checkout no longer ships: the published edge would
# serve a plugin this repo dropped.
home=$(make_home)
printf 'shokupan.fixture https://github.com/austin-karren/omarchy-fixture.git\nshokupan.gone https://github.com/austin-karren/omarchy-gone.git\n' \
  >"$home/shokupan/packages/plugins"
out=$(loaf_run "$home" plugins --index)
status=$?
assert_contains "index: detects a recorded id with no plugin" "$out" "shokupan.gone"
assert_contains "index: says why the recorded id failed" \
  "$out" "no plugin with that id in the checkout"
assert_equals "index: an unresolved id is a failure" "$status" "1"

out=$(loaf_run "$home" doctor)
status=$?
assert_contains "doctor: surfaces index drift" "$out" "packages/plugins and the checkout disagree"
assert_equals "doctor: index drift is a failure" "$status" "1"

# The other direction: a plugin that ships but was never split out and recorded.
# Unlike `loaf packages`, this is red rather than advisory — an unrecorded
# plugin is one a stranger following the README cannot install.
home=$(make_home)
mkdir -p "$home/.local/share/shokupan-plugins/plugins/shokupan-unpublished"
echo '{"id":"shokupan.unpublished"}' \
  >"$home/.local/share/shokupan-plugins/plugins/shokupan-unpublished/manifest.json"
ln -sfn "$home/.local/share/shokupan-plugins/plugins/shokupan-unpublished" \
  "$home/.config/omarchy/plugins/shokupan-unpublished"
out=$(loaf_run "$home" plugins --index)
status=$?
assert_contains "index: detects a shipped plugin with no published repo" \
  "$out" "shokupan.unpublished"
assert_contains "index: says what to do about it" "$out" "split it out and add the line"
assert_equals "index: an unrecorded plugin is a failure" "$status" "1"

# An id is matched as a whole field, not as a substring — `shokupan.capture`
# must not satisfy the record for a hypothetical `shokupan.capt`.
home=$(make_home)
printf 'shokupan.fixtures https://github.com/austin-karren/omarchy-fixtures.git\n' \
  >"$home/shokupan/packages/plugins"
out=$(loaf_run "$home" plugins --index)
assert_contains "index: a near-miss id does not resolve" \
  "$out" "no plugin with that id in the checkout"
assert_contains "index: nor does the near-miss record cover the real plugin" \
  "$out" "with no published repo recorded"

# Comments and blank lines are stripped the same way every other manifest here
# strips them.
home=$(make_home)
printf '# a comment\n\n   \nshokupan.fixture https://github.com/austin-karren/omarchy-fixture.git  # trailing\n' \
  >"$home/shokupan/packages/plugins"
out=$(loaf_run "$home" plugins --index)
status=$?
assert_contains "index: ignores comments and blank lines" "$out" "all 1 published plugin"
assert_equals "index: a commented manifest still exits 0" "$status" "0"

# No index is a hard failure for --index specifically: it was asked for the
# index. Doctor's own check is guarded on the file instead, so a repo without
# one simply does not make the claim.
home=$(make_home)
rm -f "$home/shokupan/packages/plugins"
out=$(loaf_run "$home" plugins --index)
status=$?
assert_contains "index: reports a missing index" "$out" "no index at"
assert_equals "index: a missing index exits non-zero" "$status" "1"

out=$(loaf_run "$home" doctor)
assert_not_contains "doctor: silent about the index when there is none" \
  "$out" "plugin index"

# The index is repo furniture, not config: it must never be stowed into the
# home directory. packages/ is already repo-only, so this just pins it.
home=$(make_home)
(cd "$home/shokupan" && stow --no-folding -t "$home" . 2>/dev/null)
assert_equals "index: the manifest is not stowed into the home" \
  "$([[ -e $home/packages/plugins ]] && echo present || echo absent)" "absent"

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
mkdir -p "$home/.local/share/shokupan-plugins/bar/modules"
echo "// module" >"$home/.local/share/shokupan-plugins/bar/modules/new.qml"
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

# Step 4a's qmk udev rules. udev resolves same-named rules files by directory
# precedence, so anything in /etc/udev/rules.d SHADOWS /usr/lib/udev/rules.d
# outright. qmk 1.2.0-3 ships its own 50-qmk.rules under /usr/lib, and the old
# gate ("write ours if /etc has nothing") manufactured an unowned file on every
# fresh machine that overrode the packaged one.
#
# The packaged file is also a strict SUBSET of QMK upstream — it lacks the
# RP2040/RP2350 BOOTSEL ids this machine's board flashes through — so the fix
# is not "never write anything". Two branches, both pinned below:
#   packaged present -> add only packages/qmk-udev-extra.rules, as 51-
#   packaged absent  -> supply the whole of packages/qmk-udev.rules, as 50-
#
# The fixtures build the packaged rule and the /etc ones explicitly, because
# the gate is entirely about which of those exist.

# The packaged rule is there: 50- is left to pacman and only the supplement
# lands. The regression test — an /etc/50- appearing here IS the bug.
home=$(make_home)
printf 'ATTRS{idVendor}=="fixture"\n' >"$home/shokupan/packages/qmk-udev.rules"
printf '# extra\nATTRS{idVendor}=="2e8a"\n' >"$home/shokupan/packages/qmk-udev-extra.rules"
mkdir -p "$home/etc/udev/rules.d" "$home/usr/lib/udev/rules.d"
printf '# shipped by qmk\n' >"$home/usr/lib/udev/rules.d/50-qmk.rules"
out=$(STUB_LOG="$home/udev.log" loaf_run "$home" install)
assert_contains "install: installs the qmk supplement when the package ships 50-" \
  "$out" "installing $home/etc/udev/rules.d/51-qmk-extra.rules"
assert_file_exists "install: the supplement lands as 51-" \
  "$home/etc/udev/rules.d/51-qmk-extra.rules"
if [[ -e $home/etc/udev/rules.d/50-qmk.rules ]]; then
  fail "install: writes no /etc 50- rule that would shadow the packaged one" \
    "created $home/etc/udev/rules.d/50-qmk.rules over the packaged copy"
else
  pass "install: writes no /etc 50- rule that would shadow the packaged one"
fi
assert_contains "install: reloads udev after writing the supplement" \
  "$(cat "$home/udev.log" 2>/dev/null)" "udevadm control --reload-rules"

# Second run changes nothing and does not reload — the supplement is compared
# by content, so a re-run is quiet but an updated rice copy still lands.
out=$(STUB_LOG="$home/udev2.log" loaf_run "$home" install)
assert_contains "install: an up-to-date supplement is left alone" \
  "$out" "qmk supplemental udev rules current"
assert_not_contains "install: does not reload udev when the supplement is current" \
  "$(cat "$home/udev2.log" 2>/dev/null)" "udevadm control"

printf '# extra\nATTRS{idVendor}=="2e8a"\nATTRS{idVendor}=="342d"\n' \
  >"$home/shokupan/packages/qmk-udev-extra.rules"
out=$(loaf_run "$home" install)
assert_contains "install: refreshes the supplement when the rice copy changed" \
  "$out" "installing $home/etc/udev/rules.d/51-qmk-extra.rules"
assert_contains "install: the refreshed supplement has the new rule" \
  "$(cat "$home/etc/udev/rules.d/51-qmk-extra.rules")" '342d'

# Nothing packaged: the rice still supplies the whole file at 50-, which is why
# it carries a full copy at all. The other half of the gate — without this,
# "fixed" could just mean "never installs anything".
home=$(make_home)
printf 'ATTRS{idVendor}=="fixture"\n' >"$home/shokupan/packages/qmk-udev.rules"
printf '# extra\n' >"$home/shokupan/packages/qmk-udev-extra.rules"
mkdir -p "$home/etc/udev/rules.d"
out=$(STUB_LOG="$home/udev.log" loaf_run "$home" install)
assert_contains "install: installs the full qmk rule when nothing packaged provides one" \
  "$out" "installing $home/etc/udev/rules.d/50-qmk.rules"
assert_file_exists "install: the full qmk rule lands in /etc" \
  "$home/etc/udev/rules.d/50-qmk.rules"
if [[ -e $home/etc/udev/rules.d/51-qmk-extra.rules ]]; then
  fail "install: no supplement when the rice supplied the whole file" \
    "51-qmk-extra.rules would duplicate rules already in the 50- copy"
else
  pass "install: no supplement when the rice supplied the whole file"
fi
assert_contains "install: reloads udev after writing the full rule" \
  "$(cat "$home/udev.log" 2>/dev/null)" "udevadm control --reload-rules"

# The state this machine is in: packaged rule plus the old installer's shadow.
# Named out loud rather than reported as "already present", and left in place —
# removing it needs root.
home=$(make_home)
printf 'ATTRS{idVendor}=="fixture"\n' >"$home/shokupan/packages/qmk-udev.rules"
printf '# extra\n' >"$home/shokupan/packages/qmk-udev-extra.rules"
mkdir -p "$home/etc/udev/rules.d" "$home/usr/lib/udev/rules.d"
printf '# shipped by qmk\n' >"$home/usr/lib/udev/rules.d/50-qmk.rules"
printf '# unowned, ours\n' >"$home/etc/udev/rules.d/50-qmk.rules"
out=$(loaf_run "$home" install)
assert_contains "install: names an /etc rule that shadows the packaged one" \
  "$out" "shadows the packaged rule"
assert_contains "install: says the shadow is redundant once the supplement is in" \
  "$out" "sudo rm $home/etc/udev/rules.d/50-qmk.rules"
assert_equals "install: leaves the shadowing rule in place for a human" \
  "$(cat "$home/etc/udev/rules.d/50-qmk.rules")" "# unowned, ours"

# The TRACKED supplement, not a fixture's toy version. It must be a valid udev
# rules file and must carry the RP2040/RP2350 BOOTSEL ids, which are the reason
# it exists — pacman's copy lacks them and this machine's board flashes through
# them. Read from $ROOT: the fixtures above write their own, so nothing there
# says anything about the real file.
tracked_extra=$ROOT/packages/qmk-udev-extra.rules
assert_file_exists "qmk: the tracked supplement exists" "$tracked_extra"
assert_contains "qmk: the supplement carries the RP2040 BOOTSEL id" \
  "$(cat "$tracked_extra")" 'ATTRS{idProduct}=="0003"'
assert_contains "qmk: the supplement carries the RP2350 BOOTSEL id" \
  "$(cat "$tracked_extra")" 'ATTRS{idProduct}=="000f"'

# Every rule tags uaccess itself. udev evaluates files in filename order, so
# 50-qmk.rules' trailing `ENV{ID_QMK}=="1", TAG+="uaccess"` has already been
# passed by the time 51- runs: a supplement that only set ID_QMK would tag
# nothing and the device would stay root-only. This catches someone "tidying"
# the per-rule tags out into a single trailing line.
untagged=()
while IFS= read -r rule; do
  [[ $rule == *'TAG+="uaccess"'* ]] || untagged+=("$rule")
done < <(grep '^SUBSYSTEMS==' "$tracked_extra")
if ((${#untagged[@]})); then
  fail "qmk: every supplement rule tags uaccess itself" "${untagged[@]}"
else
  pass "qmk: every supplement rule tags uaccess itself"
fi

# Every id the supplement carries must be one the rice's full upstream copy
# also has. A typo'd vendor id here would tag nothing and nobody would notice.
strays=()
while IFS= read -r id; do
  grep -q "$id" "$ROOT/packages/qmk-udev.rules" || strays+=("$id not in packages/qmk-udev.rules")
done < <(grep -o 'ATTRS{idVendor}=="[0-9a-f]*"' "$tracked_extra" | sort -u)
if ((${#strays[@]})); then
  fail "qmk: every supplement vendor id is one upstream knows" "${strays[@]}"
else
  pass "qmk: every supplement vendor id is one upstream knows"
fi

# Real udev parse, when udevadm is available. /usr/bin/udevadm explicitly: the
# suite puts a stubbed udevadm on $PATH so the install tests cannot reload the
# host's rules, and that stub would happily "verify" anything.
if [[ -x /usr/bin/udevadm ]]; then
  for f in "$tracked_extra" "$ROOT/packages/qmk-udev.rules"; do
    if verify_out=$(/usr/bin/udevadm verify "$f" 2>&1); then
      pass "qmk: $(basename "$f") parses as udev rules"
    else
      fail "qmk: $(basename "$f") parses as udev rules" "$verify_out"
    fi
  done
fi

# A linked git worktree. `.git` there is a FILE holding a `gitdir:` pointer, not
# a directory — install used to test for the directory and refuse the tree as no
# checkout, which locked out exactly the place every lane of a worktree-based
# workflow installs from. Built for real rather than faked: the install runs
# against the worktree, so it is the worktree that gets stowed.
home=$(make_home)
git -C "$home/shokupan" worktree add -q -b lane "$home/lane" >/dev/null 2>&1
assert_file_exists "install: the worktree fixture has a .git file, not a directory" \
  "$home/lane/.git"
out=$(LOAF_ROOT="$home/lane" loaf_run "$home" install)
status=$?
# Matched against the worktree path, since the plugins step prints the same
# phrase about its own (deliberately unversioned) fixture directory.
assert_not_contains "install: accepts a linked worktree as a checkout" \
  "$out" "$home/lane is not a git checkout"
assert_equals "install: exits 0 when installing from a linked worktree" "$status" "0"
assert_symlink "install: stowed the rice from the worktree" \
  "$home/.config/hypr/looknfeel.conf"

# The other half: a directory that is no checkout at all is still refused.
home=$(make_home)
rm -rf "$home/shokupan/.git"
out=$(loaf_run "$home" install)
status=$?
assert_contains "install: still refuses a directory that is not a checkout" \
  "$out" "is not a git checkout"
assert_equals "install: a non-checkout is a hard stop" "$status" "1"

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

# CLAUDE.md is agent instructions for working in this repo, not config — it must
# never be symlinked into $HOME as ~/CLAUDE.md. Stowed from the REAL repo, not
# from make_home: the fixture writes its own .stow-local-ignore, so a fixture
# stow would pass no matter what the tracked one says.
claude_tracked=$(git -C "$ROOT" ls-files -- CLAUDE.md)
assert_equals "repo-only: CLAUDE.md is tracked" "$claude_tracked" "CLAUDE.md"

stow_home=$(mktemp -d "$BUILD/stowhome-XXXXXX")
stow --no-folding -d "$(dirname "$ROOT")" -t "$stow_home" \
  "$(basename "$ROOT")" >/dev/null 2>&1
if [[ -e $stow_home/CLAUDE.md ]]; then
  fail "repo-only: CLAUDE.md is not stowed into \$HOME" \
    "stow linked $stow_home/CLAUDE.md — add ^/CLAUDE\\.md\$ to .stow-local-ignore"
else
  pass "repo-only: CLAUDE.md is not stowed into \$HOME"
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
# bash seam
# ---------------------------------------------------------
#
# The rice's .bashrc was split: crumb took the portable half and owns a
# desktop-agnostic .bashrc that sources two tiers of drop-ins —
# ~/.config/bash/env.d/*.sh BEFORE the `[[ $- != *i* ]] && return` guard, and
# ~/.config/bash/*.sh after it. The rice keeps the Omarchy-coupled half; crumb
# knows nothing about Omarchy and only provides the seam.
#
# The rice's half is split across BOTH tiers, the way upstream's own
# default/bashrc divides them: the environment (OMARCHY_PATH) above the guard
# because `ssh box somecommand` needs the variable, and the interactive rc
# below it because aliases, functions, completions and key bindings have no
# business in a non-interactive shell. Which tier a piece lands in is the thing
# these tests hold — a file drifting across the guard is silent otherwise.
#
# The cutover happened 2026-08-19: .bashrc is no longer tracked here and
# ~/.bashrc is a symlink into ~/crumb. These assertions cover only the rice's
# two drop-ins, which is all this repo still owns of the seam.

seam_env=.config/bash/env.d/00-omarchy.sh
seam_rc=.config/bash/50-omarchy-rc.sh

assert_file_exists "seam: the pre-guard OMARCHY_PATH drop-in exists" "$ROOT/$seam_env"
assert_file_exists "seam: the post-guard rc drop-in exists" "$ROOT/$seam_rc"

for f in "$seam_env" "$seam_rc"; do
  if bash -n "$ROOT/$f" 2>/dev/null; then
    pass "seam: $f parses"
  else
    fail "seam: $f parses" "$(bash -n "$ROOT/$f" 2>&1)"
  fi
done

# The watch belongs to the file that actually sources upstream's rc (ADR-0042).
# .bashrc had never been recorded here at all, which is why its drift from
# upstream went unnoticed while the board read clean.
assert_contains "seam: the rc drop-in is a recorded watch" \
  "$(grep "^$seam_rc " "$ROOT/packages/forks")" \
  "/usr/share/omarchy/default/bash/rc"
assert_contains "seam: recorded as a watch, not a fork" \
  "$(grep "^$seam_rc " "$ROOT/packages/forks")" " watch"
# The env tier carries a watch of its own now. It used to hand-roll the
# OMARCHY_PATH block against /etc/omarchy.conf — machine state, not a packaged
# upstream file, so there was nothing to watch and this asserted zero. It now
# sources upstream's default/bash/env-bootstrap, which is a packaged file whose
# drift can silently reorder PATH in every non-interactive shell. Exactly one
# watch, and against env-bootstrap rather than rc: a watch pointing at the wrong
# upstream file sends the re-verification to the wrong place.
assert_contains "seam: the env drop-in is a recorded watch" \
  "$(grep "^$seam_env " "$ROOT/packages/forks")" \
  "/usr/share/omarchy/default/bash/env-bootstrap"
assert_contains "seam: the env watch is a watch, not a fork" \
  "$(grep "^$seam_env " "$ROOT/packages/forks")" " watch"
assert_equals "seam: the env tier records exactly one watch" \
  "$(grep -c "^$seam_env " "$ROOT/packages/forks")" "1"

# Both drop-ins have to reach $HOME, so neither may be caught by the repo-only
# ignore list. Stowed from the real repo into a throwaway home rather than
# reasoning about the patterns, since what matters is what stow actually does.
home=$(make_home)
(cd "$ROOT" && stow --no-folding -t "$home" . 2>/dev/null)
assert_symlink "seam: .config/bash/env.d reaches \$HOME" "$home/$seam_env"
assert_symlink "seam: .config/bash reaches \$HOME" "$home/$seam_rc"

# Behaviour. Both drop-ins are copied into the fixture with /usr/share/omarchy
# and /etc/omarchy.conf rewritten to fixture paths, so the runs answer to the
# fixture rather than to whether the machine running the suite has Omarchy
# installed or is dev-linked.
#
# env-bootstrap is copied in for real rather than stubbed, path-rewritten the
# same way. It is upstream's file, not ours, but every assertion below is about
# what the env tier actually puts in the environment — OMARCHY_PATH, the
# dev-link prepend, the appended user paths — and a stub would only re-assert
# whatever the stub was written to do. The copy is what makes those assertions
# mean something; the fixture rewrite is what keeps them from answering to how
# the machine running the suite happens to be dev-linked. Its absence is a
# scenario, tested by deleting the copy.
seam_bootstrap=usr/share/omarchy/default/bash/env-bootstrap

assert_file_exists "seam: upstream ships the watched env-bootstrap" \
  "/$seam_bootstrap"

seam_fixture() {
  local home=$1 src dst
  mkdir -p "$home/usr/share/omarchy/default/bash" "$home/etc"
  for src in "$seam_env:env.sh" "$seam_rc:rc.sh"; do
    dst=${src#*:}
    sed -e "s|/usr/share/omarchy|$home/usr/share/omarchy|g" \
      -e "s|/etc/omarchy.conf|$home/etc/omarchy.conf|g" \
      "$ROOT/${src%%:*}" >"$home/$dst"
  done
  sed -e "s|/usr/share/omarchy|$home/usr/share/omarchy|g" \
    -e "s|/etc/omarchy.conf|$home/etc/omarchy.conf|g" \
    "/$seam_bootstrap" >"$home/$seam_bootstrap"
}

# The env tier's whole job: OMARCHY_PATH exported with no interactive shell in
# sight, which is what `ssh box somecommand` gets. The pre-crumb .bashrc left
# it unset because its Omarchy block sat below the interactivity guard.
home=$(make_home)
seam_fixture "$home"
out=$(env -u OMARCHY_PATH bash -c \
  "source '$home/env.sh' 2>/dev/null; echo \${OMARCHY_PATH:-UNSET}")
assert_equals "seam: the env tier exports OMARCHY_PATH non-interactively" \
  "$out" "$home/usr/share/omarchy"

# ...and nothing else. rc is present here, so a stray source in this tier would
# show up — that is the regression the split exists to prevent, and it is
# invisible in a shell that happens to be interactive.
mkdir -p "$home/usr/share/omarchy/default/bash"
# The stub mirrors the shape that matters: upstream's rc ends in
# `[[ $- == *i* ]] && bind -f ...`, so sourcing it non-interactively returns 1.
# A stub that returned 0 would make the $? assertion below unfalsifiable.
{
  echo 'echo SEAM-RC-SOURCED'
  echo '[[ $- == *i* ]] && :'
} >"$home/usr/share/omarchy/default/bash/rc"
out=$(env -u OMARCHY_PATH bash -c "source '$home/env.sh'" 2>/dev/null)
assert_not_contains "seam: the env tier does not source Omarchy's rc" \
  "$out" "SEAM-RC-SOURCED"
# rc's last line is `[[ $- == *i* ]] && bind -f ...`, so sourcing it
# non-interactively returns 1. Sourcing only the env tier must leave $? clean.
env -u OMARCHY_PATH bash -c "source '$home/env.sh'" >/dev/null 2>&1
assert_equals "seam: the env tier leaves \$? at 0" "$?" "0"

# The rc tier, sourced the way crumb's .bashrc would: env tier first, this one
# after the guard. Present rc must actually be loaded — without this the
# silence test below would pass on a guard that never fires.
out=$(env -u OMARCHY_PATH bash -c \
  "source '$home/env.sh'; source '$home/rc.sh'" 2>/dev/null)
assert_contains "seam: the rc tier sources Omarchy's rc when present" \
  "$out" "SEAM-RC-SOURCED"
# ...and under `set -u` too. The guard's `${OMARCHY_PATH:-}` default exists for
# the unset case only; if it ever swallowed a value that IS set, this repo would
# have traded an aborted shell for a silently unloaded rc — a behaviour change
# rather than the hardening it is meant to be.
out=$(env -u OMARCHY_PATH bash -c \
  "set -u; source '$home/env.sh'; source '$home/rc.sh'" 2>/dev/null)
assert_contains "seam: the rc tier sources Omarchy's rc under set -u" \
  "$out" "SEAM-RC-SOURCED"

# rc absent: a bare `source` errors on every shell, which is exactly what a
# machine without Omarchy is. Nothing may reach stderr.
home=$(make_home)
seam_fixture "$home"
err=$(env -u OMARCHY_PATH bash -c \
  "source '$home/env.sh'; source '$home/rc.sh'" 2>&1 >/dev/null)
assert_equals "seam: the rc tier is silent when Omarchy's rc is absent" "$err" ""

# Dev-link. /etc/omarchy.conf is written by omarchy-dev-link, and a dev-linked
# checkout has to win over the packaged path — otherwise the rc tier below loads
# the package's rc out from under a dev-linked tree. Fixture /etc, never the
# real one.
home=$(make_home)
seam_fixture "$home"
mkdir -p "$home/dev/omarchy/bin"
echo "OMARCHY_PATH=$home/dev/omarchy" >"$home/etc/omarchy.conf"
out=$(env -u OMARCHY_PATH HOME="$home" bash -c \
  "source '$home/env.sh' 2>/dev/null; echo \${OMARCHY_PATH:-UNSET}")
assert_equals "seam: dev-link's OMARCHY_PATH wins over the packaged default" \
  "$out" "$home/dev/omarchy"
# ...and only then is $OMARCHY_PATH/bin prepended. On a production install the
# omarchy-* binaries are already /usr/bin/omarchy-*, so prepending would be noise.
assert_contains "seam: dev-link prepends its own bin" \
  "$(env -u OMARCHY_PATH HOME="$home" PATH=/usr/bin bash -c \
    "source '$home/env.sh' 2>/dev/null; echo \$PATH")" \
  "$home/dev/omarchy/bin:/usr/bin"

# Dev-link absent, with a stale value inherited from the environment: the
# packaged default must be forced, not the stale value preserved. This is the
# staleness reasoning the hand-rolled block carried and upstream's file now
# carries; without this assertion the file could simply pass OMARCHY_PATH
# through and every test above would still be green.
home=$(make_home)
seam_fixture "$home"
out=$(env OMARCHY_PATH=/stale/dev/link HOME="$home" bash -c \
  "source '$home/env.sh' 2>/dev/null; echo \${OMARCHY_PATH:-UNSET}")
assert_equals "seam: no dev-link forces the packaged default over a stale value" \
  "$out" "$home/usr/share/omarchy"

# User tool paths are APPENDED, so system binaries keep precedence — and so
# crumb's own env.d/10-pnpm.sh and env.d/20-local-bin.sh, which run after this
# file and prepend, stay in front of them. An upstream switch from append to
# prepend would silently reorder every non-interactive shell, which is what the
# watch on this file exists to catch.
out=$(env -u OMARCHY_PATH HOME="$home" PATH=/usr/bin bash -c \
  "source '$home/env.sh' 2>/dev/null; echo \$PATH")
assert_equals "seam: the env tier appends the user tool paths behind /usr/bin" \
  "$out" "/usr/bin:$home/.local/share/mise/shims:$home/.local/bin"

# Omarchy absent — a machine without it is crumb's whole premise, and the guard
# is the only thing standing between that machine and an error on every shell,
# interactive or not.
home=$(make_home)
seam_fixture "$home"
rm -f "$home/$seam_bootstrap"
err=$(env -u OMARCHY_PATH HOME="$home" bash -c "source '$home/env.sh'" 2>&1 >/dev/null)
assert_equals "seam: the env tier is silent when env-bootstrap is absent" "$err" ""
# And $? stays clean. The guard is the last thing in the file, so a false guard
# would hand 1 to whatever crumb's tier-1 loop did next — the same trap that
# keeps the rc tier post-guard. The trailing `:` is what holds this.
env -u OMARCHY_PATH HOME="$home" bash -c "source '$home/env.sh'" >/dev/null 2>&1
assert_equals "seam: the env tier leaves \$? at 0 with env-bootstrap absent" "$?" "0"

# The rc tier does NOT do the same, and that asymmetry is the point of these two
# assertions. Its guard is also the last line of its file, but it carries no
# trailing `:`, so on this same no-Omarchy machine it returns 1. That is the
# behaviour both drop-ins now document: safe because crumb's tier-2 loop is
# followed by a `[[ ]]` test and an `unset -v` that overwrite $? before anything
# reads it, and deliberately left alone rather than "fixed" to match tier 1.
# Pinned so a future `:` added to the rc tier arrives as a deliberate change to
# this file instead of a silent behaviour change nothing notices.
env -u OMARCHY_PATH HOME="$home" bash -c "source '$home/rc.sh'" >/dev/null 2>&1
assert_equals "seam: the rc tier leaves \$? at 1 with Omarchy absent" "$?" "1"
# And the asymmetry itself, both tiers in one shell in crumb's order, so the
# assertion that fails names the pair rather than one half of it. Either tier
# growing or losing its trailing `:` moves this string.
out=$(env -u OMARCHY_PATH HOME="$home" bash -c \
  "source '$home/env.sh' >/dev/null 2>&1; printf '%s ' \$?
   source '$home/rc.sh' >/dev/null 2>&1; printf '%s' \$?")
assert_equals "seam: the two tiers' no-Omarchy exit statuses differ deliberately" \
  "$out" "0 1"

# ...and the chain survives `set -u`. This is the second half of Omarchy being
# absent, and it only became reachable when the env tier stopped hand-rolling
# the OMARCHY_PATH block: the hand-rolled version exported a path
# unconditionally, so the variable was always set and an unguarded read of it
# could not fail. Upstream's env-bootstrap is sourced through a guard, so on a
# machine without Omarchy the variable is legitimately UNSET — and under
# `set -u` an unguarded `$OMARCHY_PATH` read is not a false guard handing on a
# 1, it is an aborted shell. Bash prints "OMARCHY_PATH: unbound variable" and
# nothing below it in the drop-in chain runs at all. `${OMARCHY_PATH:-}` in the
# rc tier's guard is what holds this. Both tiers, in crumb's order.
out=$(env -u OMARCHY_PATH HOME="$home" bash -c \
  "set -u; source '$home/env.sh'; source '$home/rc.sh'; echo SEAM-SURVIVED" 2>/dev/null)
assert_equals "seam: the drop-in chain survives set -u with OMARCHY_PATH unset" \
  "$out" "SEAM-SURVIVED"
# Surviving is not enough: an abort inside a sourced file writes to stderr, and
# so does an unguarded read that somehow does not abort. Nothing may reach it.
err=$(env -u OMARCHY_PATH HOME="$home" bash -c \
  "set -u; source '$home/env.sh'; source '$home/rc.sh'" 2>&1 >/dev/null)
assert_equals "seam: the drop-in chain is silent under set -u with OMARCHY_PATH unset" \
  "$err" ""
# The rc tier on its own, so a regression names the tier that owns the read
# rather than pointing at the whole chain. Whether Omarchy's rc exists is not
# the variable here — the variable is whether the guard can be evaluated at all.
err=$(env -u OMARCHY_PATH HOME="$home" bash -c "set -u; source '$home/rc.sh'" 2>&1 >/dev/null)
assert_equals "seam: the rc tier's guard evaluates with OMARCHY_PATH unset" \
  "$err" ""

# The board resolves a manifest path against either checkout. Every entry used
# to be a plugins-repo path, so a rice-repo path read as missing from the repo.
home=$(make_home)
mkdir -p "$home/shokupan/.config/bash"
echo "# drop-in" >"$home/shokupan/.config/bash/50-omarchy-rc.sh"
echo "upstream v1" >"$home/upstream-rc"
printf '.config/bash/50-omarchy-rc.sh %s %s watch\n' "$home/upstream-rc" \
  "$(sha256sum "$home/upstream-rc" | awk '{print $1}')" \
  >"$home/shokupan/packages/forks"
out=$(loaf_run "$home" forks)
status=$?
assert_not_contains "forks: finds a manifest path in the rice repo" \
  "$out" "missing from the repo"
assert_equals "forks: a rice-repo watch exits 0" "$status" "0"


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
