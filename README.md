# Atari Lynx for Analogue Pocket
Ported from the original core developed at https://github.com/MiSTer-devel/AtariLynx_MiSTer

Please report any issues encountered to this repo. Issues will be upstreamed as necessary.

## Installation
To install the core, copy the `Assets`, `Cores`, and `Platform` folders over to the root of your SD card. Please note that Finder on macOS automatically _replaces_ folders, rather than merging them like Windows does, so you have to manually merge the folders.

Place the Atari Lynx bios in `/Assets/lynx/common` named "lynxboot.img".

## Usage
ROMs should be placed in `/Assets/lynx/common`.

## Features

### Supported
* Fast Forward
* CPU GPU Turbo
* Orientation: rotate video by 90
* 240p mode: doubled resolution, mainly for CRT output (Rotation does not work in this mode)
* Flickerblend: 2 or 3 frames blending like real Lynx Screen

### In Progress
* Save States and Sleep

## Refresh Rate
Lynx uses custom refresh rates from ~50Hz up to ~79Hz. Some games switch between different modes. To compensate you can either:
* Live with tearing
* Buffer video: triple buffering for clean image, but increases lag
* Sync core to 60Hz: Run core at exact 60Hz output rate, no matter what internal speed is used
