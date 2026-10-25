pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Distribution identity from /etc/os-release.
//
// Used for distro-specific UI, such as the logo in the bar. Icons are looked up
// by distro ID first, then ID_LIKE, and finally from the LOGO field. Callers
// should still pass a generic icon fallback to Quickshell.iconPath because not
// every icon theme ships every distro logo.
Singleton {
    id: root

    readonly property var fields: root.parseOsRelease(osReleaseFile.text())
    readonly property string distroId: String(root.fields.ID || "").trim().toLowerCase()
    readonly property string distroIdLike: String(root.fields.ID_LIKE || "").trim().toLowerCase()
    readonly property string distroName: String(root.fields.NAME || "").trim()
    readonly property string distroLogo: String(root.fields.LOGO || "").trim()

    readonly property string distroIcon: {
        const icons = {
            "arch": "archlinux",
            "artix": "artixlinux",
            "cachyos": "cachyos",
            "endeavouros": "endeavouros",
            "garuda": "garuda",
            "manjaro": "manjaro",
            "fedora": "fedora",
            "rhel": "redhat",
            "centos": "centos",
            "rocky": "rockylinux",
            "almalinux": "almalinux",
            "debian": "debian",
            "ubuntu": "ubuntu",
            "linuxmint": "linuxmint",
            "mint": "linuxmint",
            "pop": "pop-os",
            "elementary": "elementary",
            "zorin": "zorin",
            "opensuse": "opensuse",
            "opensuse-leap": "opensuse",
            "opensuse-tumbleweed": "opensuse",
            "suse": "opensuse",
            "gentoo": "gentoo",
            "void": "void",
            "nixos": "nixos",
            "kali": "kali-linux",
            "slackware": "slackware",
            "deepin": "deepin",
            "mx": "mxlinux",
            "raspbian": "raspbian"
        };

        if (icons[root.distroId] !== undefined)
            return icons[root.distroId];

        for (const like of root.distroIdLike.split(/\s+/)) {
            if (icons[like] !== undefined)
                return icons[like];
        }

        const logo = root.distroLogo
            .replace(/-logo(-icon)?$/i, "")
            .replace(/^distributor-logo-/i, "");
        return logo || "distributor-logo";
    }

    FileView {
        id: osReleaseFile
        path: "/etc/os-release"
        blockLoading: true
    }

    function parseOsRelease(text) {
        const fields = {};
        for (const line of String(text).split("\n")) {
            const trimmed = line.trim();
            if (trimmed === "" || trimmed.startsWith("#"))
                continue;

            const separator = trimmed.indexOf("=");
            if (separator <= 0)
                continue;

            let value = trimmed.slice(separator + 1).trim();
            if (value.length >= 2
                && (value.startsWith("\"") || value.startsWith("'"))
                && value.endsWith(value[0])) {
                value = value.slice(1, -1);
            }
            fields[trimmed.slice(0, separator)] = value;
        }
        return fields;
    }
}
