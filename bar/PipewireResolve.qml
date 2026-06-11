pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource, Pipewire.preferredDefaultAudioSource]
    }

    // Gets output Icon
    property var outputIcon: {
        if (!Pipewire.defaultAudioSink) return "audio-output-none"
        // remove ts
        // console.log("Count: " + root.linkGroups.length)
        // for (var node in root.linkGroups) {
        //     console.log("======================================")
        //     console.log( node.properties["application.name"] ?? (node.description !== "" ? node.description : node.name ));
        //     console.log( node.properties["media.name"] );

        // }
        if (Pipewire.defaultAudioSink.audio.muted) return "audio-volume-muted";
        const volume = Math.round(Pipewire.defaultAudioSink.audio.volume * 100)
        if (volume >= 66) return "audio-volume-high"
        if (volume >= 33) return "audio-volume-medium"
        if (volume >= 1) return "audio-volume-low"
        if (volume === 0) return "audio-volume-muted"
    }

    property var inputIcon: {
        if (!Pipewire.defaultAudioSource) return "audio-input-microphone-muted"
        if (Pipewire.defaultAudioSource.audio.muted) return "audio-input-microphone-muted";
        const volume = Math.round(Pipewire.defaultAudioSource.audio.volume * 100)
        if (volume >= 66) return "audio-input-microphone-high"
        if (volume >= 33) return "audio-input-microphone-medium"
        if (volume >= 1) return "audio-input-microphone-low"
        if (volume === 0) return "audio-input-microphone-muted"
    }
    function getIconByNode(node) {
        // sink === output : source === input
        if (!node) return "audio-output-muted"
        const prefix = node.isSink ? "audio-volume-" : "audio-input-microphone-";
        if (!node.audio) return prefix + "muted";
        if (node.audio.muted) return prefix + "muted"; // Ik slop code
        const volume = Math.round(node.audio.volume * 100)
        if (volume >= 66) return prefix + "high"
        if (volume >= 33) return prefix + "medium"
        if (volume >= 1) return prefix + "low"
        if (volume === 0) return prefix + "muted"
    }
}
