---
status: proposed
---

# Bake off druk, Helix and Neovim as the terminal editor

> Still proposed after the quattro migration (2026-08-09): editors run inside the
> terminal and nothing here touches the bar, launcher or Hyprland config layers
> quattro rewrote — unaffected, awaiting its bakeoff.

Decided: a three-way comparison. Keep **Neovim** installed, add **druk**, and add
**Helix** as a third option, then use them and see which wins. This is explicitly an
addition for comparison, not a replacement — no decision is being made about removing
anything.

Zed stays the editor for everything outside a terminal, and is unaffected by this. It
is already the tracked editor here, so whatever wins only has to be better than the
others *in a terminal* — it does not have to displace Zed.

**Fallback if druk does not stick: learn Neovim.** Stated outright, so this ADR
cannot become an excuse to keep shopping. The current position is simply
disinterest, not a judgement that Neovim is wrong.

## Why Neovim is not sticking

The objection is **the keybindings, plus incomplete mouse support** — not modal
editing in the abstract, and not a belief that Neovim is bad. Specifics, because
they predict what an alternative has to get right:

- Mouse support "exists but not everywhere", which is the worst case for a newcomer:
  you cannot tell where it will work.
- The `space+e` file-explorer flow was disliked on first contact.
- Resizing while the file tree is open reads as **inverted**: `ctrl+`-arrow-right
  (or similar) *shrinks* the tree, so it feels like the editor is pushing the
  sidebar rather than the sidebar being sized. That "flying on inverted controls"
  reaction was taken as evidence that the rest of the keymap would land the same
  way.
- Stated position: not interested in remapping Neovim to fix this.

That last point matters for scoping. Since rebinding is off the table, this is not
"configure Neovim better" — it is a genuine search for a tool whose defaults fit,
which is what makes trying a second editor worthwhile rather than avoidance.

## Unverified

`druk` is not installed and I have not confirmed the project. Its feature set,
maturity, and whether it is a modal editor at all are unestablished. Identify the
project first.

## The third candidate

[Helix](https://helix-editor.com/) is in because its whole pitch is the complaint
above: it is *selection-first* rather than verb-first, so you pick the target then the
action (`w` selects a word, `d` deletes the selection) instead of Vim's `dw`. That
inverts the direction that felt backwards. It ships a complete default keymap and
built-in LSP, so there is nothing to configure and nothing to remap — which matters
given remapping is off the table.

It is also nearly free to try: `helix.toml` ships in **every** Omarchy theme directory
and `omarchy-restart-helix` exists, so it is one `pacman -S` and arrives themed.

Its real value in the bake-off is diagnostic. Neovim and Helix are both modal, so if
Helix feels fine, the objection was Vim's *grammar*; if it feels the same, the
objection is modal editing itself — and that would make druk (or Zed) the answer
rather than any Vim-alike.

## Theming is not a criterion

Explicitly deprioritised. druk is reported to ship plenty of themes of its own, and
that is good enough — matching the active Omarchy Theme is not a requirement for any
of the three.

Worth keeping the distinction straight for later, though, since it is not the same
thing: shipping many built-in themes means you can *pick* a good one once. Following
`omarchy theme set` automatically is a separate mechanism, and anything outside
Omarchy's known set needs a `~/.config/omarchy/themed/*.tpl` template to do it. Helix
gets that for free; druk would not. Not a reason to prefer Helix — just not a surprise
to discover later.

## What the decision still depends on

- **What a terminal editor is for here that Zed is not.** With Zed settled for
  out-of-terminal work, the honest use case is most likely editing over SSH — which
  ties the value of this whole ADR to ADR-0016. If remote never happens, the terminal
  editor matters much less.
- Neovim is untracked in this repo precisely because it is still an unmodified LazyVim
  starter with nothing personal in it. Whoever wins should get its config tracked, or
  the bake-off result will not survive a rebuild.
