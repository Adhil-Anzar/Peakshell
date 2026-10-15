pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var apps: []
    property bool loaded: false

    signal scanComplete()

    function scan() {
        scanProc.running = false;
        scanProc.running = true;
    }

    function launch(entry) {
        if (!entry || !entry.exec)
            return;
        // Strip field codes (%f, %F, %u, %U, %d, %D, %n, %N, %v, %m, %k, %i, %c)
        var cmd = entry.exec.replace(/%[fFuUdDnNvmkic]/g, "").replace(/\s+/g, " ").trim();
        if (entry.terminal) {
            // Launch in default terminal; try common terminals in order
            launchProc.command = ["bash", "-c",
                "for t in $TERMINAL kitty alacritty wezterm foot xterm; do "
                + "command -v $t >/dev/null 2>&1 && exec $t -e " + cmd + "; done"];
        } else {
            launchProc.command = ["bash", "-c", cmd + " &"];
        }
        launchProc.running = false;
        launchProc.running = true;
        root.close();
    }

    // Exposed so the panel can call close without coupling to the panel instance
    function close() {}  // overridden by LauncherPanel via Connections

    Process {
        id: scanProc
        running: true
        command: ["python3", "-c",
            "import os, json, glob\n"
            + "dirs = []\n"
            + "xdg_home = os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share'))\n"
            + "xdg_dirs = os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share')\n"
            + "dirs.append(os.path.join(xdg_home, 'applications'))\n"
            + "for d in xdg_dirs.split(':'):\n"
            + "    dirs.append(os.path.join(d, 'applications'))\n"
            + "keymap = {'Name': 'name', 'GenericName': 'genericName', 'Comment': 'comment',\n"
            + "          'Icon': 'icon', 'Exec': 'exec', 'Keywords': 'keywords'}\n"
            + "apps = []\n"
            + "seen = set()\n"
            + "for d in dirs:\n"
            + "    if not os.path.isdir(d):\n"
            + "        continue\n"
            + "    for f in sorted(glob.glob(os.path.join(d, '*.desktop'))):\n"
            + "        key = os.path.basename(f)\n"
            + "        if key in seen:\n"
            + "            continue\n"
            + "        seen.add(key)\n"
            + "        e = {'name': '', 'genericName': '', 'comment': '', 'icon': '', 'exec': '', 'terminal': False, 'noDisplay': False, 'hidden': False, 'keywords': ''}\n"
            + "        with open(f, 'r', errors='ignore') as fh:\n"
            + "            active = False\n"
            + "            for line in fh:\n"
            + "                line = line.strip()\n"
            + "                if line == '[Desktop Entry]':\n"
            + "                    active = True\n"
            + "                    continue\n"
            + "                if line.startswith('['):\n"
            + "                    active = False\n"
            + "                    continue\n"
            + "                if not active or '=' not in line:\n"
            + "                    continue\n"
            + "                k, v = line.split('=', 1)\n"
            + "                k = k.strip(); v = v.strip()\n"
            + "                if k == 'Type' and v != 'Application':\n"
            + "                    e = None\n"
            + "                    break\n"
            + "                if k == 'NoDisplay' and v.lower() == 'true':\n"
            + "                    e['noDisplay'] = True\n"
            + "                elif k == 'Hidden' and v.lower() == 'true':\n"
            + "                    e['hidden'] = True\n"
            + "                elif k == 'Terminal' and v.lower() == 'true':\n"
            + "                    e['terminal'] = True\n"
            + "                elif k in keymap:\n"
            + "                    e[keymap[k]] = v\n"
            + "        if e and not e['noDisplay'] and not e['hidden'] and e['exec']:\n"
            + "            if not e['name']:\n"
            + "                e['name'] = os.path.basename(f).replace('.desktop', '')\n"
            + "            apps.append(e)\n"
            + "apps.sort(key=lambda a: a['name'].lower())\n"
            + "print(json.dumps(apps))\n"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text.trim());
                    root.apps = parsed;
                    root.loaded = true;
                    root.scanComplete();
                } catch (err) {
                    console.warn("AppScanner: parse error:", err);
                    root.loaded = true;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0)
                    console.warn("AppScanner stderr:", this.text.trim());
            }
        }
    }

    Process {
        id: launchProc
        running: false
        command: []
    }
}
