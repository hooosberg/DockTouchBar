<p align="center">
  <img src="assets/icon-256.png" alt="DockTouchBar" width="128" height="128">
</p>

<h1 align="center">DockTouchBar</h1>

<p align="center">
  <strong>Your Dock on the Touch Bar.</strong>
  <br>
  <strong>Simple · Elegant · Efficient</strong>
  <br>
  Tap to switch · double-tap to minimize · long-press to quit
  <br>
  <a href="https://hooosberg.com/apps/docktouchbar">Product page</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar/diary">Build diary</a>
</p>

<p align="center">
  <strong>Two apps, two downloads:</strong>
  <br>
  <a href="https://github.com/hooosberg/DockTouchBar/releases/latest"><strong>⬇ DockTouchBar</strong></a> (Standard: your Dock on the Touch Bar)
  &nbsp;·&nbsp;
  <a href="https://github.com/hooosberg/DockTouchBar/releases/tag/vibe-v1.23"><strong>⬇ DockTouchBar Vibe</strong></a> (adds live AI agent status on the icons)
  <br>
  <sub>Not sure which? Start with Standard. <a href="#two-editions">What's the difference and where to download?</a></sub>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="translations/README.zh-CN.md">简体中文</a> ·
  <a href="translations/README.zh-Hant.md">繁體中文</a> ·
  <a href="translations/README.ja.md">日本語</a> ·
  <a href="translations/README.ko.md">한국어</a> ·
  <a href="translations/README.fr.md">Français</a> ·
  <a href="translations/README.de.md">Deutsch</a> ·
  <a href="translations/README.es.md">Español</a> ·
  <a href="translations/README.pt.md">Português</a> ·
  <a href="translations/README.ru.md">Русский</a> ·
  <a href="translations/README.it.md">Italiano</a> ·
  <a href="translations/README.tr.md">Türkçe</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-444.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20silicon-tested-2e7d32.svg" alt="Apple silicon: tested">
  <img src="https://img.shields.io/badge/Intel-untested-f9a825.svg" alt="Intel: untested">
  <img src="https://img.shields.io/badge/Swift-AppKit-F05138.svg" alt="Swift + AppKit">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-1e88e5.svg" alt="PolyForm Noncommercial">
</p>

## Two editions

