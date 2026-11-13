# Mini Player for YouTube Music

A minimal YouTube Music player for macOS, inspired by Mixlet. Sign in through the expanded player; website login data stays in WebKit's local data store.

## Controls

| Keys | Action |
| --- | --- |
| F7 / F8 / F9 | Previous track / play or pause / next track |
| `h` / `l` | Previous / next track |
| `j` / `k` (or `-` / `=`) | Volume down / up by 5 percentage points |
| `p` | Play or pause |
| `e` | Expand or collapse |
| `f` | Toggle hiding when the app loses focus |
| `s` | Snap to the current screen's default position |
| `t` | Toggle mini-player background |
| `q` | Quit |
| Escape | Collapse the expanded player |
| Space / Return, Left / Right | Play/pause, previous/next in mini mode |
| Cmd-E / Cmd-S / Cmd-T / Cmd-Q | Size / position / background / quit, including while typing |
| Cmd-R | Reload YouTube Music |

Letter shortcuts work in both modes, except while typing into a text field, editing content, or composing text. Holding a volume key repeats; holding a track key does not skip multiple tracks.

With standard function keys enabled in macOS, F7/F8/F9 work while the app is focused (Fn may be needed depending on your keyboard settings). The keyboard's media keys and Control Center use macOS Now Playing commands and can work in the background when macOS selects this app as the active player. Another playing app can take that role; ytm-min does not intercept other apps' keys globally or require Accessibility access.

## Build

Requires macOS and Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh
open ytm-min.app
```

Builds an optimized, ad-hoc-signed app for the current Mac's architecture. The previous local build remains intact if compilation fails. To also replace the installed app and launch it:

```bash
./build.sh --install
```

## Checks

```bash
./test.sh
```

Requires Node.js for the JavaScript regression tests. Tests cover volume synchronization, text input, shortcut conflicts/repeats, coalesced state updates, and native function-key mapping. Manual checks on a signed-in player should include both window sizes, a focused search field, the two volume sliders, track navigation, and hardware media keys with another app focused.

Player controls depend on YouTube Music's page markup. If the website changes or fails to load, use Cmd-R or the Retry button in the expanded player.
