# shellcheck shell=bash
# A sourced fragment, so there is no shebang for shellcheck to read the
# dialect from — and /etc/omarchy.conf is machine state, not a repo input it
# can follow.
# shellcheck disable=SC1091

# The rice's Omarchy arm, first tier — extracted from .bashrc so the .bashrc
# itself can become desktop-agnostic and live in crumb. Everything
# Omarchy-coupled stays in the rice; crumb knows nothing about Omarchy and only
# provides the seam that reads this directory. The dependency points one way on
# purpose.
#
# TIER: ~/.config/bash/env.d/*.sh, sourced BEFORE crumb's
# `[[ $- != *i* ]] && return`. Only the environment belongs here — the variable
# is what a non-interactive shell needs, and the non-interactive shells that
# reach this file are the ones whose fd 0 is a connected socket. Bash sources
# ~/.bashrc for those without any `-i`; `systemd-run --user --pipe` is the
# measured live case. Pre-guard is what gets OMARCHY_PATH into them.
#
# It is NOT what gets OMARCHY_PATH into `ssh box somecommand`. That path reads
# no startup file here at all, so neither tier runs and tier placement decides
# nothing about it — see shokupan ADR-0049 for the mechanism (this bash lacks
# SSH_SOURCE_BASHRC and this sshd is built with USE_PIPES, so fd 0 is a pipe).
# `PATH` still arrives there, via Omarchy's pam_env line, not via this file.
#
# Numbered 00- because it must run before anything that reads OMARCHY_PATH,
# which includes the second-tier .config/bash/50-omarchy-rc.sh that loads
# Omarchy's interactive rc from under it.
#
# This is the same division upstream draws in /usr/share/omarchy/default/bashrc:
# the environment above the interactivity guard, the rc below it. The aliases,
# functions, completions and key bindings in that rc have no business running
# in a non-interactive shell.

# Upstream's own single source of truth for OMARCHY_PATH + PATH, sourced by
# /etc/profile.d/omarchy.sh, /etc/skel/.bashrc, /usr/share/uwsm/env.d/10-omarchy
# and default/bash/envs. It carries the /etc/omarchy.conf dev-link staleness
# handling this file used to hand-roll — /etc/omarchy.conf is written by
# omarchy-dev-link and reset by omarchy-dev-unlink, and when absent the packaged
# default is forced rather than a stale inherited value preserved — for the same
# reason and with the same result. By the stock-first rule the hand-rolled block
# stopped earning its keep once upstream absorbed it.
#
# It also does PATH work the old block did not: the dev-link `$OMARCHY_PATH/bin`
# prepend (production installs skip it — the binaries are already /usr/bin/omarchy-*),
# and an APPEND of ~/.local/share/mise/shims and ~/.local/bin so system binaries
# keep precedence. Both appends land behind /usr/bin, and behind whatever crumb's
# own env.d/10-pnpm.sh and env.d/20-local-bin.sh prepend after this file runs.
# On a machine carrying Omarchy's PAM PATH line (install/config/ssh-command-path.sh)
# the two appends are already satisfied and PATH comes out byte-identical.
# The two are about disjoint shell paths, though, and neither backs the other up:
# this file runs only where ~/.bashrc is read, and the PAM line exists precisely
# for the path where it is not. Agreeing on PATH is a coincidence worth having,
# not a fallback.
#
# Guard shape copied from upstream's own /etc/skel/.bashrc. The trailing `:` is
# ours: this is the last line of a drop-in that crumb's tier-1 loop sources, and
# a false guard on the last line would hand $? = 1 to whatever ran next on a
# machine without Omarchy — the same trap that keeps 50-omarchy-rc.sh post-guard.
#
# Recorded as a `watch` in packages/forks against THIS file: nothing is copied,
# but the path and the variables it establishes are depended on whole.

# The second tier is deliberately the other way round, and that asymmetry is a
# decision rather than a loose end: .config/bash/50-omarchy-rc.sh ends on its
# guard with NO trailing `:`, so on a machine without Omarchy that drop-in
# returns 1. It is safe there because crumb's tier-2 loop is followed by a
# `[[ ]]` test and an `unset -v`, and the `unset` succeeds unconditionally — $?
# is 0 again before any caller sees the 1. This tier has no such backstop: it is
# sourced by every shell that reads ~/.bashrc — interactive and socket-stdin
# alike, not just interactive ones — and its 1 would escape into whatever crumb
# does next.
# So the `:` belongs here and its absence belongs there. Do not "fix" either
# file to match the other; test/loaf-test.sh pins the no-Omarchy exit status of
# both tiers so that either change has to be argued for. The full reasoning is
# in 50-omarchy-rc.sh's closing comment.
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap
:
