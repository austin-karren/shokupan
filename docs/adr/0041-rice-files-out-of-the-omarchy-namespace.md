---
status: proposed
---

# Rice files leave the omarchy namespace where upstream's contract allows

The user's ask, verbatim: *"make our edits not happen in the omarchy files so we
can keep them seperate (easier to doctor and rice if my files aren't under the
omarchy name)."*

The boundary decision: files this rice owns should not live under
`~/.config/omarchy/*` names, where they sit shoulder to shoulder with files
Omarchy writes for itself. Ten tracked files live there today. When everything
in a directory looks upstream-named, three things get harder:

- **Doctoring.** `loaf doctor` tells ours from theirs by symlink-ness, which
  works but is invisible to a human running `ls` — and to any future check that
  wants to reason about a whole directory ("nothing of ours under X").
- **Ricing.** Editing "an omarchy file" and editing "our file that happens to
  live under omarchy's name" feel identical at the path level, which is exactly
  how accidental upstream edits happen.
- **Surviving upgrades.** The quattro upgrade already demonstrated the
  collision class: it wrote `bar.json` and dropped a
  `*.omarchy-upgrade-to-quattro.*.bak` *inside* `themed/`, right next to our
  template. Upstream treats that namespace as its own, because it is.

> **Proposed, not done.** This ADR is the survey and the shape of the fix. No
> file has moved. The move is a todo, and each row below says what it is
> waiting on.

## Survey: what is under the omarchy name today, and what holds it there

Measured against quattro's own source, not assumed. Two classes emerged.

### Movable — the path was a default, not a contract

> **Historical, 2026-08-15.** None of the five files below exist any more —
> `barcfg`, `calendar`, `omenu` and the `ratio`/`ratio-on` pair were all
> deleted or absorbed across the ADR-0044 waves and the r1744 upgrade. The
> `source`-key mechanism this section measured is still real and applies to
> whatever QML module comes next.

`plugins/bar/BarModel.js` (`customModulePath`) resolves a `type: "qml"` module
from an explicit **`source`** key first, with `~` expansion, and only falls
back to `<configDir>/bar/modules/<id>.qml` when none is given. So every custom
bar module can live anywhere the rice likes, declared per-entry in
`shell.json`:

| File | Move |
|---|---|
| `.config/omarchy/bar/modules/barcfg.qml` | → a rice-named home (e.g. `~/.config/shokupan/bar/`), with `"source": "~/.config/shokupan/bar/barcfg.qml"` in the entry |
| `.config/omarchy/bar/modules/calendar.qml` | same |
| `.config/omarchy/bar/modules/omenu.qml` | same |
| `.config/omarchy/bar/modules/ratio.qml` | same |
| `.config/omarchy/bar/modules/ratio-on.qml` | same |

### Fixed — the path *is* upstream's API

These locations are hardcoded in quattro's source; the files cannot leave, only
be clearly labelled as ours (they already are symlinks into the repo, which is
the machine-readable half of that):

| File | What pins it | Where it is pinned |
|---|---|---|
| `.config/omarchy/shell.json` | the shell's user-config path | `shell.qml:30` — `userConfigPath: home + "/.config/omarchy/shell.json"` |
| `.config/omarchy/extensions/omarchy-menu.jsonc` | the menu's user-extension path | `plugins/menu/Menu.qml:49` — same pattern |
| `.config/omarchy/hooks/post-update.d/10-loaf-heal` | `omarchy-hook` reads `~/.config/omarchy/hooks/<name>.d/` | `bin/omarchy-hook:14` |
| `.config/omarchy/hooks/theme-set.d/30-restore-wallpaper` | same | same |
| `.config/omarchy/themed/shell.toml.tpl` | the theme-template override directory convention | user templates outrank Omarchy's by living exactly there (ADR-0009's port) |

The fixed class is also the *defensible* class: each of these is a sanctioned
extension point — upstream's declared surface for user content — rather than an
upstream file we edited. Nothing of ours patches an Omarchy-owned file today;
the problem is purely that our sanctioned entries share a namespace with
upstream's own state (`bar.json`, `branding/`, upgrade `.bak` droppings).

> **Note 2026-08-15: `austinkarren.clock` is the sanctioned-clone exception to
> the `shokupan.*` id rule.** `omarchy-plugin-clone` derives the clone id as
> `$USER.<source-id>` — the prefix is upstream's own collision guard, and the
> shell routes the built-in's bar entry and IPC to the clone by exactly that
> id shape (`clonedFrom` + enabled). Renaming it into `shokupan.*` would buy
> namespace purity at the cost of leaving the sanctioned path, so clones keep
> the tool's name. The directory (`plugins/austinkarren.clock/`) is still a
> symlink into the repo, which remains the machine-readable "ours" marker.

## What the separation would look like

1. **A rice-named directory** — `~/.config/shokupan/` — stowed from the repo
   like everything else, holding every file whose location we control. The
   five bar modules move there; anything rice-owned added later starts there.
2. **`shell.json` entries gain explicit `source` keys** pointing at the new
   paths. `shell.json` is hot-reloaded, so the move is observable module by
   module with no shell restart.
3. **The fixed class stays put but becomes an allowlist.** `loaf doctor` grows
   a check: under `~/.config/omarchy`, the only *symlinks into the repo*
   permitted are the enumerated extension-point files; any new rice file
   appearing under the omarchy name fails the check. That makes the boundary
   enforced rather than remembered — the same move ADR-0028 made for
   symlink drift.
4. **`.config/omarchy/bar/` empties and is retired** from the repo once the
   modules move.

## Waiting on

- The bar work settling: `shell.json` and the modules are under active edit by
  the bar stream, and moving files mid-stream invites exactly the collisions
  this ADR is against.
- A decision nobody has made yet: whether the rice-named directory is
  `~/.config/shokupan/` (clean, one more top-level name) or a subtree of an
  existing tracked path. Bikeshed-sized, but it names the namespace forever.
- ~~Verifying `source` expansion end-to-end on one module before moving five~~
  — done 2026-08-10, incidentally: the audio underline fix registered
  `bar/modules/audio.qml` through an explicit
  `"source": "~/.config/omarchy/bar/modules/audio.qml"` entry in `shell.json`,
  and the `~` expansion resolved and loaded. The mechanism is proven; the move
  itself still waits on the other two items. Two lessons for whoever does it:
  the shell registers module *files* only at startup (`omarchy-restart-shell`
  after adding one — hot-reload covers edits, not additions), and a panel-type
  module hosted this way must keep its upstream id as the entry `id`
  (`findPanelWidget` matches `slot.moduleName`, or IPC summon breaks).
  *(Note 2026-08-12: `audio.qml` no longer exists — the wrapper reverted to
  stock `omarchy.audio` per ADR-0044 after the 2026-08-09 update broke its
  rebind. The `source`-expansion proof above stands as recorded, but no
  module currently uses a `source` entry.)*
