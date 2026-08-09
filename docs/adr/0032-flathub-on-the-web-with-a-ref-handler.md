---
status: accepted
---

# Flathub on the web, with a ref handler

> **Verified under quattro, 2026-08-09.** The decision and the handler survive
> whole; the watcher in the export story changed name. Measured: both mimetypes
> still resolve to `flatpakref-install.desktop` (`xdg-mime query default` on
> each), the desktop entry is a live symlink into the repo, Shelly and its
> Flatpak backend are still installed, and both export directories exist with
> the system one carrying Dawn and Eloquent. Elephant — the watcher the export
> section below is written around — was uninstalled by the upgrade. Its role
> passed to quattro's launcher, which subscribes to Quickshell's
> `DesktopEntries.applications.onValuesChanged`, and the quickshell process has
> both Flatpak `exports/share` paths on `XDG_DATA_DIRS` (read from its
> environ). So exports still become launcher-visible without a restart, by a
> different subscriber. The migration that pre-creates the export directories
> stays applied and stays right: it exists so *whatever* watches the path has a
> directory to attach to before the first install, and that constraint is not
> Elephant's — it is inotify's.
>
> **Execution path proven later the same day, from `xdg-open` in.** The earlier
> pass verified registration; this one ran the chain:
> `xdg-open 'flatpak+https://…org.gnome.Calculator.flatpakref'` resolved to the
> handler, spawned ghostty (`Exec=ghostty -e … %u`, ghostty 1.3.1 present), the
> script translated the scheme URL to https and handed it to
> `flatpak install --from` — screenshot shows its "Installing from:" banner. The
> terminal was killed at the prompt; `flatpak list` confirms nothing installed.
> Every tracked web-app entry was batch-validated: Exec resolves
> (`omarchy-launch-webapp` lives at the package path now), every absolute Icon
> path exists, every entry is a live symlink; Gmail's window confirmed on screen.
> The one link still unproven is the browser's own half — Helium handing the
> scheme to `xdg-open` when the Flathub Install button is clicked needs a real
> click in the browser, which no script can stand in for.

Flatpaks are browsed on flathub.org in the browser and installed by handing the
Ref to `flatpakref-install`, a terminal wrapper around `flatpak install --from`.
No store GUI is the browse surface.

Shelly remains the package manager for the pacman repos and the AUR, and its
Flatpak backend is installed (`shelly-flatpak-backend`, in the Manifest) so its
Flatpak tab works. It is simply not where Flatpaks get found.

## Why not a store GUI

The obvious path was to install a Flatpak store — Bazaar is four packages on this
box, GNOME Software and Discover drag in a desktop environment's worth of
plumbing. All three were rejected on the same ground: flathub.org's own interface
is better than any of them, and a store is one more surface to theme, update and
keep working after an Omarchy update.

Shelly's Flatpak tab is kept as a fallback and as the way to *manage* what is
already installed. Browsing there is not the intent.

## The scheme was taken from Shelly

flathub.org's Install button emits a `flatpak+https://` URL. Shelly registers
`x-scheme-handler/flatpak+https` and routes it into its own GUI, which did not
result in an install. It does **not** register `application/vnd.flatpak.ref`, so
the downloaded fallback file had no handler at all.

`flatpakref-install` now claims both, which is the one genuinely intrusive part of
this decision: it overrides an association a system package set up. Reverting is a
single command, and worth knowing about before wondering why Shelly stopped
answering the browser.

    xdg-mime default com.shellyorg.shelly.desktop x-scheme-handler/flatpak+https

The handler accepts all three forms the browser can produce — the `flatpak+https`
URL, a `file://` URL of a downloaded Ref, and a bare path — because which one
arrives depends on whether the browser hands off the scheme or falls back to
downloading.

## Export directories are created up front

A Flatpak becomes visible in the Launcher by Exporting a desktop entry into
`exports/share/applications`. Elephant watches that path, but **a watch cannot be
attached to a directory that does not exist**, and Flatpak does not create one
until the first app is installed.

This cost an hour of confusion once: Dawn installed correctly, exported
correctly, and never appeared in the Launcher, because Elephant had started 29
minutes before the directory existed. Nothing was misconfigured and nothing in
the environment was wrong — `XDG_DATA_DIRS` was correct in Walker, Elephant and
Hyprland alike. The app appeared after a restart of Elephant, which reads as the
Launcher being broken rather than as a watch that was never established.

A migration creates both export directories unconditionally, so the watch is
attached at every boot whether or not anything is installed there yet. Verified
afterwards by uninstalling and reinstalling Dawn with Elephant untouched
(`NRestarts=0`, up three minutes before the entry was written).

Worth noting a pacman hook could never have fixed this: Flatpak installs do not
go through pacman, so no `[Trigger]` would ever match. The standard mechanism
here is the launcher's own inotify watch, and the only requirement is that there
be something to watch.

## Consequences

- Installs are system-wide and prompt through polkit. Adding `--user` to the
  handler would remove the prompt and put apps under `~/.local/share/flatpak`
  instead; the export directory for that path is created either way.
- Each app installed from a Ref leaves an Origin remote behind, `no-enumerate`,
  named after the Ref rather than after Flathub. This is normal and is what makes
  the app updatable; declining "keep the remote" only stops it being searched.
- AppImages are a Source Shelly also supports and this decision says nothing
  about them. Untested — the first one installed may hit the same export problem.
