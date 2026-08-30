# shellcheck shell=bash
# A sourced fragment, so there is no shebang for shellcheck to read the
# dialect from — and Omarchy's rc is machine state, not a repo input it can
# follow.
# shellcheck disable=SC1091

# The rice's Omarchy arm, second tier: Omarchy's interactive shell — aliases,
# functions, completions, key bindings, prompt.
#
# TIER: ~/.config/bash/*.sh, sourced AFTER crumb's
# `[[ $- != *i* ]] && return`, which is where upstream puts this same source in
# /usr/share/omarchy/default/bashrc (environment above the guard, rc below it).
# Post-guard on purpose, two reasons:
#
#   - None of what rc pulls in — envs, shell, aliases, functions, init, and
#     `bind -f inputrc` — has any business in a non-interactive shell. Pre-guard
#     it would run `mise activate bash`, `zoxide init` and bash-completion for
#     ~28 ms in every shell that reads ~/.bashrc without being interactive —
#     any shell whose fd 0 is a connected socket, `systemd-run --user --pipe`
#     being the measured case — and in the non-interactive login shells that
#     reach it through /etc/profile.d. Not `ssh box somecommand`: that path
#     reads no startup file at all here, so there is nothing to skip
#     (shokupan ADR-0049). The cost is real; the example used to be wrong.
#   - rc's last line is `[[ $- == *i* ]] && bind -f ...`, so sourcing it
#     non-interactively returns 1. Pre-guard that left $? at 1 for whatever
#     crumb's drop-in loop did next.
#
# OMARCHY_PATH is already exported by the first tier,
# .config/bash/env.d/00-omarchy.sh. Numbered 50- to sit after anything crumb
# wants to establish first and before anything that overrides an Omarchy alias.

# Guarded, which the .bashrc line this replaces was not: a bare
# `source "$OMARCHY_PATH/default/bash/rc"` errors on every single shell when
# Omarchy is absent, and a no-Omarchy machine is the whole reason crumb exists.
# Guard shape copied from upstream's own /usr/share/omarchy/default/bashrc:
#
#   [[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap
#
# `${OMARCHY_PATH:-}`, not `$OMARCHY_PATH`: the first tier sources upstream's
# env-bootstrap through a guard of its own, so on a machine without Omarchy the
# variable is not set to a dead path — it is never set at all. Under `set -u`
# that turns this guard from false into "unbound variable", which aborts the
# shell before anything below this drop-in in crumb's tier-2 loop runs. The
# default expands to the same empty string the unguarded read expands to
# without `set -u`, so the guard stays false on a no-Omarchy machine either
# way; nothing about the Omarchy-present path changes. Both halves carry the
# default, not just the test: the two must expand identically, or a readable
# /default/bash/rc would send the source down a path the guard never checked.
#
# Recorded as a `watch` in packages/forks against THIS file, since this is the
# one that loads upstream's rc whole and depends on its internal structure.

# No trailing `:` on that guard, and the asymmetry with the first tier is
# deliberate rather than an oversight. The guard is the last line of this file,
# so on a machine without Omarchy it evaluates false and this drop-in returns 1
# — where .config/bash/env.d/00-omarchy.sh ends on a bare `:` and returns 0.
# The two tiers are not in the same position:
#
#   - Tier 1 runs in every shell that reads ~/.bashrc — interactive shells and
#     socket-stdin non-interactive ones alike — and what follows crumb's tier-1
#     loop can read $?. A 1 escaping there is the trap the `:` in that file
#     exists to close. (It does not run over `ssh box somecommand`; nothing
#     does. That path is irrelevant to this argument, which only needs shells
#     where a stray 1 has somewhere to escape to. See shokupan ADR-0049.)
#   - Tier 2 runs only in interactive shells, and crumb's tier-2 loop is
#     followed by `[[ $_crumb_nullglob == off ]] && shopt -u nullglob` and then
#     `unset -v _crumb_f _crumb_nullglob`. The `unset` succeeds
#     unconditionally, so $? is 0 again before anything can observe the 1.
#
# Nothing consumes this file's status today, so adding a `:` here would change
# an observable exit status from 1 to 0 to fix a problem no caller has —
# replacing working behaviour on inference. Left as it is on purpose.
#
# What would make the `:` correct is crumb's tier-2 loop no longer overwriting
# $? on its way out. That shape lives in crumb's .bashrc, not here, so re-read
# it before relying on this paragraph. test/loaf-test.sh pins the no-Omarchy
# exit status of both tiers, so adding a `:` to either file surfaces as a
# deliberate test change rather than a silent one.
[[ -r "${OMARCHY_PATH:-}/default/bash/rc" ]] && source "${OMARCHY_PATH:-}/default/bash/rc"
