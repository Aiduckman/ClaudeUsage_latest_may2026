# ClaudeUsage

A macOS menu bar app that shows real-time [claude.ai](https://claude.ai) usage — the rolling 5-hour session window, the 7-day weekly window, and the Opus weekly window (if your plan has one).

![icon](docs/icon.png)

- Color-coded percentage right in the menu bar (blue under 70%, orange 70–90%, red above 90%)
- Notifications at 80% and 95% per window (with hysteresis so they don't spam)
- Optional Launch at Login
- `sessionKey` stored in the macOS Keychain, never on disk

The app talks to the same internal endpoint that `claude.ai/settings/usage` calls. **It's not a public Anthropic API** — it can change at any time without notice.

## Requirements

- macOS 14 (Sonoma) or later
- [Xcode](https://apps.apple.com/app/xcode/id497799835) 15+ (full Xcode, not just Command Line Tools)
- [Homebrew](https://brew.sh) and [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

```bash
git clone https://github.com/<you>/ClaudeUsage.git
cd ClaudeUsage
chmod +x build.sh
./build.sh
open ClaudeUsage.app                  # try it
mv ClaudeUsage.app /Applications/     # install (recommended for Launch at Login)
```

The first launch runs in **mock mode** so the menu bar populates immediately with fake data. To switch to live data, do the two configuration steps below.

## Configure for live data

### 1. Find your org UUID

1. Sign into <https://claude.ai> in your browser.
2. Open DevTools (`⌥⌘I`) → **Network** tab → filter Fetch/XHR.
3. Click **Settings → Usage** in claude.ai.
4. Look for a request to `https://claude.ai/api/organizations/<UUID>/usage`.
5. Copy `<UUID>`.

Paste it into `UsageClient.swift`:

```swift
private static let orgUUID = "YOUR_ORG_UUID"   // ← replace this
```

### 2. Grab your sessionKey

In the same DevTools window: **Application → Cookies → https://claude.ai → sessionKey**. Copy the **Value** (a long string starting with `sk-ant-sid01-...`).

### 3. Flip mock mode off and rebuild

In `ClaudeUsageApp.swift`:

```swift
@StateObject private var viewModel = UsageViewModel(useMock: false)
```

Then:

```bash
./build.sh
mv ClaudeUsage.app /Applications/        # overwrite if you already installed
```

Launch the app → click the menu bar icon → **Settings…** → paste your `sessionKey` → Save. Real numbers should appear within ~60s.

## Customize

- **Bundle ID**: change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` *and* the matching `service` in `SessionStore.swift`. Defaults are `com.example.claudeusage`.
- **Polling interval**: edit `pollingInterval` in `UsageViewModel.swift` (default: 60s).
- **Notification thresholds**: edit `thresholds: [Int]` in `UsageViewModel.swift` (default: `[80, 95]`).
- **Icon**: edit `make_icon.py` (requires Python + Pillow) and rebuild with `python3 make_icon.py icon_1024.png && iconutil -c icns AppIcon.iconset`.

## Project layout

```
ClaudeUsage/
├── project.yml                # XcodeGen project definition
├── build.sh                   # one-shot build script
├── make_icon.py               # icon generator
├── AppIcon.icns               # bundled app icon
├── ClaudeUsageApp.swift       # @main entry
├── MenuBarLabelView.swift     # the percentage shown in the menu bar
├── MenuBarContentView.swift   # dropdown content
├── SettingsView.swift         # ⌘, settings window
├── UsageViewModel.swift       # polling, state, threshold notifications
├── UsageClient.swift          # claude.ai HTTP client + JSON decoder
├── UsageData.swift            # data models
├── SessionStore.swift         # Keychain wrapper for sessionKey
├── NotificationManager.swift  # banner notifications
└── LaunchAtLogin.swift        # SMAppService toggle
```

## Troubleshooting

- **"Org UUID not set"** — you skipped step 1 of *Configure for live data*.
- **"Not signed in"** — paste your sessionKey in Settings (it may have expired; grab a fresh one).
- **Keychain prompts on every launch** — the app is ad-hoc signed, so its identity changes on every rebuild. Click **Always Allow** each time. This goes away once you sign with a real Developer ID.
- **App icon doesn't show in Finder** — try `killall Finder Dock` to clear the icon cache.
- **HTTP 200 but blank** — claude.ai changed the response shape. Run `print(String(data: data, encoding: .utf8) ?? "")` in `UsageClient.fetchUsage` to see the real payload and update `RawUsageResponse`.

## License

MIT — see [LICENSE](LICENSE).