| | **DockTouchBar** (Standard) | **DockTouchBar Vibe** |
|---|---|---|
| For | Everyone with a Touch Bar Mac | People who code with AI agents (Claude Code, Codex, Qoder, WorkBuddy, Antigravity…) |
| What it is | Your Dock on the Touch Bar: tap, double-tap, long-press | Everything in Standard, plus a live status on the icon of the app your AI agent runs in: a pixel-art screen with falling digits while it works, **OK** when it's done |
| Download | [**Download Standard**](https://github.com/hooosberg/DockTouchBar/releases/latest) | [**Download Vibe 1.23**](https://github.com/hooosberg/DockTouchBar/releases/tag/vibe-v1.23) |

**Where to download**

- **Standard** → the repository's [**Releases** page](https://github.com/hooosberg/DockTouchBar/releases/latest) (the release marked **Latest**, also shown in the right sidebar of this page). Download `DockTouchBar-<version>.dmg`.
- **Vibe** → its own release, [**Vibe 1.23**](https://github.com/hooosberg/DockTouchBar/releases/tag/vibe-v1.23). Download `DockTouchBarVibe-<version>.dmg` from **Assets**. GitHub's sidebar can only show one "Latest", so Vibe is not shown there; use this link, or find it in the full [Releases list](https://github.com/hooosberg/DockTouchBar/releases) (releases named "Vibe").

**Not sure? Start with Standard.** Pick **Vibe** if you use AI coding agents on this Mac and want to see, right on the Touch Bar, which one is busy and which one has just finished. Vibe is a separate app with its own name, settings and updates, and it already includes the whole Dock, so you only need one of the two. They both take the Touch Bar, so run one at a time (Vibe tells you if the Standard one is running). Both come from this repository: Standard is the `main` branch, Vibe is the `vibecoding` branch.

Vibe 1.23 shares Standard 1.23's window centering and maximizing code. Their version numbers are aligned; each app keeps its own settings and update channel.

![DockTouchBar on the Touch Bar](assets/touchbar-idle.gif)
*Idle state: apps aligned to bottom with top-right active badge dot (red for frontmost app); pixel-art coffee cup with live rising steam.*

![Long-press to quit: four seasons animation](assets/touchbar-seasons.gif)
*Long-press to quit: side-scrolling pixel-art countdown scenes across four seasons (spring running dog / summer sailing ship / autumn forest fox / winter sleigh ride). Release early to cancel, with seasonal finale burst.*

### ⚡ Energy & Native Performance (Earlier Release Measurements)

Engineered for 24/7 background residency using event-driven app and window updates. The measurements below are from earlier releases; screenshot activity temporarily uses a short process check:

| Metric | Measured | Notes |
|---|---|---|
| **CPU Usage** | **0.0% ~ 0.8%** | Idle 0.0%; brief negligible spikes only on app/window switch events |
| **Physical Footprint** | **29 MB** | Measured with macOS `footprint` tool, fraction of Electron alternatives |
| **Energy Impact** | **0.0** | Lowest possible macOS Activity Monitor energy rating, zero impact on battery |
| **Resident Threads** | **4 threads (all sleeping on events)** | Zero busy-wait, no high-frequency timer polling |
| **Network access** | **GitHub update checks and downloads** | Dock interactions run locally; no analytics or accounts |
| **Render Latency** | **~2.3 ms / frame** | Native CoreAnimation / AppKit rendering pipeline for instant touch responsiveness |

**If DockTouchBar is useful to you, a ⭐ Star on GitHub is the best way to say thanks.**

## DockTouchBar Vibe: see your AI agents work

![AI coding agents on the Touch Bar: idle, working, done](assets/vibe-agents.gif)
*Vibe: the icon of the app an agent runs in turns into a little pixel-art screen with falling digits while the agent works, then shows **OK** when it's done. Tap the icon to dismiss it. The five icons here are Claude Code, Codex, Qoder, WorkBuddy and Antigravity.*

- **No agent-specific plugins.** You don't wait for us to support your tool: copy one prompt, paste it to your agent, and it connects itself.
- The animation is drawn by the app, from the real icon of whatever app the agent runs in, so it works for tools we have never seen. Nothing is pre-made per agent.
- **Pixel-art look:** the icon is redrawn as sharp 8-bit pixel art with its own small palette, framed like an old CRT screen. The frame, the falling digits and **OK** all share the same pixel grid.

**Pair an agent in three steps**

1. Open **Settings → Pair agents** and press **Copy prompt**.
2. Paste it to your agent (any agent that can run commands on your Mac). It checks itself first, then connects the best way it can: through its own hooks, or, if it has none, through a rule in its long-term instructions; for apps Vibe can watch by itself it changes nothing at all. It backs up its config first and tells you every step.
3. Vibe itself verifies the connection and host app (the agent can't mark itself as verified), then the agent registers in the list. This plays a demo; it does not prove that hooks are trusted or running automatically. Complete any required hook trust, then give the agent a task and check that its icon follows the work. The list shows connection verification separately from received activity; manually sent events are not proof of automatic delivery. **Try it** plays only the animation, and **Copy unpair prompt** hands the agent a prompt that undoes its own changes.

![Pair agents page](assets/vibe-pairing-en.png)

What to know:

- **The app never edits another tool's configuration.** The agent does that, on your Mac, after you paste the prompt, and it is told to back up first, never touch your existing hooks, and show you what it did. Nothing leaves your Mac for this feature.
- **Needs an agent that can run a command on your Mac and runs in a desktop app** (a terminal or editor works too). Web-only chat tools can't. If the agent can't reach the app, it is told to say so instead of claiming success.
- **Some agents ask you to trust the new hook once.** Codex, for example: ChatGPT Settings → Hooks → Trust all. The agent will tell you where to click.
- A sandbox can deny access to Vibe's local socket even while the app is running. Pairing commands report `NOT_REACHABLE` with a reason, the `nc` exit status and any diagnostic it emits. Some macOS versions fail silently even with verbose output: `reason=connection_failed` then means the cause is unknown, not that Vibe is closed. For `reason=permission_denied`, stop and request approval through the agent's normal permission flow before retrying the same command. Do not disable the sandbox or bypass hook trust. `reason=no_response` means the connection returned no reply; it is not a successful check.

### Supported agents

**Any agent that can run a command on your Mac can pair. The list below is only what has been tried so far, not a limit.**

| Agent | How it connects | Notes |
|---|---|---|
| Claude Code | its own hooks | |
| Codex (ChatGPT app / CLI) | its own hooks | Trust the hooks once: ChatGPT Settings → Hooks → Trust all |
| Qoder | its own hooks | |
| WorkBuddy | its own hooks | |
| Antigravity | a rule in its long-term instructions (`GEMINI.md`) | No hooks, so it relies on the agent following the rule |
| Qwen Work (千问办公) | a rule in its long-term instructions | Same |
| Doubao Work (豆包) | Vibe reads its session files, read-only | Nothing in Doubao is changed |
| **Anything else** | paste the prompt | It picks hooks or an instruction rule and reports back. If it can't reach Vibe, it is told to say so instead of claiming success |

All of the above were tried on the author's Mac only. Pairing safety: the prompt tells the agent to back up first, only add (never remove) settings, stop and show you the raw output when anything differs from what it expects, and never fake a verification.

## Why

Pock, PockV2 and friends can put the Dock on the Touch Bar, but they do a lot more, and in daily use the bar tends to disappear or stop responding. DockTouchBar keeps to one job and does it well.

**Simple**

- One job: your Dock on the Touch Bar. No widgets, no plugins.
- A handful of switches in the menu bar, nothing else to configure.
- Native Swift and AppKit, with no third-party dependencies. Pixel-art scenes are included in the source.

**Elegant**

- Uses macOS icons and the system Touch Bar scroller. Unpinned running apps appear on the left, newest first; pinned apps keep their Dock order. Closing an app keeps the current visible area.
- Gestures that stay out of your way: a tap acts immediately (it never waits to see whether a double-tap is coming), and long-press shows a quiet progress bar under the icon, plus a "Closing …" countdown at the right edge of the Touch Bar so your finger never hides it, drawn as a little pixel-art scene you can switch between four seasons. Release early to cancel.
- Rapid taps feel right: the last tap always wins, and it never fights you. If the system drops a desktop switch or something steals focus, it quietly puts things right, and it stops the moment you touch the keyboard, mouse or trackpad.
- Speaks your language (12 languages, from English to 简体中文 and 日本語) and asks for just one optional permission.

**Efficient**

- Event-driven app and window updates. Earlier measurements on an M1 MacBook Pro with the Dock showing and idle: **0.0% CPU**, **0 idle wakeups**, about **32 MB** of memory.\*
- Adapts to your Mac instead of using fixed delays: desktop switches wait for the system's own "finished" signal and check the result, so it stays correct whether animations are slow, off, or the machine is busy.
- When apps start or quit, only what changed is updated and your scroll position is kept. Icons are rasterized once and cached.
- Self-healing: re-attaches after sleep, screen unlock and Control Strip restarts, so you never have to relaunch it.
- Fails safe: private APIs are resolved at runtime. If macOS removes one, that feature switches itself off instead of crashing.
- Privacy: no analytics or accounts. Dock interactions run locally; automatic update checks and requested downloads connect to GitHub. Preferences stay on your Mac.

<sub>\* Release build. CPU from five `top` samples 2 s apart (all 0.0%); wakeups from the kernel's per-process counters read 20 s apart, three times on 1.10 (0 idle wakeups and 0 interrupt wakeups every time; an earlier run on 1.8 saw 0–7 interrupt wakeups, from system events); memory is the physical footprint from `footprint` (32 MB). The steam above the coffee cup is drawn by the system's render process, not by the app.</sub>

## Features

| Gesture | What happens |
|---|---|
| **Tap** an icon | Switch to the app, or launch it. If its windows are on another desktop (Space), jump to that desktop |
| **Double-tap** | Minimize the current window, like its yellow button. Needs Accessibility permission. Tap again to restore |
| **Long-press** | Close the app, and always tell you what happened. A progress bar fills under the icon while you hold, and a "Closing …" countdown appears at the right edge over a pixel-art season (your pick in the menu); release early and it counts as a tap. The app is always quit entirely (same as ⌘Q), whatever its number of windows or whether they are minimized or hidden. Finder can't be quit, so all its windows are closed instead (minimized ones too; if they are on another desktop it jumps there first). If the app can't close because it is waiting for you (an "unsaved changes" sheet) or does not close, the Touch Bar switches to it, across desktops, and says so |
| **Trash** | Tap opens the Trash window in Finder; double-tap minimizes it; long-press closes it. It dims while the window is closed (and disappears in "only show running apps" mode) |
| **Swipe** | Scroll when the icons don't all fit; closing an app keeps the current area in view |
| **Coffee cup** (right end, with animated steam) | Take a break: hide the Dock for a moment and hand the Touch Bar back to the system (brightness, volume). It returns on its own after 10–60 s |
| **Center / maximize button** (far right) | Center the frontmost app's window; tap again to maximize it (fills the usable area, not native full screen), and again to center it. If you moved the window yourself or switched apps, it centers first, and the icon follows the window's current state. Needs Accessibility permission |

The menu bar menu keeps the everyday switches: Show Dock on Touch Bar, Only show running apps (off by default: pinned apps are shown too; apps that would be dimmed, including Finder without windows and a closed Trash, are hidden, and Finder sits at the far left), Center the icons (when they fit; once they overflow they start from the left and scroll), Show the center / maximize button, and Launch at login. **Settings…** opens the settings window, which has three pages:

- **Settings** — icon spacing; hide-for-a-moment time after tapping the coffee cup (10 / 20 / 30 / 60 s); the size of the centered window (60–100% of the screen height; width same as height, or 50–100% of the screen width); double-tap to minimize; long-press to close (Off / 1 / 2 / 3 / 5 s) and its style (Spring / Summer / Autumn / Winter, with a short preview on the Touch Bar); yielding to system Touch Bar controls (independent screenshot / recording and Fn switches, on by default); language (Follow System, or one of 12 languages — shown at the top of the Settings page; it also translates the Touch Bar's long-press messages); Accessibility permission status with a shortcut to System Settings (nothing else needs a permission); and the "why can't I see the Dock?" diagnosis
- **How to use** — gestures and buttons
- **About** — version, update check, product page and build diary links, Star button

The app has an icon in the Dock too, so you can launch it from there after installing.

Opening the app again from Applications while it is running pops up the menu.

## Requirements and tested environment

| | |
|---|---|
| Hardware | A Mac with a Touch Bar (MacBook Pro 2016–2022) |
| **Tested on** | **MacBook Pro 13" (M1, `MacBookPro17,1`), macOS 27.0, single display, 3 Spaces, Touch Bar set to "Expanded Control Strip", Stage Manager on** |
| Apple silicon (M1) | ✅ This is the machine it is developed and used on |
| Intel | ⚠️ **Unknown.** The download is a universal binary and the Intel slice starts under Rosetta on an M1 Mac, but it has never run on a real Intel Touch Bar Mac. Reports welcome |
| macOS version | Built with a macOS 13 minimum, but only tested on macOS 27.0. Older versions are untested |

Things to know:

- It uses **private Apple APIs** to keep a Touch Bar on screen from a background app. That is also why it cannot be on the Mac App Store, and why a future macOS update could break it. The private interfaces are resolved at runtime, so if one disappears that feature switches off instead of crashing; `swift tools/probe-private-api.swift` shows which ones your macOS still has.
- The Dock takes the **whole** Touch Bar, so the system Control Strip (brightness, volume) is hidden while it is on. Tap the little coffee cup on the right of the bar to hide the Dock for a moment and hand the Touch Bar back to the system (it returns on its own after 10–60 seconds, 20 by default — or, if the screen was turned all the way down, as soon as the brightness is raised). You can also untick "Show Dock on Touch Bar" in the menu.
- Left-to-right order: unpinned running apps (newest first) → divider → Finder → pinned apps in Dock order → divider → Trash. Newly launched unpinned apps come into view on the left; switching between open apps does not reorder them. Tap Trash to open it in Finder.
- With Stage Manager on, macOS animates the window change, so the window can take about half a second to appear on screen. The tapped app becomes the frontmost app in about 40 ms; the rest is the system's animation.

## Install

1. Download `DockTouchBar-<version>.dmg` from [Releases](https://github.com/hooosberg/DockTouchBar/releases/latest). (For **Vibe**, download `DockTouchBarVibe-<version>.dmg` from its [release](https://github.com/hooosberg/DockTouchBar/releases/tag/vibe-v1.23) and drag **DockTouchBar Vibe** onto Applications; see [Two editions](#two-editions).)
2. Open it and drag **DockTouchBar** onto **Applications**, then launch it. A Dock icon appears in the menu bar and on the Touch Bar.

> The DMG is signed with a Developer ID certificate and **notarized by Apple**, so it opens like any other app. macOS will only ask you to confirm the first launch. Prefer to compile it yourself? See [Build from source](#build-from-source).

### Accessibility permission (optional)

Accessibility enables cross-desktop window switching, double-tap minimization, center / maximize, closing Finder's windows, detecting confirmation dialogs, and Fn yielding. Without it, basic launching and activation remain available; these features are limited.

1. Menu bar icon → **Settings…** → **Permissions** → **Turn on…** (once granted it reads **Accessibility: on**)
2. In System Settings → Privacy & Security → Accessibility, turn DockTouchBar on.

If it still asks after you turned it on, the old entry is stale (this happens when the app's signature changed): select DockTouchBar in the list, click **−**, then add it again. Or run `tccutil reset Accessibility com.maohuhu.docktouchbar` and repeat step 1.

### If a tap doesn't switch desktops

Right after it happens, run this from a clone of the repo. It is read-only and prints how the app judged that app's windows (which windows exist, which desktop each is on, which ones are real windows, which one it would raise):

```bash
tools/diagnose-switch.sh com.google.Chrome
```

## Can't see the Dock?

Most common cause: System Settings → Keyboard → “Touch Bar Shows” is set to “F1, F2, etc. keys”, which fills the whole Touch Bar with function keys. Since 1.16 the app detects this and offers to switch it to “Expanded Control Strip” on first launch. You can also click “Diagnose: why can't I see the Dock?” in the menu bar menu to check each possible cause and copy a report for feedback. Holding Fn still shows F1–F12 afterwards.

## Build from source

Requires the Xcode command line tools.

```bash
git clone https://github.com/hooosberg/DockTouchBar.git
cd DockTouchBar
scripts/install.sh      # build → copy to /Applications → launch
scripts/make-dmg.sh     # build/DockTouchBar-<version>.dmg
```

Without a signing certificate the build falls back to ad-hoc signing. That works, but macOS treats every ad-hoc rebuild as a new app, so you have to re-grant Accessibility each time. Set `SIGN_IDENTITY="Apple Development: …"` (or a Developer ID certificate) to keep one stable identity.

## Project layout

```
Sources/DockTouchBar/   App source
Resources/              Info.plist, app icon
scripts/                build.sh, install.sh, make-dmg.sh, make-icon.sh
tools/                  Diagnostics: private-API check, Spaces/windows inspector, switch diagnostic, rapid-click stress test, offscreen preview, and render-seasons.sh (the README screenshots)
assets/                 README images
```

After a big macOS update, run `swift tools/probe-private-api.swift` to see which private APIs are still available.

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — free to use, copy, modify and share for **personal and other noncommercial purposes**. **Commercial use is not covered** and needs a separate license from the author; please get in touch via [hooosberg.com](https://hooosberg.com/).

This is a source-available license, not an OSI-approved open source license. Required notice: Copyright © 2026 hooosberg.

## Author

Made by **hooosberg** — [hooosberg.com](https://hooosberg.com/) · [GitHub](https://github.com/hooosberg). If this saved you some taps, please ⭐ the repo.
