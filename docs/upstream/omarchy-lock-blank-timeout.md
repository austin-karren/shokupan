# Upstream comment: lock screen re-blanks 5 s after a wake keypress

**Status: posted 2026-11-23** as https://github.com/omacom/omarchy/issues/17042#issuecomment-7114668621 on omacom/omarchy#17042, which
reports this exact behavior and already asks for ~30 s or a setting. Same
5 s `idleBlankTimer` in #19946, #18926 and #15759, so no new issue: it would
be a duplicate.

## Comment

> _AI-drafted (Claude) on my behalf. Feel free to discard the wording; the request is what I'd like to discuss._

Same here on Omarchy 4.5.0-3 (Framework Desktop, BenQ over USB-C). I wake the lock screen with a key, the panel takes a second or two to light up, and it blanks again before I've started typing my password. So I wake it again, and again.

`idleBlankTimer.idleMs` is hardcoded at 5000 in `shell/plugins/lock/Service.qml`. Patching the file isn't a fix for users: it's owned by the `omarchy` package and every update puts the 5 s back.

Would you take either of these?
- an `idle.lockBlank` (seconds) key in `~/.config/omarchy/shell.json`, next to `idle.screensaver` and `idle.lock`; or
- a longer default. 15 s works well for me.

Happy to send a PR for the `shell.json` key if that's the direction you want.
