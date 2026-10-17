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
peakshell ipc call ii1qe clipboard
peakshell ipc call ii1qe powermenu
peakshell ipc call ii1qe power shutdown
peakshell ipc call mpris playPause
peakshell ipc call timer start 25m
peakshell ipc call timer state
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
