# peakshell

A quickshell-based desktop shell with a native C++ plugin for hyprland.

## Build

### Dependencies (Arch Linux)

Required build dependencies:

```bash
sudo pacman -S --needed base-devel cmake pkgconf qt6-base qt6-declarative
```

Optional build-time integrations (auto-detected by CMake; rebuild after
installing them):

```bash
sudo pacman -S --needed syntax-highlighting baloo
```

- `syntax-highlighting` enables syntax-highlighted clipboard previews.
- `baloo` enables KDE-indexed file search in the launcher. Without it the
  launcher uses a bounded home-directory fallback.

Runtime dependencies:

```bash
sudo pacman -S --needed hyprland qt6-svg qt6-multimedia qt6-multimedia-ffmpeg

# quickshell-git is available from the AUR, for example:
paru -S --needed quickshell-git
```

Then build and install:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
sudo cmake --install build
```

## Usage

```bash
# Launch the shell
peakshell

# Daemonize
peakshell -d

# IPC – To view all ipc and call them
peakshell ipc show
peakshell ipc call ii1qe launcher
peakshell ipc prop <target> <property>

# Other quickshell subcommands work as is
peakshell log
peakshell list
peakshell kill

# To view help
peakshell --help
```

### On-screen display

The OSD mirrors volume, mute, brightness, lock-key and media changes. It can
also be driven manually:

```bash
peakshell ipc call osd volumeRaise
peakshell ipc call osd brightnessLower
peakshell ipc call osd media next
peakshell ipc call osd message "Captured Screenshot" "camera-photo-symbolic" 2000
peakshell ipc call osd progress 0.5 "Custom progress" "audio-volume-medium" 2000
peakshell ipc call osd segments 2 5 "Workspace" "view-grid"
```

`message` and `progress` accept an optional duration in milliseconds. The
timeout, bottom margin and output monitor can be changed in
**Settings → OSD**.

`peakshell` is a wrapper around `quickshell -p <config-dir>`.
Every argument after `peakshell` is forwarded to quickshell,
so all quickshell subcommands and flags are available.

## Config directory

The shell config is installed to `${INSTALL_QSCONFDIR}` (default:
`/usr/local/etc/xdg/quickshell/peakshell` or `/etc/xdg/quickshell/peakshell`).

Override at runtime with the `PEAKSHELL_CONFIG` environment variable.
In development, `peakshell` automatically detects `shell.qml` in the current working directory.
