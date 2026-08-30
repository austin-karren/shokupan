---
status: accepted
---

# Personal identity lives behind untracked includes, not in the repo

The repo is public, so no tracked file may contain a name or email address.
Rather than templating or scrubbing on install, tracked configs end with an
include of a machine-side Identity file that the repo never sees:
`~/.config/git/config` includes `~/.gitconfig.local`, which is gitignored.

Chosen over the alternatives — a private repo (loses the ability to share the
rice), or `git config --local` per clone (does not apply to a home directory).

## Consequences

A missing include fails **silently**. Git does not warn about an unreadable
include path; it just rejects the commit with "please tell me who you are". That
is the symptom to recognise, and the README documents it as the first thing to
check on a fresh machine.

Because *something* installs `~/.config/git/config`, git ignores `~/.gitconfig`
entirely — it reads the latter only when the former does not exist. A stray
`~/.gitconfig` is a red herring. (Which repo installs it changed on 2026-08-19;
see the amendment below. The behaviour does not depend on which.)

Applied to `~/.XCompose` on 2026-08-09: the identity expansions moved to
`~/.XCompose.local` behind an `include`, and the rest is tracked (ADR-0010).
Same pattern, one sharper failure mode — a *missing* include file there aborts
the whole compose table rather than failing one commit, so the README documents
that an empty file is enough to parse.

**Verified under quattro, 2026-08-09.** All three includes hold on the upgraded
machine: `~/.config/git/config` is a live symlink into a repo, ends in the
`~/.gitconfig.local` include, and `git config user.email` resolves through it;
no stray `~/.gitconfig` exists. Every commit in the quattro migration was made
through this path.

## Amendment, 2026-08-19 — the git half moved to `crumb`

The decision is unchanged and still followed. Only *which repo* installs the
tracked half moved: `~/.config/git/config` and `.bashrc` left this repo for
`crumb`, and `~/.config/git/config` is now a live symlink into `~/crumb`, not
into here. `crumb`'s tracked `.config/git/config` still carries no name and no
email, and still ends in the `~/.gitconfig.local` include — which is why this
ADR is amended rather than superseded: the alternatives rejected above
(templating, a private repo, `git config --local`) are still rejected, and
`crumb` being private does not change that, because `crumb` scrubs identity out
of its tracked files exactly as this repo does.

One thing did change: `user.name` was previously tracked, and moved out to
`~/.gitconfig.local` beside `user.email`. The Identity file now holds both.

The silent-failure consequence above is intact — a missing
`~/.gitconfig.local` still produces "please tell me who you are", from the same
git and for the same reason. It is simply a different repo's include that is
dangling. This repo's README points at `crumb` rather than documenting the file
itself.

`~/.XCompose` / `~/.XCompose.local` did not move; `.XCompose` stayed in the
rice, so that paragraph reads as written.

## Amendment, 2026-08-20 — `crumb` went public

The amendment above says "`crumb` being private does not change that". That
sentence was true when written and is left standing as the record of the
2026-08-19 reasoning; `crumb` was flipped **public** on 2026-08-20 and now
carries a description, topics and an MIT LICENSE.

The decision is unaffected, and in the one direction that matters it is
strengthened: privateness was never what kept identity out of `crumb`'s tracked
files — the include pattern was, and `crumb` follows it. A private repo remains
a rejected alternative here, and no tree that holds a shell or git config is
unpublished any more: of the three self-stowing trees in ADR-0002, `shokupan`
and `crumb` are both public and only `claude-config` is private. The rule "no
tracked file may contain a name or email address" is what protects the two that
are published, and it now protects the `.bashrc` and git config as well as the
rice.
