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

Because the repo installs `~/.config/git/config`, git ignores `~/.gitconfig`
entirely — it reads the latter only when the former does not exist. A stray
`~/.gitconfig` is a red herring.

Applied to `~/.XCompose` on 2026-08-09: the identity expansions moved to
`~/.XCompose.local` behind an `include`, and the rest is tracked (ADR-0010).
Same pattern, one sharper failure mode — a *missing* include file there aborts
the whole compose table rather than failing one commit, so the README documents
that an empty file is enough to parse.

**Verified under quattro, 2026-08-09.** All three includes hold on the upgraded
machine: `~/.config/git/config` is a live symlink into the repo, ends in the
`~/.gitconfig.local` include, and `git config user.email` resolves through it;
no stray `~/.gitconfig` exists. Every commit in the quattro migration was made
through this path.
