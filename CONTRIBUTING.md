# Contributing to OctaneOS

First off — thank you for being here. OctaneOS is a community project from day one, and every contribution matters whether it's a kernel patch, a typo fix, or just showing up on Discord and asking questions.

---

## We are early

OctaneOS is in active early development. Things will break. Decisions will change. That's not a bug — it's the reality of building something new in public. If you're comfortable with that, you're in the right place.

---

## Ways to contribute

You don't need to know Linux to contribute. Here's what we need at every skill level:

**If you're just getting started:**
- Test builds and report issues
- Improve documentation
- Ask questions on Discord — if you're confused, someone else is too, and your question helps us write better docs
- Share the project with people who'd care about it

**If you know your way around Linux:**
- Help with Batocera build system configuration
- Test emulator performance on A733 hardware
- Write setup and build guides
- Help others in Discord

**If you're comfortable with kernel work:**
- Allwinner A733 device tree development
- LCD0 DPI display driver bring-up
- USB-C DisplayPort Alt Mode configuration
- WiFi streaming stack development
- GPIO and I2C peripheral support

**If you're a designer:**
- OctaneOS EmulationStation theme
- GameOctane app UI
- Shell design and STL files (coming soon in the Hardware repo)

---

## Before you start

1. **Check open issues first** — someone may already be working on what you have in mind
2. **Open an issue before a big PR** — let's talk about it before you spend hours on something
3. **Introduce yourself** — open an issue titled "Hello from [your name/handle]" and tell us what you're interested in working on. We read every one.

---

## How to submit a pull request

1. Fork the repo
2. Create a branch with a descriptive name (`feature/a733-device-tree`, `fix/emulationstation-theme`, etc.)
3. Make your changes
4. Write a clear description of what you changed and why
5. Submit the PR against `main`

Keep PRs focused. One thing per PR is easier to review and faster to merge.

---

## Code style

We don't have a strict style guide yet — this will evolve as the codebase grows. For now:

- Comment your code, especially anything hardware-specific
- If you're touching the device tree or kernel config, explain what you changed and why in the PR description
- Shell scripts should be POSIX-compatible where possible

---

## Community

- 💬 [Discord](https://discord.gg/pnuamjT) — the best place to ask questions and get help
- 🌐 [GameOctane.com](https://gameoctane.com) — home base
- 🐦 [X / Twitter](https://x.com/gameoctane) — build updates

---

## A note on skill level

OctaneOS is being built by someone learning Linux through building it. If that's you too, you belong here. Every expert was once a beginner, and this project is explicitly designed to be documented well enough that beginners can follow along and contribute.

Ask the question. Open the issue. Submit the draft PR. The worst that happens is we iterate together.

---

*Build It. Play It. Own It.*