# Reddit r/macapps Post

## Where to post
https://www.reddit.com/r/macapps/submit

## Title
SmartCharge — Free, open-source macOS app that automatically manages your battery charging between 20%-85% to preserve battery health

## Body (paste this)

Hey r/macapps!

I built **SmartCharge**, a lightweight macOS menu bar app that automatically manages your laptop's charging to preserve long-term battery health.

### The problem
Keeping your MacBook plugged in at 100% all day degrades the battery faster. Apple's built-in "Optimized Battery Charging" only targets 80% and isn't very configurable.

### What SmartCharge does
- **Starts charging only when battery drops to ≤20%**
- **Stops charging at 85%** (or whatever you set)
- Runs silently in the background — you never need to unplug
- Fully configurable thresholds via a clean native UI

### Features
- 📊 Battery charge history chart (24h / 7-day view with Swift Charts)
- 🔋 4 built-in charging profiles (Home, Travel, Presentation, Balanced) + custom profiles
- 🌡️ Real-time battery temperature gauge with overheat warning
- ⏱️ Charge time estimation ("Full at 2:30 PM")
- 📈 Battery health degradation tracking over time
- 🔔 Desktop notifications when charging starts/stops
- ⌨️ Global keyboard shortcuts (Cmd+Shift+B to toggle)
- 📋 Activity log with full charge event history
- 📤 Export charge data as CSV
- 🎯 First-launch onboarding walkthrough

### Tech
- Native SwiftUI, macOS 13+
- Privileged helper talks to the SMC (System Management Controller) to control charging hardware
- ~3,000 lines of Swift, 88 unit tests
- GitHub Actions CI/CD with daily macOS compatibility checks

### Install
Download the DMG from the GitHub releases page — drag to Applications, done.

**GitHub:** https://github.com/a217-anjali/SmartCharge
**Download:** https://github.com/a217-anjali/SmartCharge/releases/tag/v1.0.0

It's completely free and MIT licensed. Would love feedback!

## Flair
Set flair to: "Open Source" or "Utilities" (whatever r/macapps offers)
