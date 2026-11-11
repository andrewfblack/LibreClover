# FreeSudoku

A local-first Sudoku game for iPhone and iPad, targeting iOS/iPadOS 17+.

## Build on macOS

Requirements: Xcode 16 or later with an iOS simulator runtime, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd Apps/FreeSudoku
xcodegen generate
open FreeSudoku.xcodeproj
```

Select the FreeSudoku scheme and an iPhone or iPad simulator. The project is generated from `project.yml`; edit that file rather than committing generated projects.

Run the engine tests from the repository root:

```sh
swift test --package-path Packages/FreeSudokuCore
```

GitHub Actions runs engine tests and app UI smoke tests on both iPhone and iPad simulators, including notes, persistence, rotation, settings and a large-text/dark-appearance pass. Downloadable `.xcresult` artifacts contain simulator test results; `FreeSudoku-screenshots` contains exported native screenshots. These are not installable iPhone apps, and screenshots still require human review.

## Artwork

The app icon is original geometric artwork, generated without fonts or third-party assets. To reproduce it, install Pillow in a development environment and run:

```sh
python3 Apps/FreeSudoku/Tools/generate_icon.py
```

The icon source and output are covered by the repository's GPLv3 license. Pillow is only a development tool, not an app dependency.

## How it works

- The Swift package generates complete valid grids and removes digits only while retaining a unique solution.
- Easy, Medium, Hard and Expert target 42, 36, 31 and 27 clues. Generation can stop above a target to preserve uniqueness. These are clue-density presets, not technique-based difficulty ratings.
- Notes, moves, undo/redo history, elapsed time, hints and aggregate completion statistics are saved to one versioned JSON file in Application Support using atomic writes.
- Moves save immediately. The timer checkpoints every ten seconds and when pausing/backgrounding. A force termination may lose up to ten seconds of timer progress.
- Undo history is capped at 200 moves. Completed games are locked; hint counts are not undone. Statistics include hinted games.
- Invalid saves are not automatically deleted or overwritten. Retry loading or explicitly confirm replacement with a new puzzle.
- Session-file reads are bounded to 5 MB. File-based tests cover corrupt/oversized saves, missing files, atomic replacement, and read/write failures without touching real player data.
- No networking, permissions, third-party SDKs, accounts, telemetry or paid features.
- Appearance follows the system by default; Settings also offers explicit Light and Dark modes.
- The privacy manifest declares app-scoped UserDefaults usage for preferences. Review declarations against current Apple requirements before distribution.

## Validation and distribution

See [TESTFLIGHT.md](TESTFLIGHT.md) for the manual-only signed build/export setup, required `app-store` secrets, and explicit upload approval flow.

Simulator tests do not replace hardware testing. Before release, verify VoiceOver, maximum Dynamic Type, contrast, touch targets, rotation, split-view, interruptions, persistence and low-storage errors on real iPhone and iPad devices. A 9-column board necessarily has smaller cells on small screens; VoiceOver exposes cell coordinates, values and notes.

The app includes an initial original icon and a prepared signed-export workflow, but signing/export has not yet been verified with credentials. Confirm the provisional bundle ID `com.libreclover.FreeSudoku`, approve final artwork, configure the `app-store` environment, review licenses/privacy, and obtain human release approval before TestFlight. Signing stays disabled in `project.yml` for simulator CI; the manual release workflow signs during export. Never commit certificates or API keys.

License: GPLv3. Apple distribution terms and GPL obligations need review before App Store distribution.
