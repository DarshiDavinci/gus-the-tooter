# Gus

Gus lives just below the bottom edge of your screen. Every so often he pops up,
holding on with both hands. Click him and he farts: one of seven toots, with a
green cloud. Ignore him and he ducks back down.

This app starts and stops him, and sets how often he shows up, how long he
waits, the volume, and which toots he does. Changes reach Gus right away. He
keeps lurking after you close the window.

Gus himself is a Quickshell overlay (`overlay/shell.qml`). It catches clicks
only on Gus, so the rest of your screen works as usual. His faces and sounds
are generated at build time by `overlay/make_assets.py`, so no audio files are
downloaded.

## Shortcuts

| Key   | Does                       |
|-------|----------------------------|
| Space | Start or stop Gus          |
| S     | Summon Gus now             |
| M     | Sound on or off            |
| P     | Play a toot                |
| ?     | Show or hide shortcuts     |
| Q     | Quit (Gus keeps running)   |

## Build and install

```sh
bin/build     # build/gus, with the overlay in build/overlay
bin/test      # backend, theme and translator tests, offscreen
bin/install   # makepkg -fsi, so Gus appears in the app launcher
```

Settings live in `~/.config/gus/settings.json`.
