pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    property var outputIcon: {
        const n = Pipewire.defaultAudioSink;
        if (!n)
            return "audio-output-none";
        if (!n.audio || n.audio.muted)
            return "audio-volume-muted";
        const v = Math.round(n.audio.volume * 100);
        return v >= 66 ? "audio-volume-high" : v >= 33 ? "audio-volume-medium" : v >= 1 ? "audio-volume-low" : "audio-volume-muted";
    }
    property var inputIcon: {
        if (!Pipewire.defaultAudioSource)
            return "audio-input-microphone-muted";
        if (Pipewire.defaultAudioSource.audio.muted)
            return "audio-input-microphone-muted";
        const volume = Math.round(Pipewire.defaultAudioSource.audio.volume * 100);
        if (volume >= 66)
            return "audio-input-microphone-high";
        if (volume >= 33)
            return "audio-input-microphone-medium";
        if (volume >= 1)
            return "audio-input-microphone-low";
        return "audio-input-microphone-muted";
    }

    property int currentIndexInputDevice: {
        for (let i = 0; i < inputDevices.length; ++i) {
            if (inputDevices[i] === Pipewire.defaultAudioSource)
                return i;
        }
        return 0;
    }
    property int currentIndexOutputDevice: {
        for (let i = 0; i < outputDevices.length; ++i) {
            if (outputDevices[i] === Pipewire.defaultAudioSink)
                return i;
        }
        return 0;
    }

    property var inputDevices: {
        const nodes = [];
        for (let i = 0; i < Pipewire.nodes.values.length; ++i) {
            const node = Pipewire.nodes.values[i];
            if (!node.isStream && !node.isSink && node.audio)
                nodes.push(node);
        }
        return nodes;
    }
    property var outputDevices: {
        const nodes = [];
        for (let i = 0; i < Pipewire.nodes.values.length; ++i) {
            const node = Pipewire.nodes.values[i];
            if (!node.isStream && node.isSink && node.audio)
                nodes.push(node);
        }
        return nodes;
    }
    property string status: {
        if (!Pipewire.defaultAudioSink)
            return "No Audio";
        if (Pipewire.defaultAudioSink.audio.muted)
            return "Muted";
        return Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%";
    }

    function getIconByNode(node) {
        if (!node)
            return "audio-volume-muted";
        const prefix = node.isSink ? "audio-volume-" : "audio-input-microphone-";
        if (!node.audio || node.audio.muted)
            return prefix + "muted";
        const volume = Math.round(node.audio.volume * 100);
        if (volume >= 66)
            return prefix + "high";
        if (volume >= 33)
            return prefix + "medium";
        if (volume >= 1)
            return prefix + "low";
        return prefix + "muted";
    }
}
