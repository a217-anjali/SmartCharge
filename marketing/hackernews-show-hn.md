# Hacker News — Show HN Post

## Where to post
https://news.ycombinator.com/submit

## Title (must start with "Show HN:")
Show HN: SmartCharge – Open-source macOS app for automatic battery charge management

## URL
https://github.com/a217-anjali/SmartCharge

## Text (leave blank — HN Show posts with a URL don't need body text, the GitHub README serves as the landing page)

---

## First comment (post this as a comment on your own submission immediately after submitting)

Hi HN! I built SmartCharge to solve a simple problem: I keep my MacBook plugged in all day, but constant 100% charge degrades the battery.

SmartCharge sits in your menu bar and talks to the System Management Controller (SMC) via a privileged helper to physically enable/disable charging hardware. It only charges when the battery drops to 20% and stops at 85% — configurable.

Interesting technical bits:
- The app uses XPC to communicate between the user-space SwiftUI app and a root-level helper that writes SMC keys (CH0B on Apple Silicon)
- Battery snapshots every 5 min, visualized with Swift Charts
- Temperature monitoring via AppleSmartBattery IORegistry (centidegrees conversion)
- Charge rate estimated from InstantAmperage × Voltage
- Daily compatibility check via GitHub Actions — auto-opens an issue if a macOS update breaks the build
- 88 unit tests, CI on every push

Stack: Swift/SwiftUI, IOKit, XPC, SMC. ~3,000 lines. MIT licensed.

Happy to answer questions about SMC programming, macOS privileged helpers, or battery health science.

---

## Best time to post
Tuesday–Thursday, 8–9 AM US Eastern (12–1 PM UTC)
