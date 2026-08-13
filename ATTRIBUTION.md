# Attribution and asset provenance

## Carbon and illogical-impulse

Carbon is an independently maintained fork of [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)'s Quickshell-based **illogical-impulse**, originally created from a source snapshot. The snapshot was imported as one squashed starting point in 2025 and subsequently modified extensively. Carbon is not registered as a GitHub fork and does not automatically merge upstream changes.

The upstream repository and Carbon are distributed under GPLv3. The complete license is in [`LICENSE`](LICENSE). Copyright in upstream portions remains with end_4 and the respective upstream contributors; copyright in later modifications remains with Carbon's contributors.

## Included third-party code

- `.config/quickshell/Modules/Common/Functions/fuzzysort.js` is adapted from [farzher/fuzzysort](https://github.com/farzher/fuzzysort), Copyright (c) 2018 Stephen Kamenar, under the MIT License. Its embedded priority queue is adapted from [lemire/FastPriorityQueue.js](https://github.com/lemire/FastPriorityQueue.js) under Apache-2.0. The license texts are in [`LICENSES/MIT.txt`](LICENSES/MIT.txt) and [`LICENSES/Apache-2.0.txt`](LICENSES/Apache-2.0.txt).
- `.config/quickshell/Modules/Common/Functions/levendist.js` identifies its source as `koeqaife/hyprland-material-you` under GPLv3.
- `.config/quickshell/Modules/Common/Widgets/CircularProgress.qml` is adapted from [rafzby/circular-progressbar](https://github.com/rafzby/circular-progressbar) under LGPL-3.0-only. The license text is in [`LICENSES/LGPL-3.0-only.txt`](LICENSES/LGPL-3.0-only.txt).
- `.config/quickshell/Services/Brightness.qml` is adapted from [caelestia-dots/shell](https://github.com/caelestia-dots/shell) under GPLv3.
- The `.config/hypr/*.lua` files were authored for Carbon and are distributed under GPL-3.0-or-later.

The remaining QML, JavaScript, Python, shell, Matugen template, and Hyprland configuration content was imported from the GPLv3 upstream snapshot or developed as a Carbon modification and is distributed under GPLv3.

## Images, icons, and fonts

- `.config/quickshell/Assets/Images/default-wallpaper.webp` is a resized and WebP-encoded copy of ["Abstract dark wavy paper folds with shadows"](https://unsplash.com/photos/abstract-dark-wavy-paper-folds-with-shadows-FTaXNyHOxeU) by [Pawel Czerwinski](https://unsplash.com/@pawel_czerwinski). It is used under the [Unsplash License](https://unsplash.com/license), which permits free commercial and non-commercial use, modification, and distribution; attribution is not required but is provided here with appreciation.
- Carbon bundles no fonts. Interface text uses the system sans-serif font; Material Symbols Rounded and JetBrains Mono Nerd Font are installed through Arch packages.
- Carbon bundles no third-party logo/icon pack. Distro and application marks are resolved from the user's installed system icon theme at runtime.

## External software and themes

Hyprland, Quickshell, Matugen, awww, Qt, system utilities, optional KDE/Kvantum themes, and optional desktop applications are dependencies rather than redistributed source. Their own packages and licenses govern them.

## Audit record

The release audit checks publishable files for credentials, private keys, personal absolute paths, machine identifiers, runtime output, and generated caches. The repository was deliberately reinitialized before its first public commit, so there is no retained pre-audit Git history to publish.
