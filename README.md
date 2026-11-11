# LibreClover

Open-source native iPhone and iPad apps and games.

LibreClover apps are designed to be free, privacy-first, accessible, and offline-capable wherever possible—without ads, tracking, in-app purchases, or required accounts.

Each app will be independently installable, with shared Swift packages where useful.

## FreeSudoku

The first app is [FreeSudoku](Apps/FreeSudoku/README.md), a native iPhone/iPad Sudoku game for iOS 17+. Its pure Swift engine lives in `Packages/FreeSudokuCore`.

Features include uniquely solvable generated puzzles, four clue-density presets, pencil notes, undo/redo, hints, optional mistake highlighting, pause/resume, local autosave, and statistics. Presets are not yet graded by human-solving techniques.

GitHub Actions builds and tests the app on iPhone and iPad simulators without signing. This is development source, not an App Store or TestFlight release.

## License

Source code is licensed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
