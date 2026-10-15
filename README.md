# peakshell

A quickshell-based desktop shell with a native C++ plugin.

## Build

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

# IPC – same interface as quickshell ipc
peakshell ipc call ii1qe launcher
peakshell ipc call mpris playPause
peakshell ipc show
peakshell ipc prop <target> <property>

# Other quickshell subcommands work as-is
peakshell log
peakshell list
peakshell kill
```

`peakshell` is a wrapper around `quickshell -p <config-dir>`.
Every argument after `peakshell` is forwarded to quickshell,
so all quickshell subcommands and flags are available.

## Config directory

The shell config is installed to `${INSTALL_QSCONFDIR}` (default:
`/usr/local/etc/xdg/quickshell/peakshell` or `/etc/xdg/quickshell/peakshell`).

Override at runtime with the `PEAKSHELL_CONFIG` environment variable.
In development, `peakshell` automatically detects `shell.qml` in the current working directory.

## Plugin modules

| QML URI | Description |
|---|---|
| `PeakShell` | Core utilities singleton (`Utils`) |
| `PeakShell.Apps` | Desktop entry scanner (`AppScanner`, `AppEntry`) |
| `PeakShell.Services` | System metrics (`SystemMonitor`, `NetworkUsage`, `SessionManager`, `Swaync`) |
| `PeakShell.Wallpapers` | Wallpaper directory watcher (`WallpaperScanner`, `WallpaperEntry`) |

### What the plugin replaces

| Component | Old (python3/bash Process) | New (C++) |
|---|---|---|
| `services/AppScanner.qml` | Python3 desktop entry scanner | `PeakShell.Apps.AppScanner` |
| `services/SystemMonitor.qml` | Bash `monitorProc` (procfs/sysfs/hwmon) | `PeakShell.Services.SystemMonitor` |
| `services/WallpaperService.qml` | Python3 scanProc + watchProc + loadStateProc + saveProc | `PeakShell.Wallpapers.WallpaperScanner` |
| `services/Power.qml` | Shell `execProc` (`hyprshutdown`, `systemctl`) | `PeakShell.Services.SessionManager` |
| `services/Swaync.qml` | Shell client processes + subscribe stream | `PeakShell.Services.Swaync` |
| `services/Hypr.qml` | Shell `kill -9` process | `PeakShell.Utils.killProcess` |
| `bar/modules/Arch.qml` | 11 shell `Process` instances (`netStats`, `lowPower`, etc.) | `PeakShell.Services.NetworkUsage` & `Utils.execute` |
| `components/VolumeMixer.qml` | Shell `pw-cli` / `awk` pipeline | `PeakShell.Utils.pipewireClientAppName` |
