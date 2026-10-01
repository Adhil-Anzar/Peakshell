pragma Singleton
import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root
    function getRealPlayers() {
        return Mpris.players.values.filter(player => isRealPlayer(player));
    }
    property var players: root.getRealPlayers()
    property var trackedPlayer: null
    property var activePlayer: {
        if (trackedPlayer) {
            // Make sure the tracked player is still actually alive and valid
            const currentReal = root.getRealPlayers();
            if (currentReal.includes(trackedPlayer)) {
                return trackedPlayer;
            }
        }

        // Fallback: only pick the first player if real players actually exist
        const currentReal = getRealPlayers();
        return currentReal.length > 0 ? currentReal[0] : null;
    }
    signal trackChanged(bool reverse)

    property bool __reverse: false

    property var activeTrack

    readonly property bool hasActivePlasmaIntegration: Mpris.players.values.some(p => p && p.dbusName && p.dbusName.startsWith('org.mpris.MediaPlayer2.plasma-browser-integration'))
    function isRealPlayer(player) {
        return (
            // Remove native browser buses only if plasma-browser-integration is actually active on D-Bus
            !(hasActivePlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.firefox')) && !(hasActivePlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.chromium')) &&
            // playerctld just copies other buses and we don't need duplicates
            !(player && player.dbusName && player.dbusName.startsWith('org.mpris.MediaPlayer2.playerctld')) &&
            // Non-instance mpd bus
            !(player && player.dbusName && player.dbusName.endsWith('.mpd') && !player.dbusName.endsWith('MediaPlayer2.mpd')));
    }

    Instantiator {
        model: root.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            function onTrackTitleChanged() {
                if (modelData === root.activePlayer)
                    root.updateTrack();
            }

            function onTrackArtistsChanged() {
                if (modelData === root.activePlayer)
                    root.updateTrack();
            }

            function onTrackAlbumChanged() {
                if (modelData === root.activePlayer)
                    root.updateTrack();
            }

            function onTrackArtUrlChanged() {
                if (modelData === root.activePlayer)
                    root.updateTrack();
            }

            function onPlaybackStateChanged() {
                if (modelData.playbackState === MprisPlaybackState.Playing) {
                    root.setActivePlayer(modelData);
                }
            }
        }
    }

    Connections {
        target: Mpris.players

        function onValuesChanged() {
            if (!Mpris.players) {
                console.log("Mpris.players is null");
                return;
            }
            if (Mpris.players.values.length === 0) {
                root.setActivePlayer(null);
                return;
            }

            const currentRealPlayers = Mpris.players.values.filter(player => root.isRealPlayer(player));

            if (root.trackedPlayer && !currentRealPlayers.includes(root.trackedPlayer)) {
                root.trackedPlayer = null;
            }

            // Optional: If no player is tracked, automatically pick the first available real player if any exist
            if (!root.trackedPlayer && currentRealPlayers.length > 0) {
                // If you want it to auto-fallback to another playing/available app, leave this block.
                // Otherwise, leave root.trackedPlayer = null so it cleanly goes to null.
            }
        }
    }

    Connections {
        target: root.activePlayer

        function onTrackTitleChanged() {
            root.updateTrack();
        }

        function onTrackArtistsChanged() {
            root.updateTrack();
        }

        function onTrackAlbumChanged() {
            root.updateTrack();
        }

        function onTrackArtUrlChanged() {
            root.updateTrack();
        }

        function onUniqueIdChanged() {
            root.updateTrack();
        }
    }

    onActivePlayerChanged: this.updateTrack()

    function updateTrack() {
        this.activeTrack = {
            uniqueId: (this.activePlayer && this.activePlayer.uniqueId) ? this.activePlayer.uniqueId : 0,
            artUrl: (this.activePlayer && this.activePlayer.trackArtUrl) ? this.activePlayer.trackArtUrl : "",
            title: (this.activePlayer && this.activePlayer.trackTitle) ? this.activePlayer.trackTitle : "Unknown Title",
            artist: (this.activePlayer && this.activePlayer.trackArtist) ? this.activePlayer.trackArtist : "Unknown Artist",
            album: (this.activePlayer && this.activePlayer.trackAlbum) ? this.activePlayer.trackAlbum : "Unknown Album"
        };

        this.trackChanged(__reverse);
        this.__reverse = false;
    }

    property bool isPlaying: this.activePlayer && this.activePlayer.isPlaying
    property bool canTogglePlaying: this.activePlayer ? this.activePlayer.canTogglePlaying : false
    function togglePlaying() {
        if (this.canTogglePlaying)
            this.activePlayer.togglePlaying();
    }

    property bool canGoPrevious: this.activePlayer ? this.activePlayer.canGoPrevious : false
    function previous() {
        if (this.canGoPrevious) {
            this.__reverse = true;
            this.activePlayer.previous();
        }
    }

    property bool canGoNext: this.activePlayer ? this.activePlayer.canGoNext : false
    function next() {
        if (this.canGoNext) {
            this.__reverse = false;
            this.activePlayer.next();
        }
    }

    property bool canChangeVolume: this.activePlayer && this.activePlayer.volumeSupported && this.activePlayer.canControl

    property bool loopSupported: this.activePlayer && this.activePlayer.loopSupported && this.activePlayer.canControl
    property var loopState: (this.activePlayer && this.activePlayer.loopState !== undefined) ? this.activePlayer.loopState : MprisLoopState.None
    function setLoopState(loopState) {
        if (this.loopSupported) {
            this.activePlayer.loopState = loopState;
        }
    }

    property bool shuffleSupported: this.activePlayer && this.activePlayer.shuffleSupported && this.activePlayer.canControl
    property bool hasShuffle: this.activePlayer ? this.activePlayer.shuffle : false
    function setShuffle(shuffle) {
        if (this.shuffleSupported) {
            this.activePlayer.shuffle = shuffle;
        }
    }

    function setActivePlayer(player) {
        const targetPlayer = player ? player : (Mpris.players.values.length > 0 ? Mpris.players.values[0] : null);
        console.log(`[Mpris] Active player ${targetPlayer} << ${activePlayer}`);

        if (targetPlayer && this.activePlayer) {
            this.__reverse = Mpris.players.indexOf(targetPlayer) < Mpris.players.indexOf(this.activePlayer);
        } else {
            // always animate forward if going to null
            this.__reverse = false;
        }

        this.trackedPlayer = targetPlayer;
    }

    IpcHandler {
        target: "mpris"

        function pauseAll() {
            for (const player of Mpris.players.values) {
                if (player.canPause)
                    player.pause();
            }
        }

        function playPause() {
            root.togglePlaying();
        }
        function previous() {
            root.previous();
        }
        function next() {
            root.next();
        }
    }
}
