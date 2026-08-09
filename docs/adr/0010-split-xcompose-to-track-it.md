---
status: accepted
---

# Split ~/.XCompose so its identity lines can stay untracked

`~/.XCompose` was the last config deliberately left untracked purely because of
identity: it defines `<Multi_key> <space> <e>` and `<space> <n>` as literal
email/name expansions, and the repo is public. The ADR-0003 pattern now applies —
the repo tracks a `.XCompose` that ends with an include of a machine-side
`~/.XCompose.local` holding only the identity expansions.

XCompose supports this natively; the file already used `include` to pull in
Omarchy's emoji table, so no new mechanism was needed. The include uses `%H`,
XCompose's own home expansion, rather than a hard-coded path.

## The open questions, settled by implementing (2026-08-09)

**Whether the tracked remainder is worth a file** — yes, and not for the reason
proposed. The tracked file is what makes `loaf heal` defend the config: the
quattro upgrade rewrote `~/.XCompose` on 2026-08-09 and blanked both identity
expansions to `""`, exactly the silent-overwrite failure ADR-0028 exists for.
Untracked, nothing noticed. Tracked, the displacement check would have flagged it.

**Whether a missing `~/.XCompose.local` fails loudly** — worse than predicted,
and measured rather than assumed. The proposal guessed "dead keybind". In fact
xkbcommon (the parser behind fcitx5's compose support) treats a failed include as
fatal to the whole file:

    xkbcommon: ERROR: ~/.XCompose:10:9: failed to open included Compose file
    xkbcommon: ERROR: ~/.XCompose:10:9: failed to parse file

so *every* compose sequence dies, including the emoji table — not just the
identity binds. `~/.XCompose.local` therefore joins `~/.gitconfig.local` in the
README's **Required** section, not the optional one. Even an empty file makes the
parse succeed.

**Whether `omarchy-restart-xcompose` belongs in the install flow** — it is just
`omarchy-restart-app fcitx5`, needed once after stowing. A README line covers it;
wiring it into install machinery for a one-shot would be ceremony.

## Verified

Driven through libxkbcommon's compose API (the same parser fcitx5 uses), against
the live `~/.XCompose` symlink with both includes in place:

- table parses under `en_US.UTF-8`
- `<Multi_key> <s> <m>` → `℠` (Omarchy's emoji table, through include #1)
- `<Multi_key> <space> <e>` and `<space> <n>` compose through include #2 —
  currently to `""`, faithfully preserving what the quattro upgrade left; the
  real values need re-entering in `~/.XCompose.local`
- with `.local` removed: total parse failure, as documented above

The pre-split file is kept as `~/.XCompose.displaced.<epoch>`.
