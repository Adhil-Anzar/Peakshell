pragma Singleton

import QtQuick
import Quickshell
import PeakShell.Wallpapers

Singleton {
    id: root

    // Native C++ scanner handles directory watching and state persistence.
    readonly property var images: WallpaperScanner.images
    readonly property var videos: WallpaperScanner.videos

    property var tabIndices: ({})

    readonly property var gradients: [
        { name: "Sunset Aura",      type: "gradient", tag: "gradient", colors: ["#FF4E50", "#F9D423"] },
        { name: "Deep Cyber",       type: "gradient", tag: "gradient", colors: ["#0F2027", "#203A43", "#2C5364"] },
        { name: "Neon Dream",       type: "gradient", tag: "gradient", colors: ["#7F00FF", "#E100FF"] },
        { name: "Aurora Borealis",  type: "gradient", tag: "gradient", colors: ["#00F260", "#0575E6"] },
        { name: "Cosmic Fusion",    type: "gradient", tag: "gradient", colors: ["#8A2387", "#E94057", "#F27121"] },
        { name: "Midnight Bloom",   type: "gradient", tag: "gradient", colors: ["#2E0854", "#6B117B", "#B83B5E"] },
        { name: "Hyper Dark",       type: "gradient", tag: "gradient", colors: ["#000000", "#130F40"] },
        { name: "Toxic Green",      type: "gradient", tag: "gradient", colors: ["#11998E", "#38EF7D"] },
        { name: "Solar Flare",      type: "gradient", tag: "gradient", colors: ["#F12711", "#F5AF19"] },
        { name: "Nordic Fog",       type: "gradient", tag: "gradient", colors: ["#2C3E50", "#4CA1AF"] },
        { name: "Deep Crimson",     type: "gradient", tag: "gradient", colors: ["#1E0000", "#500000", "#8B0000"] },
        { name: "Electric Violet",  type: "gradient", tag: "gradient", colors: ["#4776E6", "#8E54E9"] },
        { name: "Emerald Abyss",    type: "gradient", tag: "gradient", colors: ["#093028", "#237A57"] },
        { name: "OLED Vapor",       type: "gradient", tag: "gradient", colors: ["#1F1C2C", "#928DAB"] },
        { name: "Magma Ember",      type: "gradient", tag: "gradient", colors: ["#3A0007", "#8A1C14", "#FF5E36"] },
        { name: "Abyssal Blue",     type: "gradient", tag: "gradient", colors: ["#000428", "#004E92"] },
        { name: "Rose Quartz",      type: "gradient", tag: "gradient", colors: ["#2B1055", "#7597DE"] },
        { name: "Twilight Sky",     type: "gradient", tag: "gradient", colors: ["#0C1033", "#2B32B2", "#1488CC"] }
    ]

    readonly property var colors: [
        { name: "Obsidian Void",   type: "color", tag: "color", color: "#0A0A0D" },
        { name: "Midnight Navy",   type: "color", tag: "color", color: "#0F1522" },
        { name: "Deep Wine",       type: "color", tag: "color", color: "#1A0F1A" },
        { name: "Slate Carbon",    type: "color", tag: "color", color: "#18181C" },
        { name: "Forest Pine",     type: "color", tag: "color", color: "#0D1912" },
        { name: "Espresso Roast",  type: "color", tag: "color", color: "#1A120B" },
        { name: "Amethyst Shadow", type: "color", tag: "color", color: "#160D20" },
        { name: "Gunmetal Steel",  type: "color", tag: "color", color: "#1F2429" },
        { name: "Ashen Graphite",  type: "color", tag: "color", color: "#222226" },
        { name: "Blood Moon",      type: "color", tag: "color", color: "#220909" },
        { name: "Nordic Slate",    type: "color", tag: "color", color: "#17202A" },
        { name: "Earthy Moss",     type: "color", tag: "color", color: "#141C12" },
        { name: "Chocolate Bark",  type: "color", tag: "color", color: "#211510" },
        { name: "Titanium Mist",   type: "color", tag: "color", color: "#2A2D34" },
        { name: "Pure OLED Black", type: "color", tag: "color", color: "#000000" },
        { name: "Royal Indigo",    type: "color", tag: "color", color: "#11102A" }
    ]

    // Default to images if any exist, otherwise gradients
    property string currentTab: (images && images.length > 0) ? "images" : "gradients"

    readonly property var availableTabs: {
        let tabs = [];
        if (images && images.length > 0)
            tabs.push({ id: "images",    name: "Images",    count: images.length });
        if (videos && videos.length > 0)
            tabs.push({ id: "videos",    name: "Videos",    count: videos.length });
        tabs.push({ id: "gradients", name: "Gradients", count: gradients.length });
        tabs.push({ id: "colors",    name: "Colors",     count: colors.length });
        return tabs;
    }

    readonly property var currentTabItems: {
        if (currentTab === "images")    return images;
        if (currentTab === "videos")    return videos;
        if (currentTab === "gradients") return gradients;
        if (currentTab === "colors")    return colors;
        return (images && images.length > 0) ? images : gradients;
    }

    property int currentTabIndex: 0
    property var currentWallpaper: (currentTabItems && currentTabItems.length > 0 && currentTabIndex >= 0 && currentTabIndex < currentTabItems.length)
        ? currentTabItems[currentTabIndex]
        : (gradients.length > 0 ? gradients[0] : null)

    onCurrentTabItemsChanged: {
        if (currentTabItems && currentTabItems.length > 0) {
            if (currentTabIndex < 0 || currentTabIndex >= currentTabItems.length || !currentWallpaper) {
                currentTabIndex = 0;
                currentWallpaper = currentTabItems[0];
            }
        }
    }

    property bool videoMuted: true
    property real videoVolume: 0.5

    signal requestShowPreview
    signal requestHidePreview

    function setTab(tabId) {
        if (tabId === "videos" && (!videos || videos.length === 0))
            return;
        if (tabId === "images" && (!images || images.length === 0))
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
        onTriggered: if (root.autoCycle) root.step(1)
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
        WallpaperScanner.saveState(
            currentWallpaper.path ? currentWallpaper.path.toString() : "",
            currentWallpaper.name || "",
            currentWallpaper.type || "",
            root.currentTab,
            root.videoMuted,
            root.videoVolume
        );
    }

    Component.onCompleted: {
        WallpaperScanner.loadState();
        if (!currentWallpaper && currentTabItems && currentTabItems.length > 0) {
            currentTabIndex = 0;
            currentWallpaper = currentTabItems[0];
        }
    }

    Connections {
        target: WallpaperScanner

        function onImagesChanged() {
            if (root.currentTab === "images")
                root._restoreIndex();
        }
        function onVideosChanged() {
            if (root.currentTab === "videos")
                root._restoreIndex();
        }
        function onStateLoaded(state) {
            if (!state || Object.keys(state).length === 0) {
                if (currentTabIndex < 0 && currentTabItems && currentTabItems.length > 0) {
                    currentTabIndex = 0;
                    currentWallpaper = currentTabItems[0];
                }
                return;
            }

            if (state.muted !== undefined)
                root.videoMuted = state.muted;
            if (state.volume !== undefined)
                root.videoVolume = state.volume;
            if (state.tab && (state.tab !== "videos" || (root.videos && root.videos.length > 0))) {
                if (state.tab !== "images" || (root.images && root.images.length > 0)) {
                    root.currentTab = state.tab;
                }
            }

            let idx = -1;
            if (state.path && root.currentTabItems)
                idx = root.currentTabItems.findIndex(w => w && w.path && w.path.toString() === state.path.toString());
            if (idx < 0 && state.name && root.currentTabItems)
                idx = root.currentTabItems.findIndex(w => w && w.name === state.name);

            root.currentTabIndex = (idx >= 0) ? idx : 0;
            if (root.currentTabItems && root.currentTabItems.length > 0) {
                root.currentWallpaper = root.currentTabItems[root.currentTabIndex];
            }

            let newIndices = Object.assign({}, root.tabIndices);
            newIndices[root.currentTab] = root.currentTabIndex;
            root.tabIndices = newIndices;
        }
    }

    function _restoreIndex() {
        const n = currentTabItems ? currentTabItems.length : 0;
        if (n === 0) return;
        const oldPath = currentWallpaper ? (currentWallpaper.path ? currentWallpaper.path.toString() : "") : "";
        let idx = oldPath ? currentTabItems.findIndex(w => w && w.path && w.path.toString() === oldPath) : -1;
        currentTabIndex = idx >= 0 ? idx : Math.min(Math.max(0, currentTabIndex), n - 1);
        currentWallpaper = currentTabItems[currentTabIndex];
    }
}
