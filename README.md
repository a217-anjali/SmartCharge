# SmartCharge

A macOS menu bar app that automatically manages your battery charging thresholds. Keep your laptop plugged in all the time — SmartCharge only allows charging when the battery drops to 20% and stops it at 85%, preserving long-term battery health.

## Features

- **Dual-threshold charging**: starts at ≤20%, stops at ≥85% (configurable)
- **Menu bar widget**: always-visible battery percentage and charge state
- **Fully automatic**: no need to plug/unplug the charger
- **Launch at login**: optional auto-start on boot
- **Desktop notifications**: alerts when charging starts/stops
- **Safe shutdown**: always re-enables charging if the app quits or crashes

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac
- Xcode 15+ (to build from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the Xcode project)

## Quick Start

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Generate Xcode project

```bash
make generate
```

### 3. Open in Xcode

```bash
make open
```

### 4. Build & Run

In Xcode, select the `SmartCharge` scheme, then **Product → Run** (⌘R).

On first launch, you'll be prompted for your admin password to install the privileged helper that controls charging via the SMC.

### Alternative: command-line build

```bash
make build
make install-helper   # requires sudo
```

## How It Works

```
Battery ≤ 20%  →  Charging ON   →  Battery reaches 85%  →  Charging OFF
                                                          (repeat)
```

The app communicates with a small privileged helper tool that runs as root and talks to the System Management Controller (SMC) to enable/disable charging hardware. The main app runs in user space as a menu bar widget.

## Configuration

Open **Settings** from the menu bar dropdown:

| Setting | Default | Range |
|---------|---------|-------|
| Start charging at | 20% | 5–50% |
| Stop charging at | 85% | 50–100% |
| Notifications | On | On/Off |
| Launch at login | Off | On/Off |

## Architecture

```
SmartCharge.app (user space)        SmartChargeHelper (root)
┌────────────────────────┐          ┌──────────────────────┐
│ Menu Bar UI (SwiftUI)  │          │ XPC Listener         │
│ Battery Monitor (IOKit)│◀──XPC──▶│ SMC Read/Write       │
│ State Machine          │          │ Charging On/Off      │
│ Settings (UserDefaults)│          └──────────────────────┘
└────────────────────────┘
```

## Uninstall

```bash
make uninstall   # removes helper + launch daemon, re-enables charging
```

Then drag SmartCharge.app to Trash.

## Packaging (DMG)

```bash
make dmg
```

Creates `build/SmartCharge.dmg` with a drag-to-Applications layout.

## License

MIT
