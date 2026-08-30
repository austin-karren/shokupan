---
status: proposed
---

# Manage git worktrees with worktrunk instead of by hand

> Still proposed after the quattro migration (2026-08-09): a git-side tooling
> choice with no contact with the desktop layers quattro rewrote — unaffected,
> awaiting its grilling.

Intent: stop driving `git worktree` directly and use **worktrunk** to manage
worktrees.

> **Intent recorded, not yet grilled.** The *want* is settled; the *how* is
> deliberately undecided. Nothing below has been agreed — treat it as the
> question list for a later session, not as a plan.

## Unverified

`worktrunk` is not installed and I have not confirmed the project. Nothing about
its behaviour is established here.

## What the decision depends on

- **What the actual pain is.** "Rawdogging worktrees" covers several different
  problems — remembering the `git worktree add` invocation, deciding where trees
  live on disk, per-tree setup after creation (installing dependencies, copying
  untracked `.env` files), and cleaning up merged trees. A tool that fixes one may
  not touch the others. Naming the specific friction first will make it obvious
  whether this needs a tool or three shell aliases.
- **Interaction with the identity split.** Per ADR-0003, `~/.gitconfig.local` is a
  home-directory include, so it applies to every worktree automatically. Any tool
  that writes per-repo or per-tree git config should not be allowed to reintroduce
  an email into a tracked file.
- **Where it gets recorded.** If this becomes part of the workflow it belongs in
  the package list here, or in `~/.config/git/config`'s aliases — which is
  `crumb`'s file since 2026-08-19, not this repo's (ADR-0003 amendment) — so a
  rebuilt machine has it.
