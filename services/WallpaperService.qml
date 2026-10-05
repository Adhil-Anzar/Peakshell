pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateFilePath: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper_state.json"

    // Raw categorized collections
    property var images: []
    property var videos: []

    // Per-tab index memory dictionary
    property var tabIndices: ({})

    // Built-in presets (Rich collection of Gradients, Patterns, and Colors)
    readonly property var gradients: [
        {
            name: "Sunset Aura",
            type: "gradient",
            tag: "gradient",
            colors: ["#FF4E50", "#F9D423"]
        },
        {
            name: "Deep Cyber",
            type: "gradient",
            tag: "gradient",
            colors: ["#0F2027", "#203A43", "#2C5364"]
        },
        {
            name: "Neon Dream",
            type: "gradient",
            tag: "gradient",
            colors: ["#7F00FF", "#E100FF"]
        },
        {
            name: "Aurora Borealis",
            type: "gradient",
            tag: "gradient",
            colors: ["#00F260", "#0575E6"]
        },
        {
            name: "Cosmic Fusion",
            type: "gradient",
            tag: "gradient",
            colors: ["#8A2387", "#E94057", "#F27121"]
        },
        {
            name: "Midnight Bloom",
            type: "gradient",
            tag: "gradient",
            colors: ["#2E0854", "#6B117B", "#B83B5E"]
        },
        {
            name: "Hyper Dark",
            type: "gradient",
            tag: "gradient",
            colors: ["#000000", "#130F40"]
        },
        {
            name: "Toxic Green",
            type: "gradient",
            tag: "gradient",
            colors: ["#11998E", "#38EF7D"]
        },
        {
            name: "Solar Flare",
            type: "gradient",
            tag: "gradient",
            colors: ["#F12711", "#F5AF19"]
        },
        {
            name: "Nordic Fog",
            type: "gradient",
            tag: "gradient",
            colors: ["#2C3E50", "#4CA1AF"]
        },
        {
            name: "Deep Crimson",
            type: "gradient",
            tag: "gradient",
            colors: ["#1E0000", "#500000", "#8B0000"]
        },
        {
            name: "Electric Violet",
            type: "gradient",
            tag: "gradient",
            colors: ["#4776E6", "#8E54E9"]
        },
        {
            name: "Emerald Abyss",
            type: "gradient",
            tag: "gradient",
            colors: ["#093028", "#237A57"]
        },
        {
            name: "OLED Vapor",
            type: "gradient",
            tag: "gradient",
            colors: ["#1F1C2C", "#928DAB"]
        },
        {
            name: "Magma Ember",
            type: "gradient",
            tag: "gradient",
            colors: ["#3A0007", "#8A1C14", "#FF5E36"]
        },
        {
            name: "Abyssal Blue",
            type: "gradient",
            tag: "gradient",
            colors: ["#000428", "#004E92"]
        },
        {
            name: "Rose Quartz",
            type: "gradient",
            tag: "gradient",
            colors: ["#2B1055", "#7597DE"]
        },
        {
            name: "Twilight Sky",
            type: "gradient",
            tag: "gradient",
            colors: ["#0C1033", "#2B32B2", "#1488CC"]
        }
    ]

    readonly property var colors: [
        {
            name: "Obsidian Void",
            type: "color",
            tag: "color",
            color: "#0A0A0D"
        },
        {
            name: "Midnight Navy",
            type: "color",
            tag: "color",
            color: "#0F1522"
        },
        {
            name: "Deep Wine",
            type: "color",
            tag: "color",
            color: "#1A0F1A"
        },
        {
            name: "Slate Carbon",
            type: "color",
            tag: "color",
            color: "#18181C"
        },
        {
            name: "Forest Pine",
            type: "color",
            tag: "color",
            color: "#0D1912"
        },
        {
            name: "Espresso Roast",
            type: "color",
            tag: "color",
            color: "#1A120B"
        },
        {
            name: "Amethyst Shadow",
            type: "color",
            tag: "color",
            color: "#160D20"
        },
        {
            name: "Gunmetal Steel",
            type: "color",
            tag: "color",
            color: "#1F2429"
        },
        {
            name: "Ashen Graphite",
            type: "color",
            tag: "color",
            color: "#222226"
        },
        {
            name: "Blood Moon",
            type: "color",
            tag: "color",
            color: "#220909"
        },
        {
            name: "Nordic Slate",
            type: "color",
            tag: "color",
            color: "#17202A"
        },
        {
            name: "Earthy Moss",
            type: "color",
            tag: "color",
            color: "#141C12"
        },
        {
            name: "Chocolate Bark",
            type: "color",
            tag: "color",
            color: "#211510"
        },
        {
            name: "Titanium Mist",
            type: "color",
            tag: "color",
            color: "#2A2D34"
        },
        {
            name: "Pure OLED Black",
            type: "color",
            tag: "color",
            color: "#000000"
        },
        {
            name: "Royal Indigo",
            type: "color",
            tag: "color",
            color: "#11102A"
        }
    ]

    // Active tab and its items
    property string currentTab: "images"

    // Available tabs (videos omitted if none found)
    readonly property var availableTabs: {
        let tabs = [];
        if (images && images.length > 0) {
            tabs.push({
                id: "images",
                name: "Images",
                count: images.length
            });
        }
        if (videos && videos.length > 0) {
            tabs.push({
                id: "videos",
                name: "Videos",
                count: videos.length
            });
        }
        tabs.push({
            id: "gradients",
            name: "Gradients",
            count: gradients.length
        });
        tabs.push({
            id: "colors",
            name: "Colors",
            count: colors.length
        });
        return tabs;
    }

    readonly property var currentTabItems: {
        if (currentTab === "images")
            return images;
        if (currentTab === "videos")
            return videos;
        if (currentTab === "gradients")
            return gradients;
        if (currentTab === "colors")
            return colors;
        return images;
    }

    property int currentTabIndex: -1
    property var currentWallpaper: (currentTabItems && currentTabItems.length > 0 && currentTabIndex >= 0 && currentTabIndex < currentTabItems.length) ? currentTabItems[currentTabIndex] : null
    // Video audio settings
    property bool videoMuted: true
    property real videoVolume: 0.5

    signal requestShowPreview
    signal requestHidePreview

    function setTab(tabId) {
        if (tabId === "videos" && (!videos || videos.length === 0))
            return;

        let newIndices = Object.assign({}, tabIndices);
        newIndices[currentTab] = currentTabIndex;
        tabIndices = newIndices;

        currentTab = tabId;

        const targetIndex = (tabId in tabIndices) ? tabIndices[tabId] : 0;
        const n = currentTabItems ? currentTabItems.length : 0;
        if (n > 0) {
            currentTabIndex = Math.max(0, Math.min(targetIndex, n - 1));
            currentWallpaper = currentTabItems[currentTabIndex];
            saveState();
        }
    }

    function nextTab() {
        if (!availableTabs || availableTabs.length === 0)
            return;
        const curIdx = availableTabs.findIndex(t => t.id === currentTab);
        const nextIdx = (curIdx + 1) % availableTabs.length;
        setTab(availableTabs[nextIdx].id);
        requestShowPreview();
    }

    function previousTab() {
        if (!availableTabs || availableTabs.length === 0)
            return;
        const curIdx = availableTabs.findIndex(t => t.id === currentTab);
        const prevIdx = (curIdx - 1 + availableTabs.length) % availableTabs.length;
        setTab(availableTabs[prevIdx].id);
        requestShowPreview();
    }

    property bool autoCycle: false

    Timer {
        id: autoCycleTimer
        interval: 30000
        running: true
        repeat: true
        onTriggered: if (root.autoCycle)
            root.step(1)
    }

    function step(delta) {
        const n = currentTabItems ? currentTabItems.length : 0;
        if (n < 2)
            return;
        select(((currentTabIndex + delta) % n + n) % n);
    }

    function next() {
        step(1);
        requestShowPreview();
    }
    function previous() {
        step(-1);
        requestShowPreview();
    }

    function select(index) {
        if (!currentTabItems || index < 0 || index >= currentTabItems.length)
            return;
        currentTabIndex = index;
        currentWallpaper = currentTabItems[index];

        let newIndices = Object.assign({}, tabIndices);
        newIndices[currentTab] = index;
        tabIndices = newIndices;

        autoCycleTimer.restart();
        saveState();
    }

    function showPreview() {
        requestShowPreview();
    }

    function toggleMute() {
        videoMuted = !videoMuted;
        saveState();
    }

    function saveState() {
        if (!currentWallpaper)
            return;
        const state = {
            tab: root.currentTab,
            name: currentWallpaper.name || "",
            type: currentWallpaper.type || "",
            path: currentWallpaper.path || "",
            muted: root.videoMuted,
            volume: root.videoVolume
        };
        saveProc.running = false;
        saveProc.command = ["python3", "-c", "import os, sys, json\n" + "p = os.path.expanduser('~/.cache/quickshell/wallpaper_state.json')\n" + "os.makedirs(os.path.dirname(p), exist_ok=True)\n" + "with open(p, 'w') as f:\n" + "    f.write(sys.argv[1])\n", JSON.stringify(state)];
        saveProc.running = true;
    }

    Process {
        id: saveProc
        running: false
    }
    property bool isInitialScan: true

    function rescan() {
        scanProc.running = false;
        scanProc.running = true;
    }

    // Process to scan wallpapers from ~/Pictures/Wallpapers (Recursive)
    Process {
        id: scanProc
        running: true
        command: ["python3", "-c", "import os, json\n" + "wall_dir = os.path.expanduser('~/Pictures/Wallpapers')\n" + "img_exts = {'.png', '.jpg', '.jpeg', '.webp', '.bmp'}\n" + "vid_exts = {'.mp4', '.mkv', '.webm', '.mov', '.m4v', '.avi'}\n" + "imgs, vids = [], []\n" + "if os.path.isdir(wall_dir):\n" + "    for root_dir, _, files in os.walk(wall_dir):\n" + "        for f in sorted(files):\n" + "            ext = os.path.splitext(f)[1].lower()\n" + "            name = os.path.splitext(f)[0]\n" + "            full_path = os.path.join(root_dir, f)\n" + "            if ext in img_exts:\n" + "                imgs.append({'name': name, 'path': 'file://' + full_path, 'type': 'image', 'tag': 'image'})\n" + "            elif ext in vid_exts:\n" + "                vids.append({'name': name, 'path': 'file://' + full_path, 'type': 'video', 'tag': 'video'})\n" + "print(json.dumps({'images': imgs, 'videos': vids}))\n"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const text = this.text.trim();
                    if (text.length > 0) {
                        const parsed = JSON.parse(text);
                        const oldPath = root.currentWallpaper ? root.currentWallpaper.path : "";

                        root.images = parsed.images || [];
                        root.videos = parsed.videos || [];

                        if (root.isInitialScan) {
                            root.isInitialScan = false;
                            loadStateProc.running = false;
                            loadStateProc.running = true;
                        } else if (root.currentTabItems && root.currentTabItems.length > 0) {
                            let newIdx = -1;
                            if (oldPath) {
                                newIdx = root.currentTabItems.findIndex(w => w.path === oldPath);
                            }
                            if (newIdx >= 0) {
                                root.currentTabIndex = newIdx;
                            } else {
                                root.currentTabIndex = Math.min(Math.max(0, root.currentTabIndex), root.currentTabItems.length - 1);
                            }
                            root.currentWallpaper = root.currentTabItems[root.currentTabIndex];
                        }
                    }
                } catch (e) {
                    console.warn("Error parsing wallpaper files:", e);
                }
            }
        }
    }

    // Process to continuously watch ~/Pictures/Wallpapers for file/folder changes
    Process {
        id: watchProc
        running: true
        command: ["python3", "-c", "import os, sys, time\n" + "wall_dir = os.path.expanduser('~/Pictures/Wallpapers')\n" + "def get_state():\n" + "    if not os.path.exists(wall_dir): return (0, 0)\n" + "    try:\n" + "        entries = []\n" + "        for r, d, files in os.walk(wall_dir):\n" + "            for f in files:\n" + "                p = os.path.join(r, f)\n" + "                st = os.stat(p)\n" + "                entries.append((p, st.st_mtime, st.st_size))\n" + "        return tuple(sorted(entries))\n" + "    except Exception:\n" + "        return (0, 0)\n" + "prev = get_state()\n" + "while True:\n" + "    time.sleep(2)\n" + "    curr = get_state()\n" + "    if curr != prev:\n" + "        sys.exit(0)\n"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.rescan();
                watchProc.running = false;
                watchProc.running = true;
            }
        }
    }
    Process {
        id: loadStateProc
        running: false
        command: ["python3", "-c", "import os\n" + "p = os.path.expanduser('~/.cache/quickshell/wallpaper_state.json')\n" + "if os.path.isfile(p):\n" + "    with open(p, 'r') as f: print(f.read().strip())\n"]

        stdout: StdioCollector {
            onStreamFinished: {
                let stateLoaded = false;
                try {
                    const text = this.text.trim();
                    if (text.length > 0) {
                        const state = JSON.parse(text);
                        if (state.muted !== undefined)
                            root.videoMuted = state.muted;
                        if (state.volume !== undefined)
                            root.videoVolume = state.volume;
                        if (state.tab && (state.tab !== "videos" || (root.videos && root.videos.length > 0))) {
                            root.currentTab = state.tab;
                        }
                        if (root.currentTabItems && root.currentTabItems.length > 0) {
                            let idx = -1;
                            if (state.path) {
                                idx = root.currentTabItems.findIndex(w => w.path === state.path);
                            }
                            if (idx < 0 && state.name) {
                                idx = root.currentTabItems.findIndex(w => w.name === state.name);
                            }
                            root.currentTabIndex = (idx >= 0) ? idx : 0;
                            stateLoaded = true;
                        }
                    }
                } catch (e) {
                    console.warn("Error loading wallpaper state:", e);
                }

                if (!stateLoaded) {
                    root.currentTabIndex = 0;
                }

                let newIndices = Object.assign({}, root.tabIndices);
                newIndices[root.currentTab] = root.currentTabIndex;
                root.tabIndices = newIndices;
            }
        }
    }
}
