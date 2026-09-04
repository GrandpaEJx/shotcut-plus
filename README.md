[![build-shotcut-linux](https://github.com/mltframework/shotcut/workflows/build-shotcut-linux/badge.svg)](https://github.com/mltframework/shotcut/actions?query=workflow%3Abuild-shotcut-linux+is%3Acompleted+branch%3Amaster)
[![build-shotcut-macos](https://github.com/mltframework/shotcut/workflows/build-shotcut-macos/badge.svg)](https://github.com/mltframework/shotcut/actions?query=workflow%3Abuild-shotcut-macos+is%3Acompleted+branch%3Amaster)
[![build-shotcut-windows](https://github.com/mltframework/shotcut/workflows/build-shotcut-windows/badge.svg)](https://github.com/mltframework/shotcut/actions?query=workflow%3Abuild-shotcut-windows+is%3Acompleted+branch%3Amaster)


# Shotcut+ - a free, open source, cross-platform **video editor**

Shotcut+ is a fork of [Shotcut](https://www.shotcut.org/) that adds a modern,
Canva/CapCut-style **layer timeline** on top of the original editor. Everything
else — the engine, filters, encoding, classic timeline — stays the same
Shotcut you already know; this fork just adds an alternate, layer-based way to
arrange clips.

<div align="center">

<img src="https://www.shotcut.org/assets/img/screenshots/Shotcut-18.11.18.png" alt="screenshot" />

</div>

- Upstream project: https://github.com/mltframework/shotcut
- Features (upstream): https://www.shotcut.org/features/
- Roadmap (upstream): https://www.shotcut.org/roadmap/

## What's new in Shotcut+: the layer timeline

A second, opt-in timeline view built around layers/tracks the way Canva,
CapCut, and similar tools present them — clips stack as horizontal layers
instead of the classic MLT track rows, aimed at people who find that mental
model more familiar than a traditional NLE timeline.

- **Layer-based drag & drop** — move and trim clips directly by dragging their
  body or edges, with corrected resize-handle direction and a wider, more
  reliable hit target so the resize cursor shows up when you'd expect it.
- **Auto track creation** — drag a clip above the topmost layer or below the
  bottommost one and a new track is created for you automatically, instead of
  refusing the drop.
- **Right-click context menu** on any clip: Cut, Copy, Duplicate, Lift,
  Delete, and Properties, all sharing the same actions/shortcuts as the rest
  of Shotcut.
- **Per-clip color tags** — mark clips with a color from the context menu (or
  a custom color) to visually group or categorize them, independent of track
  color.
- **Per-clip lock** — lock individual clips (not just whole tracks) to guard
  them against accidental move/trim/delete while you edit around them.
- **Hover cursors throughout** — pointing-hand/resize cursors on draggable
  and clickable controls in the layer timeline's headers and toolbar for
  clearer affordances.
- **Right-click quick-add** on empty timeline space to drop a generator or
  adjustment clip at the clicked position, in both the layer and classic
  timelines.

The classic MLT-style timeline is untouched and still the default; the layer
timeline is an additional view for those who prefer it.

## Install

Shotcut+ is currently source-only; build it yourself using the instructions
below. For the unmodified upstream editor, prebuilt binaries are available at
https://www.shotcut.org/download/.

## Contributors

Shotcut+ is maintained by [GrandpaEJx](https://github.com/GrandpaEJx) as a
fork of upstream Shotcut, whose original contributors include:

- Dan Dennedy <<http://www.dennedy.org>> : main author
- Brian Matherly <<code@brianmatherly.com>> : contributor

## Dependencies

Shotcut's direct (linked or hard runtime) dependencies are:

- [MLT](https://www.mltframework.org/): multimedia authoring framework
- [Qt 6 (6.4 minimum)](https://www.qt.io/): application and UI framework
- [FFTW](https://fftw.org/)
- [FFmpeg](https://www.ffmpeg.org/): multimedia format and codec libraries
- [Frei0r](https://www.dyne.org/software/frei0r/): video plugins
- [SDL](http://www.libsdl.org/): cross-platform audio playback

See https://shotcut.org/credits/ for a more complete list including indirect
and bundled dependencies.

## License

GPLv3. See [COPYING](COPYING).

## How to build

**Warning**: building Shotcut should only be reserved to beta testers or contributors who know what they are doing.

### Qt Creator

The fastest way to build and try Shotcut development version is through [Qt Creator](https://www.qt.io/download#qt-creator).

### From command line

First, check dependencies are satisfied and various paths are correctly set to find different libraries and include files (Qt, MLT, frei0r and so forth).

#### Configure

In a new directory in which to make the build (separate from the source):

```
cmake -DCMAKE_INSTALL_PREFIX=/usr/local/ /path/to/shotcut
```

We recommend using the Ninja generator by adding `-GNinja` to the above command line.

#### Build

```
cmake --build .
```

#### Install

If you do not install, Shotcut may fail when you run it because it cannot locate its QML
files that it reads at run-time.

```
cmake --install .
```

## Translation

If you want to translate Shotcut to another language, please use [Transifex](https://explore.transifex.com/ddennedy/shotcut/).
