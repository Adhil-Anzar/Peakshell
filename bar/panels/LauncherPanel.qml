import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import PeakShell
import PeakShell.Apps
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root
    property var panelHost

    // Shorthands so each Behavior/Transition is a one-liner.
    component SpatialAnim: Anim {
        type: Anim.DefaultSpatial
    }
    component EffectsAnim: Anim {
        type: Anim.DefaultEffects
    }

    readonly property int maxVisibleItems: Theme.launcherMaxItems
    readonly property int itemSpacing: 6

    property var filteredApps: []
    // Query whose async file-search results are allowed to update the list.
    property string _activeQuery: ""
    // App/action/calc/web results for the active query. File/folder results
    // are appended to these as they arrive from the async service.
    property var _baseResults: []
    // Skip duplicate searches (settings/scope signals can fire several times)
    // and avoid showing "No results" during the file-search delay.
    property string _lastSearchKey: ""
    property bool _fileSearchPending: false
    property bool _suppressTextSearch: false
    // Previous result window (key -> {obj, idx}) used to keep row identity
    // across searches so the ListView can slide rows instead of rebuilding
    // them. Only rows inside the visible window are tracked: sliding a row in
    // from (or out to) far off-screen strands its delegate outside the view.
    property var _prevRows: ({})
    // Bumped after every search. Web/calc rows keep their object identity (so
    // they slide) while their fields are updated in place; plain JS objects
    // aren't reactive, so delegate bindings depend on this to re-read them.
    property int rowRevision: 0
    // Latest contents of per-query rows (web/calc), key -> row. The model only
    // keeps the snapshot a row had when it was inserted, so delegates read
    // these rows from here instead of from modelData.
    property var _live: ({})

    // Scoped-search state parsed from the search field ("" = no scope).
    property string _scope: ""
    // A scope committed with Tab is shown as a chip instead of keeping the
    // raw prefix in the text field. The canonical value stays internal.
    property string activeScope: ""
    property string _tabText: ""
    property string _tabToken: ""
    property string _tabQuery: ""
    property int _tabIndex: -1
    readonly property string folderTerm: Settings.launcherFolderTerm === "folder" ? "folder" : "directory"
    readonly property string folderTermPlural: folderTerm + "s"
    // Ctrl+Space preview. Only file rows can be previewed.
    property bool previewActive: false
    readonly property var previewEntry: {
        root.rowRevision;
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= root.filteredApps.length)
            return null;
        var entry = root._latest(root.filteredApps[idx]);
        return (entry && entry.kind === "file") ? entry : null;
    }
    readonly property bool showPreview: previewActive && previewEntry !== null
    readonly property real previewHeight: {
        var screenH = root.screen ? root.screen.height : 900;
        return Math.min(560, Math.max(240, screenH * 0.6));
    }

    // Alt on an empty field reveals the scoped-search cheatsheet.
    readonly property bool showScopeHint: altHeld && root.activeScope === "" && searchInput.text.trim().length === 0 && Settings.launcherScopeKey.length > 0
    readonly property real scopeHintHeight: scopeHintText.implicitHeight + 14

    // Identity key for per-query rows ("" for everything else). Web/calc and
    // file/folder rows are updated in place across partial -> final updates,
    // so delegates read their latest fields through _live instead of modelData.
    function _queryRowKey(r) {
        if (!r || r.uid === undefined || r.uid === "")
            return "";
        if (r.kind === "web" || r.kind === "calc" || r.kind === "file" || r.kind === "folder")
            return r.kind + ":" + r.uid;
        return "";
    }
    // While held, Alt previews the selected row's hover tags (same logic as
    // hovering; pairs with Alt+Enter copy). Reset on open/close.
    property bool altHeld: false
    readonly property int visibleCount: filteredApps.length
    readonly property int displayCount: Math.min(visibleCount, maxVisibleItems)
    readonly property bool queryActive: root.activeScope !== "" || searchInput.text.trim().length > 0
    readonly property bool hasResults: visibleCount > 0 && queryActive
    // The empty-state row needs its own height: without it the results area is
    // clipped to zero and "No results" never becomes visible.
    readonly property bool showEmptyMessage: queryActive && visibleCount === 0
        && !showPreview && AppScanner.loaded
    readonly property string emptyText: {
        if (root._fileSearchPending || FileSearch.searching) {
            var parsed = root._effectiveParsed();
            if (parsed.scope === "files")
                return "Searching files…";
            if (parsed.scope === "folders")
                return "Searching " + root.folderTermPlural + "…";
            return "Searching…";
        }
        return root._noResultsText();
    }

    // Currently active/selected index (defaults to first item when results are shown)
    readonly property int selectedIndex: (appList.currentIndex >= 0) ? appList.currentIndex : (hasResults ? 0 : -1)

    // Rotating friendly help shown in the search field, re-picked on each open.
    property string placeholderText: ""
    property int _placeholderIndex: -1
    readonly property var placeholderPool: {
        var pool = ["Type to explore apps, actions and answers", "Hold Alt to preview a result's details", "Alt+Enter copies the highlighted command", "Enter opens the highlighted result", "Right-click a result to copy its command", "Arrow keys to move · Enter to open", "What are we looking for?"];
        if (Settings.launcherCalc)
            pool.splice(3, 0, "Try a calculation: 12*8 works");
        if (Settings.launcherWebSearch)
            pool.splice(4, 0, "Type anything to search the web");
        if (Settings.launcherFuzzy)
            pool.splice(5, 0, "Fuzzy search: typos are welcome");
        if (Settings.launcherFileSearch || Settings.launcherFolderSearch) {
            pool.push("Files and " + root.folderTermPlural + " are searched too");
            pool.push("Ctrl+Space previews the selected file");
        }
        if (Settings.launcherScopeKey.length > 0)
            pool.push("Type " + Settings.launcherScopeKey + "files or " + Settings.launcherScopeKey + root.folderTermPlural + " for recents");
        return pool;
    }

    readonly property var _scopeAliases: ({
        "files": "files",
        "file": "files",
        "directories": "folders",
        "directory": "folders",
        "folders": "folders",
        "folder": "folders",
        "apps": "apps",
        "app": "apps",
        "actions": "actions",
        "action": "actions",
        "ipc": "actions",
        "calc": "calc",
        "calculator": "calc",
        "math": "calc",
        "web": "web",
        "search": "web"
    })

    // Splits "<prefix><scope> <query>" into a scope and the effective query.
    // Unknown prefixes are left alone so a literal "/foo" search still works.
    function _parseScope(text) {
        var t = text.trim();
        var prefix = Settings.launcherScopeKey;
        if (prefix.length === 0 || !t.startsWith(prefix))
            return { scope: "", query: t, token: "" };

        var rest = t.slice(prefix.length);
        var split = -1;
        for (var i = 0; i < rest.length; i++) {
            var c = rest.charAt(i);
            if (c === " " || c === "\t") {
                split = i;
                break;
            }
        }
        var token = (split < 0 ? rest : rest.slice(0, split)).toLowerCase();
        var scope = root._scopeAliases[token] || "";
        if (scope === "")
            return { scope: "", query: t, token: "" };
        return {
            scope: scope,
            query: split < 0 ? "" : rest.slice(split + 1).trim(),
            token: token
        };
    }

    // The scope for the current search. A chip is authoritative; otherwise the
    // typed prefix is parsed as before.
    function _effectiveParsed() {
        if (root.activeScope !== "")
            return { scope: root.activeScope, query: searchInput.text.trim(), token: "" };
        return root._parseScope(searchInput.text);
    }

    // Aliases whose spelling starts with token, deduplicated by canonical scope.
    function _scopeMatches(token) {
        token = (token || "").toLowerCase();
        if (token.length === 0)
            return [];
        var out = [];
        var seen = ({});
        for (var alias in root._scopeAliases) {
            if (alias.indexOf(token) !== 0)
                continue;
            var scope = root._scopeAliases[alias];
            if (seen[scope])
                continue;
            seen[scope] = true;
            out.push({ scope: scope, alias: alias });
        }
        return out;
    }

    function _scopeChipLabel(scope) {
        if (scope === "files")
            return "files";
        if (scope === "folders")
            return root.folderTermPlural;
        if (scope === "apps")
            return "apps";
        if (scope === "actions")
            return "actions";
        if (scope === "calc")
            return "calc";
        if (scope === "web")
            return "web";
        return scope;
    }

    // Tab completes a typed scope into a permanent chip. Repeated Tab (while
    // the query text is unchanged) cycles through ambiguous aliases such as
    // /f -> files -> folders -> files.
    function completeScopeTab() {
        var prefix = Settings.launcherScopeKey;
        if (prefix.length === 0)
            return false;

        if (root.activeScope !== "" && searchInput.text.trim() === root._tabQuery) {
            var candidates = root._scopeMatches(root._tabToken);
            if (candidates.length <= 1)
                return false;
            root._tabIndex = (root._tabIndex + 1) % candidates.length;
            root.activeScope = candidates[root._tabIndex].scope;
            root._cancelSearches();
            root.updateFilter();
            return true;
        }

        var text = searchInput.text;
        var trimmed = text.trim();
        if (!trimmed.startsWith(prefix))
            return false;

        var rest = trimmed.slice(prefix.length);
        var split = -1;
        for (var i = 0; i < rest.length; i++) {
            var c = rest.charAt(i);
            if (c === " " || c === "\t") {
                split = i;
                break;
            }
        }
        var token = (split < 0 ? rest : rest.slice(0, split)).toLowerCase();
        if (token.length === 0)
            return false;

        var matches = root._scopeMatches(token);
        if (matches.length === 0)
            return false;

        root._tabText = text;
        root._tabToken = token;
        root._tabQuery = split < 0 ? "" : rest.slice(split + 1).trim();
        root._tabIndex = 0;
        root.activeScope = matches[0].scope;
        root._setSearchText(root._tabQuery);
        root._cancelSearches();
        root.updateFilter();
        return true;
    }

    // Typing " " after a complete scope token (for example "/files") commits
    // it into the chip immediately, exactly like Tab. Ambiguous prefixes stay
    // literal so Tab can still cycle them.
    function commitScopeFromText() {
        var prefix = Settings.launcherScopeKey;
        if (prefix.length === 0 || root.activeScope !== "")
            return false;

        var text = searchInput.text;
        var trimmed = text.trim();
        if (!trimmed.startsWith(prefix))
            return false;

        var rest = trimmed.slice(prefix.length);
        if (rest.length === 0 || rest.indexOf(" ") >= 0 || rest.indexOf("\t") >= 0)
            return false;

        var token = rest.toLowerCase();
        var matches = root._scopeMatches(token);
        if (matches.length === 0)
            return false;

        var exact = false;
        for (var i = 0; i < matches.length; i++) {
            if (matches[i].alias === token) {
                exact = true;
                break;
            }
        }
        if (!exact && matches.length !== 1)
            return false;

        root._tabText = text;
        root._tabToken = token;
        root._tabQuery = "";
        root._tabIndex = 0;
        root.activeScope = matches[0].scope;
        root._setSearchText("", 0);
        root._cancelSearches();
        root.updateFilter();
        return true;
    }

    function clearScope() {
        root.activeScope = "";
        root._tabText = "";
        root._tabToken = "";
        root._tabQuery = "";
        root._tabIndex = -1;
        root._cancelSearches();
        root.updateFilter();
        searchInput.forceActiveFocus();
    }

    function _noResultsText() {
        var parsed = root._effectiveParsed();
        if (parsed.scope === "files")
            return parsed.query.length > 0 ? "No files for \"" + parsed.query + "\"" : "No recent files";
        if (parsed.scope === "folders")
            return parsed.query.length > 0
                ? "No " + root.folderTermPlural + " for \"" + parsed.query + "\""
                : "No recent " + root.folderTermPlural;
        if (parsed.scope !== "" && parsed.query.length === 0) {
            if (root.activeScope !== "")
                return "Type to search " + root._scopeChipLabel(parsed.scope);
            return "Type a search after " + Settings.launcherScopeKey + parsed.token;
        }
        var noun = "results";
        if (parsed.scope === "apps")
            noun = "apps";
        else if (parsed.scope === "actions")
            noun = "actions";
        else if (parsed.scope === "calc")
            noun = "calculations";
        else if (parsed.scope === "web")
            noun = "web results";
        return "No " + noun + " for \"" + parsed.query + "\"";
    }

    // App search is cheap enough to run at the end of a short keystroke
    // debounce. Filesystem search gets its own longer delay so intermediate
    // queries never start an index or directory walk.
    Timer {
        id: searchDebounce
        interval: 60
        repeat: false
        onTriggered: root.updateFilter()
    }

    Timer {
        id: fileSearchDebounce
        interval: 180
        repeat: false
        onTriggered: root._startFileSearch(root._scope, root._activeQuery)
    }

    // Programmatic text changes (scope chips, open/close) must not schedule a
    // second search through the text-change handler.
    function _setSearchText(text, cursor) {
        root._suppressTextSearch = true;
        searchInput.text = text;
        searchInput.cursorPosition = cursor === undefined ? text.length : cursor;
        root._suppressTextSearch = false;
    }

    function _searchKey(scope, q) {
        return JSON.stringify([
            scope, q,
            Settings.launcherFuzzy,
            Settings.launcherWebSearch,
            Settings.launcherCalc,
            Settings.launcherPowerActions,
            Settings.launcherWallpaperActions,
            Settings.launcherFileSearch,
            Settings.launcherFolderSearch,
            Settings.launcherFileFuzzy,
            Settings.launcherFolderFuzzy,
            Settings.launcherFullFilesystemSearch
        ]);
    }

    function _cancelSearches() {
        searchDebounce.stop();
        fileSearchDebounce.stop();
        root._fileSearchPending = false;
        FileSearch.cancel();
    }

    function _startFileSearch(scope, q) {
        fileSearchDebounce.stop();
        root._fileSearchPending = false;
        if (scope === "files" || scope === "folders") {
            FileSearch.searchScoped(q, scope);
        } else if (scope === ""
                   && (Settings.launcherFileSearch || Settings.launcherFolderSearch)) {
            FileSearch.search(q);
        } else {
            FileSearch.cancel();
        }
    }

    function _scheduleFileSearch(scope, q) {
        fileSearchDebounce.stop();
        root._fileSearchPending = false;
        if (scope === "files" || scope === "folders") {
            // The app debounce already waited for the user to stop typing.
            root._startFileSearch(scope, q);
        } else if (scope === ""
                   // One-letter global queries are too broad: keep the fast
                   // app/action results and let /files handle file lookup.
                   && q.length >= 2
                   && (Settings.launcherFileSearch || Settings.launcherFolderSearch)) {
            FileSearch.cancel();
            root._fileSearchPending = true;
            fileSearchDebounce.restart();
        } else {
            FileSearch.cancel();
        }
    }

    function updateFilter(force) {
        var parsed = root._effectiveParsed();
        var scope = parsed.scope;
        var q = parsed.query;
        root._scope = scope;
        root.previewActive = false;

        if (!q && scope === "") {
            root._cancelSearches();
            root._activeQuery = "";
            root._baseResults = [];
            root._prevRows = ({});
            root.filteredApps = [];
            root._lastSearchKey = "";
            appList.currentIndex = -1;
            appList.forceLayout();
            return;
        }

        root._activeQuery = q;
        var key = root._searchKey(scope, q);
        if (!force && key === root._lastSearchKey)
            return;
        root._lastSearchKey = key;

        // Scope-aware C++ search: only the requested result family is scored
        // and built. Empty scoped queries show the "type to search" hint
        // instead of running an empty scan.
        if (scope === "files" || scope === "folders" || q.length === 0)
            root._baseResults = [];
        else
            root._baseResults = AppScanner.searchScoped(q, scope);
        root._applyResults(root._baseResults, true);

        root._scheduleFileSearch(scope, q);
    }

    // Applies a result list while keeping row identities stable across the
    // partial (recent) and final (indexed) updates.
    function _applyResults(results, resetSelection) {
        results = root._stableize(results);
        var oldIndex = appList.currentIndex;
        root.filteredApps = results;
        root.rowRevision++;
        if (resetSelection || oldIndex < 0)
            appList.currentIndex = results.length > 0 ? 0 : -1;
        else
            appList.currentIndex = Math.max(0, Math.min(oldIndex, results.length - 1));
        appList.forceLayout();
        if (resetSelection && results.length > 0)
            appList.positionViewAtBeginning();
        // The selected row may have changed family (or disappeared) after an
        // async merge; a file preview cannot stay open on a non-file row.
        if (root.previewActive && root.previewEntry === null)
            root.previewActive = false;
    }

    // Base (apps/actions/calc/web) results stay in front; file/folder rows
    // are inserted before the web fallback, deduplicated by stable uid.
    function _mergeFileResults(base, files) {
        if (!files)
            files = [];
        var out = [];
        var web = [];
        var seen = ({});
        // File/folder rows belong only to global search or their explicit
        // scopes. Global search honours the ambient toggles even if a stale
        // async result set arrives. /files and /folder bypass the toggles
        // because those are direct requests.
        function allowed(row) {
            if (row.kind !== "file" && row.kind !== "folder")
                return true;
            if (root._scope === "files")
                return row.kind === "file";
            if (root._scope === "folders")
                return row.kind === "folder";
            if (root._scope === "")
                return row.kind === "file"
                    ? Settings.launcherFileSearch
                    : Settings.launcherFolderSearch;
            return false;
        }
        for (var i = 0; i < base.length; i++) {
            var row = base[i];
            if (!allowed(row))
                continue;
            var uid = row.uid;
            if (uid !== undefined && uid !== "")
                seen[uid] = true;
            if (row.kind === "web")
                web.push(row);
            else
                out.push(row);
        }
        for (var j = 0; j < files.length; j++) {
            var f = files[j];
            if (!allowed(f))
                continue;
            var fuid = f.uid;
            if (fuid !== undefined && fuid !== "" && seen[fuid])
                continue;
            if (fuid !== undefined && fuid !== "")
                seen[fuid] = true;
            out.push(f);
        }
        // The web result is a last-resort fallback. A matching file/folder is
        // more specific than a generic search URL, so it must not sit below it.
        for (var w = 0; w < web.length; w++)
            out.push(web[w]);
        return out;
    }

    // Keep object identity only for app/ipc rows that sit inside the visible
    // window both before and after this search (short slides). Everything else
    // is a fresh row. Rows that collide (same identity key or uid) are dropped
    // so no object appears twice.
    function _stableize(results) {
        var win = root.maxVisibleItems;
        var out = [];
        var seen = ({});
        var next = ({});
        var live = ({});
        for (var i = 0; i < results.length; i++) {
            var r = results[i];
            var key = "";
            if (r.kind === "app")
                key = "app:" + r.exec + "\n" + r.name;
            else if (r.kind === "ipc")
                key = "ipc:" + r.ipcFunction;
            else if (r.kind === "file" || r.kind === "folder")
                key = r.kind + ":" + r.exec;
            else
                key = root._queryRowKey(r);
            var uidKey = (r.uid !== undefined && r.uid !== "") ? "uid:" + r.uid : "";
            if ((key && seen[key]) || (uidKey && seen[uidKey]))
                continue;
            if (key)
                seen[key] = true;
            if (uidKey)
                seen[uidKey] = true;

            var row = r;
            if (key) {
                var prev = root._prevRows[key];
                if (prev && prev.idx < win && out.length < win) {
                    row = prev.obj;
                    // Per-query rows: same object, fresh contents.
                    if (r.kind === "web" || r.kind === "calc") {
                        for (var k in row)
                            if (!(k in r))
                                delete row[k];
                        for (var k2 in r)
                            row[k2] = r[k2];
                    }
                }
                if (out.length < win)
                    next[key] = {
                        obj: row,
                        idx: out.length
                    };
            }
            var qk = root._queryRowKey(r);
            if (qk)
                live[qk] = r;
            out.push(row);
        }
        root._live = live;
        root._prevRows = next;
        return out;
    }

    // Extra height reserved for the selected row's command line.
    readonly property real commandExtra: 23
    readonly property real listHeight: hasResults ? displayCount * Theme.launcherItemHeight + Math.max(0, displayCount - 1) * itemSpacing + ((appList.currentIndex >= 0) ? commandExtra : 0) : 0
    readonly property real emptyHeight: Math.max(48, Theme.launcherItemHeight)
    readonly property real bodyHeight: showPreview ? previewHeight : (hasResults ? listHeight : (showEmptyMessage ? emptyHeight : 0))
    readonly property real extraHeight: showScopeHint && bodyHeight <= 0 ? scopeHintHeight : bodyHeight

    readonly property real totalHeight: Theme.launcherSearchHeight + (extraHeight > 0 ? itemSpacing + extraHeight : 0)

    // Picks a fresh help line, never repeating the previous one.
    function pickPlaceholder() {
        var pool = root.placeholderPool;
        if (pool.length === 0) {
            root.placeholderText = "";
            return;
        }
        var i = Math.floor(Math.random() * pool.length);
        if (pool.length > 1 && i === root._placeholderIndex)
            i = (i + 1) % pool.length;
        root._placeholderIndex = i;
        root.placeholderText = pool[i];
    }

    function open() {
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("launcher");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["launcher"] = root;
        root._cancelSearches();
        root._setSearchText("");
        pickPlaceholder();
        _prevRows = ({});
        filteredApps = [];
        _activeQuery = "";
        _baseResults = [];
        _lastSearchKey = "";
        _scope = "";
        activeScope = "";
        _tabText = "";
        _tabToken = "";
        _tabQuery = "";
        _tabIndex = -1;
        previewActive = false;
        appList.currentIndex = -1;
        searchInput.forceActiveFocus();
    }

    function close() {
        // Release text-input focus while the surface is still mapped (first
        // funneling focus through the search field so a focused command field
        // also lets go cleanly). Hiding with a focused input makes Qt log
        // disableSurface warnings about a null focused surface.
        searchInput.forceActiveFocus();
        searchInput.focus = false;
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["launcher"] = false;
        root._cancelSearches();
        root._setSearchText("");
        _activeQuery = "";
        _baseResults = [];
        _lastSearchKey = "";
        filteredApps = [];
        _scope = "";
        activeScope = "";
        _tabText = "";
        _tabToken = "";
        _tabQuery = "";
        _tabIndex = -1;
        previewActive = false;
        appList.currentIndex = -1;
        altHeld = false;
    }

    function toggle() {
        visible ? close() : open();
    }

    // The freshest contents for a row (per-query rows are updated in place).
    function _latest(entry) {
        var k = root._queryRowKey(entry);
        return (k && root._live[k]) ? root._live[k] : entry;
    }

    // Ctrl+Space preview is file-only; on anything else it simply closes.
    function togglePreview() {
        if (!root.previewEntry) {
            root.previewActive = false;
            return;
        }
        root.previewActive = !root.previewActive;
        // If the preview was opened from the command field, move keyboard
        // ownership back to the search input so Ctrl+Space/Escape/Page keys
        // keep working while the preview is visible (and after it closes).
        searchInput.forceActiveFocus();
    }

    onShowPreviewChanged: {
        if (root.visible)
            searchInput.forceActiveFocus();
    }

    // PageUp/PageDown scroll the open preview by most of a viewport.
    function scrollPreview(direction) {
        if (root.showPreview)
            previewCard.scrollPage(direction);
    }

    onSelectedIndexChanged: {
        if (root.previewActive && root.previewEntry === null)
            root.previewActive = false;
    }

    function launchCurrent() {
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= filteredApps.length)
            return;
        root.activateItem(root._latest(filteredApps[idx]));
    }

    // Dispatches a ranked result map. Calculator results are copied to the
    // clipboard, echoed back into the search box (mirrors OpenSearch), and
    // confirmed through the system notification daemon; the launcher stays
    // open. Everything else closes the launcher after activation.
    function activateItem(entry) {
        if (!entry)
            return;
        if (entry.kind === "calc") {
            AppScanner.activateResult(entry);
            searchInput.text = entry.name;
            Utils.notify("Copied to clipboard", entry.name, "accessories-calculator");
            return;
        }
        AppScanner.activateResult(entry);
        close();
    }

    // The exact string that activating this entry would execute.
    function commandFor(entry) {
        if (!entry)
            return "";
        if (entry.kind === "ipc")
            return "peakshell ipc call ii1qe " + entry.ipcFunction;
        if (entry.kind === "calc")
            return entry.name;
        return entry.exec || "";
    }

    // Copies an entry's command and confirms via the system notification daemon.
    function copyCommand(entry) {
        var cmd = root.commandFor(entry);
        if (!cmd)
            return;
        AppScanner.copyToClipboard(cmd);
        Utils.notify("Copied to clipboard", cmd, "edit-copy");
    }

    function copyCurrent() {
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= filteredApps.length)
            return;
        root.copyCommand(root._latest(filteredApps[idx]));
    }

    // First ";" separated token of a .desktop list field (Keywords/Categories),
    // capitalized for pill display.
    function _firstListToken(s) {
        if (!s)
            return "";
        var parts = s.split(";");
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].trim();
            if (t.length > 0)
                return t.charAt(0).toUpperCase() + t.slice(1);
        }
        return "";
    }

    function moveSelection(delta) {
        if (filteredApps.length === 0)
            return;
        var current = (appList.currentIndex < 0) ? 0 : appList.currentIndex;
        var next = Math.max(0, Math.min(current + delta, filteredApps.length - 1));
        appList.currentIndex = next;
        root.ensureVisible(next);
    }

    // Scrolls just far enough to show row idx including the extra height of
    // its expanded command line. ListView.Contain only knows the fixed slot
    // height, so it would clip the bottom of the expanded card.
    function ensureVisible(idx) {
        var step = Theme.launcherItemHeight + itemSpacing;
        var top = idx * step;
        var bottom = top + Theme.launcherItemHeight + commandExtra;
        var viewH = appList.height;
        var cy = appList.contentY - appList.originY;
        if (top < cy)
            cy = top;
        else if (bottom > cy + viewH)
            cy = bottom - viewH;
        var maxY = Math.max(0, appList.contentHeight + appList.bottomMargin - viewH);
        cy = Math.max(0, Math.min(cy, maxY));
        appList.contentY = cy + appList.originY;
    }

    Connections {
        target: AppScanner
        function onScanComplete() {
            // App data may have changed; drop stabilized identities once.
            root._prevRows = ({});
            root.updateFilter(true);
        }
    }

    Connections {
        target: FileSearch
        function onRecentResultsReady(query, results) {
            if (!root.visible || query !== root._activeQuery)
                return;
            root._applyResults(root._mergeFileResults(root._baseResults, results), false);
        }
        function onSearchFinished(query, results) {
            if (!root.visible || query !== root._activeQuery)
                return;
            root._applyResults(root._mergeFileResults(root._baseResults, results), false);
        }
    }

    Connections {
        target: Settings
        function onLauncherFuzzyChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherWebSearchChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherCalcChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherPowerActionsChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherWallpaperActionsChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherFileSearchChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherFolderSearchChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherFileFuzzyChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherFolderFuzzyChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherFullFilesystemSearchChanged() {
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherScopeKeyChanged() {
            if (Settings.launcherScopeKey.length === 0) {
                root.activeScope = "";
                root._tabText = "";
                root._tabToken = "";
                root._tabQuery = "";
                root._tabIndex = -1;
            }
            if (root.visible)
                root.updateFilter();
        }
        function onLauncherFolderTermChanged() {
            if (root.visible)
                root.updateFilter();
        }
    }

    visible: false
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Alt) {
                root.altHeld = true;
                return;
            }
            switch (event.key) {
            case Qt.Key_Escape:
                if (root.previewActive) {
                    root.previewActive = false;
                    event.accepted = true;
                } else {
                    root.close();
                    event.accepted = true;
                }
                break;
            case Qt.Key_Up:
                root.moveSelection(-1);
                event.accepted = true;
                break;
            case Qt.Key_Down:
                root.moveSelection(1);
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (event.modifiers & Qt.AltModifier)
                    root.copyCurrent();
                else
                    root.launchCurrent();
                event.accepted = true;
                break;
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt)
                root.altHeld = false;
        }

        Item {
            id: launcher
            anchors.centerIn: parent
            width: Theme.launcherWidth

            // The only height animation: resultsArea follows this value.
            height: root.totalHeight
            Behavior on height {
                SpatialAnim {}
            }

            opacity: root.visible ? 1 : 0
            scale: root.visible ? 1 : 0.94
            transformOrigin: Item.Center
            Behavior on opacity {
                EffectsAnim {}
            }
            Behavior on scale {
                SpatialAnim {}
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            // Search bar pill
            Rectangle {
                id: searchBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.launcherSearchHeight

                radius: Theme.cornerLargeRadius
                color: Theme.bgColor
                border.color: searchInput.activeFocus ? Theme.accent : Theme.mutedAccent
                border.width: Theme.generalThickness
                antialiasing: true
                smooth: true
                Behavior on border.color {
                    CAnim {}
                }

                HoverHandler {
                    id: searchBarHover
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 16
                        rightMargin: 12
                    }
                    spacing: 12

                    IconImage {
                        id: searchIcon
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: Theme.launcherIconSize
                        source: Quickshell.iconPath("system-search", "edit-find")
                        backer.mirror: true
                        smooth: true
                        mipmap: true

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            brightness: 1.0
                            colorizationColor: Theme.mutedFgColor
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            color: Theme.fgColor
                            font.pointSize: Theme.launcherSearchFontSize
                            font.family: Theme.labelFontFamily
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            antialiasing: true

                            // Cancel any in-flight filesystem work immediately;
                            // the app debounce below waits for the user to stop.
                            onTextChanged: {
                                if (root._suppressTextSearch)
                                    return;
                                // Publish the new query immediately so a
                                // queued result from the previous query can
                                // never merge into it during the debounce.
                                var parsed = root._effectiveParsed();
                                root._scope = parsed.scope;
                                root._activeQuery = parsed.query;
                                root._lastSearchKey = "";
                                root._fileSearchPending = false;
                                fileSearchDebounce.stop();
                                FileSearch.cancel();
                                searchDebounce.restart();
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Tab) {
                                    root.completeScopeTab();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Space
                                           && !(event.modifiers & Qt.ControlModifier)
                                           && root.commitScopeFromText()) {
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Backspace && searchInput.text.length === 0
                                           && root.activeScope !== "") {
                                    root.clearScope();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Space && (event.modifiers & Qt.ControlModifier)) {
                                    root.togglePreview();
                                    event.accepted = true;
                                } else if (root.showPreview
                                           && (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown)) {
                                    root.scrollPreview(event.key === Qt.Key_PageUp ? -1 : 1);
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            anchors.fill: parent
                            text: root.activeScope !== ""
                                ? "Search " + root._scopeChipLabel(root.activeScope) + "…"
                                : root.placeholderText
                            color: Theme.mutedFgColor
                            font.pointSize: Theme.launcherSearchFontSize
                            font.family: Theme.labelFontFamily
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            visible: searchInput.text.length === 0
                            renderType: Text.CurveRendering
                            antialiasing: true
                        }
                    }

                    // Scope committed with Tab. The raw prefix leaves the
                    // text field and the active scope becomes a removable chip.
                    Rectangle {
                        id: scopeChip
                        visible: root.activeScope !== ""
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: scopeChipRow.implicitWidth + 18
                        implicitHeight: 26
                        radius: implicitHeight / 2
                        color: Theme.mutedBgColor
                        border.color: Theme.mutedAccent
                        border.width: 1
                        clip: true

                        Row {
                            id: scopeChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root._scopeChipLabel(root.activeScope)
                                color: Theme.fgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                                renderType: Text.CurveRendering
                                antialiasing: true
                            }

                            Item {
                                width: 14
                                height: 14
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: scopeChipClose.containsMouse ? Theme.hoveredBgColor : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize * 0.9
                                    font.family: Theme.labelFontFamily
                                    renderType: Text.CurveRendering
                                    antialiasing: true
                                }

                                MouseArea {
                                    id: scopeChipClose
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearScope()
                                }
                            }
                        }
                    }

                    Item {
                        id: searchAction
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Theme.iconFontSize
                        implicitHeight: Theme.iconFontSize

                        // Loading spinner shares the clear button's slot. It
                        // yields to the clear button as soon as the bar is
                        // hovered, so the action is never unreachable.
                        Canvas {
                            id: searchSpinner
                            anchors.centerIn: parent
                            width: Theme.iconFontSize
                            height: Theme.iconFontSize
                            visible: root.visible && FileSearch.searching && !searchBarHover.hovered
                            opacity: visible ? 1 : 0
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = Theme.mutedFgColor;
                                ctx.lineWidth = Math.max(1.5, width * 0.12);
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                var start = -Math.PI / 2;
                                ctx.arc(width / 2, height / 2, width / 2 - ctx.lineWidth, start, start + Math.PI * 1.4);
                                ctx.stroke();
                            }
                            RotationAnimation on rotation {
                                running: searchSpinner.visible
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 850
                            }
                            Behavior on opacity {
                                EffectsAnim {}
                            }
                        }

                        ClickButton {
                            id: clearBtn
                            visible: opacity > 0
                            opacity: ((searchInput.text.length > 0 || root.activeScope !== "") && (searchBarHover.hovered || clearBtn.isHovered)) ? 1.0 : 0.0
                            symbol: "edit-clear"
                            size: Theme.iconFontSize
                            bgColor: "transparent"
                            cornerRadius: Theme.cornerRadius
                            iconColor: clearBtn.isHovered ? Theme.fgColor : Theme.mutedFgColor
                            onPress: {
                                searchInput.text = "";
                                root.clearScope();
                            }

                            Behavior on opacity {
                                EffectsAnim {}
                            }
                        }
                    }
                }
            }

            // Scoped-search cheatsheet, revealed with Alt on an empty field.
            Rectangle {
                id: scopeHint
                anchors.top: searchBar.bottom
                anchors.topMargin: root.itemSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: root.scopeHintHeight
                radius: Math.min(Theme.cornerLargeRadius, implicitHeight / 2)
                color: Theme.bgColor
                border.color: Theme.mutedAccent
                border.width: 1
                opacity: root.showScopeHint ? 1 : 0
                visible: root.showScopeHint

                Behavior on opacity {
                    EffectsAnim {}
                }

                Text {
                    id: scopeHintText
                    anchors.centerIn: parent
                    width: parent.width - 28
                    text: {
                        var p = Settings.launcherScopeKey;
                        if (p.length === 0)
                            return "";
                        return p + "files recent files · " + p + root.folderTerm + " recent " + root.folderTermPlural + " · "
                            + p + "app apps · " + p + "action actions · "
                            + p + "calc calculator · " + p + "web web"
                            + "    Ctrl+Space previews files";
                    }
                    color: Theme.mutedFgColor
                    font.pointSize: Theme.labelFontSize * 0.85
                    font.family: Theme.labelFontFamily
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    renderType: Text.CurveRendering
                    antialiasing: true
                }
            }

            // Ctrl+Space file preview. FilePreviewCard handles images, text
            // highlighting and unsupported files, mirroring the clipboard.
            FilePreviewCard {
                id: previewCard
                anchors.top: searchBar.bottom
                anchors.topMargin: root.itemSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.previewHeight
                visible: root.showPreview
                opacity: visible ? 1 : 0
                z: 50
                filePath: (root.showPreview && root.previewEntry) ? root.previewEntry.exec : ""
                fileName: (root.showPreview && root.previewEntry) ? root.previewEntry.name : ""
                fileIcon: (root.showPreview && root.previewEntry) ? root.previewEntry.icon : "text-x-generic"
                onToggleRequested: root.togglePreview()

                Behavior on opacity {
                    EffectsAnim {}
                }
            }

            // Results list container (fixed viewport of up to 5 items, scrollable)
            Item {
                id: resultsArea
                anchors.top: searchBar.bottom
                anchors.topMargin: root.itemSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                // Follows the launcher's animated height (no second animation).
                height: Math.max(0, launcher.height - searchBar.height - root.itemSpacing)
                clip: true

                opacity: ((root.hasResults || root.showEmptyMessage) && !root.showPreview) ? 1 : 0
                Behavior on opacity {
                    EffectsAnim {}
                }

                ScriptModel {
                    id: appScriptModel
                    values: root.filteredApps
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    clip: true
                    spacing: root.itemSpacing
                    model: appScriptModel
                    currentIndex: -1
                    highlight: null
                    boundsBehavior: Flickable.StopAtBounds
                    // Rows have a fixed slot height; the selected card grows
                    // visually by commandExtra, so keep that room at the end.
                    bottomMargin: root.commandExtra

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                        visible: false
                    }

                    // Shuffle & displacement transitions
                    // Rows slide to their new slots. `displaced` also covers
                    // add/remove displacement. (No `add` fade for now.)
                    displaced: Transition {
                        SpatialAnim {
                            property: "y"
                        }
                    }
                    move: Transition {
                        SpatialAnim {
                            property: "y"
                        }
                    }

                    delegate: Item {
                        id: del
                        required property var modelData
                        required property int index

                        // Avoid animating scale when delegate is initially scrolled in
                        property bool ready: false

                        // Cascade entrance ("shuffle")
                        // 0 -> 1 when this row is created. Drives a drop-in
                        // (translate), a small scale-up and a fade, staggered by
                        // row position. Owned entirely by the row, so it can't
                        // leave anything stranded by the ListView.
                        property real enter: 0

                        // Reads a field of the row; depends on rowRevision so
                        // in-place updates to a reused row refresh the UI.
                        function liveRow() {
                            root.rowRevision;
                            return root._latest(del.modelData);
                        }
                        function field(name) {
                            return del.liveRow()[name];
                        }
                        SequentialAnimation {
                            id: enterAnim
                            PauseAnimation {
                                duration: Math.max(0, Math.min(del.index, 6)) * 35
                            }
                            SpatialAnim {
                                target: del
                                property: "enter"
                                from: 0
                                to: 1
                            }
                        }
                        Component.onCompleted: {
                            ready = true;
                            enterAnim.start();
                        }
                        opacity: Math.min(1, del.enter)

                        readonly property int distance: Math.abs(del.index - root.selectedIndex)
                        readonly property bool isSelected: del.index === root.selectedIndex

                        // Pills for the tag row: the kind pill plus, on hover,
                        // keyword/category info pills (or a sensible fallback).
                        // On hover the kind pill steps aside whenever keyword
                        // or category pills take over.
                        // Hovered rows show the extended tag logic; holding Alt
                        // previews the same for the selected row.
                        readonly property bool tagsHover: delMa.containsMouse || (root.altHeld && del.isSelected)
                        readonly property string kindLabel: {
                            root.rowRevision;
                            var d = del.liveRow();
                            if (d.kind === "ipc")
                                return "Action";
                            if (d.kind === "calc")
                                return "Calc";
                            if (d.kind === "web")
                                return "Web";
                            if (d.kind === "file")
                                return "File";
                            if (d.kind === "folder")
                                return root.folderTerm.charAt(0).toUpperCase() + root.folderTerm.slice(1);
                            return d.terminal ? "CLI" : "App";
                        }
                        // The timer action shows the live countdown in place of
                        // its description while a timer is active.
                        readonly property bool isTimerRow: {
                            root.rowRevision;
                            var d = del.liveRow();
                            return d.kind === "ipc" && d.ipcFunction === "timer";
                        }
                        readonly property string timerText: {
                            if (!del.isTimerRow || !TimerService.running)
                                return "";
                            return TimerService.formatted + " remaining";
                        }
                        readonly property bool kindStepsAside: {
                            root.rowRevision;
                            var d = del.liveRow();
                            if (!del.tagsHover || d.kind !== "app")
                                return false;
                            return root._firstListToken(d.keywords).length > 0 || root._firstListToken(d.categories).length > 0;
                        }
                        readonly property var infoPills: {
                            root.rowRevision;
                            if (!del.tagsHover)
                                return [];
                            var d = del.liveRow();
                            var pills = [];
                            if (d.kind === "app") {
                                var kw = root._firstListToken(d.keywords);
                                var cat = root._firstListToken(d.categories);
                                if (kw.length > 0)
                                    pills.push(kw);
                                if (cat.length > 0)
                                    pills.push(cat);
                                if (pills.length === 0)
                                    pills.push(d.terminal ? "Terminal" : "Application");
                            } else if (d.kind === "ipc") {
                                pills.push(d.ipcFunction);
                            } else if ((d.kind === "calc" || d.kind === "web") && d.detail) {
                                pills.push(d.detail);
                            } else if (d.kind === "file" || d.kind === "folder") {
                                if (d.detail)
                                    pills.push(d.detail);
                                if (d.keywords)
                                    pills.push(d.keywords);
                            }
                            return pills;
                        }

                        width: appList.width
                        // Fixed slot height: the ListView never has to re-measure
                        // rows when the selection changes, so row positions (and
                        // the shuffle transitions' targets) can't go stale.
                        height: Theme.launcherItemHeight
                        transformOrigin: Item.Center

                        // The one animated value for the selection expansion:
                        // extra card height for the selected row's command line.
                        property real extraH: del.isSelected ? root.commandExtra : 0
                        Behavior on extraH {
                            enabled: del.ready
                            SpatialAnim {}
                        }
                        // 0..1 progress derived from extraH; drives the command
                        // row and tag row so they need no animations of their own.
                        readonly property real expand: del.extraH / root.commandExtra

                        // Rows below the selected one are pushed down visually
                        // (a transform, not layout) to make room for that extra.
                        property real pushY: (root.selectedIndex >= 0 && del.index > root.selectedIndex) ? root.commandExtra : 0
                        Behavior on pushY {
                            enabled: del.ready
                            SpatialAnim {}
                        }
                        transform: [
                            Translate {
                                y: del.pushY + (1 - del.enter) * -18
                            },
                            Scale {
                                origin.x: del.width / 2
                                origin.y: del.height / 2
                                xScale: 0.92 + 0.08 * del.enter
                                yScale: 0.92 + 0.08 * del.enter
                            }
                        ]

                        // Max scale is 1.0 (matches the search bar width); siblings
                        // shrink with distance from the selected row.
                        readonly property real baseScale: Math.max(0.88, 1.0 - del.distance * 0.03)
                        readonly property real targetScale: del.isSelected ? 1.0 : (delMa.containsMouse ? Math.min(0.99, del.baseScale + 0.03) : del.baseScale)
                        scale: del.targetScale
                        Behavior on scale {
                            enabled: del.ready
                            SpatialAnim {}
                        }

                        z: del.isSelected ? 20 : (15 - Math.min(10, del.distance))

                        // Floating Card with matching cornerLargeRadius
                        Rectangle {
                            id: itemCard
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: Theme.launcherItemHeight + del.extraH
                            radius: Theme.cornerLargeRadius
                            color: del.isSelected ? Theme.hoveredBgColor : (delMa.containsMouse ? Theme.mutedBgColor : Theme.bgColor)
                            border.color: del.isSelected ? Theme.accent : Theme.mutedAccent
                            border.width: del.isSelected ? Theme.generalThickness : 1
                            antialiasing: true
                            smooth: true

                            opacity: (del.isSelected || delMa.containsMouse) ? 1.0 : Math.max(0.65, 1.0 - del.distance * 0.08)
                            Behavior on opacity {
                                EffectsAnim {}
                            }

                            Behavior on color {
                                CAnim {}
                            }
                            Behavior on border.color {
                                CAnim {}
                            }
                            Behavior on border.width {
                                NumberAnimation {
                                    duration: Theme.fastEffectsDuration
                                }
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 18
                                    rightMargin: 18
                                }
                                spacing: 14

                                IconImage {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitSize: Theme.launcherIconSize
                                    source: Quickshell.iconPath(del.field("icon") || "application-x-executable", "application-x-executable")
                                    smooth: true
                                    mipmap: true
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: del.field("name") || ""
                                        color: Theme.fgColor
                                        font.bold: true
                                        font.pointSize: Theme.labelFontSize + 2
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: del.timerText.length > 0 ? del.timerText : (del.field("comment") || del.field("genericName") || "")
                                        color: del.timerText.length > 0 ? Theme.accent : Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.9
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }

                                    // Command line: what will be executed (selectable)
                                    Row {
                                        width: parent.width
                                        height: 20 * del.expand
                                        visible: height > 0
                                        opacity: del.expand
                                        spacing: 6
                                        clip: true

                                        Text {
                                            id: commandLabel
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            text: "command:"
                                            color: Theme.mutedFgColor
                                            font.pointSize: Theme.labelFontSize * 0.85
                                            font.family: Theme.labelFontFamily
                                            renderType: Text.CurveRendering
                                            antialiasing: true
                                        }

                                        TextInput {
                                            id: commandField
                                            width: parent.width - commandLabel.width - parent.spacing
                                            height: parent.height
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: {
                                                root.rowRevision;
                                                return root.commandFor(del.liveRow());
                                            }
                                            color: Theme.fgColor
                                            selectionColor: Theme.accent
                                            selectedTextColor: Theme.fgColor
                                            font.pointSize: Theme.labelFontSize * 0.85
                                            font.family: Theme.labelFontFamily
                                            readOnly: true
                                            selectByMouse: true
                                            clip: true
                                            cursorVisible: activeFocus
                                            renderType: Text.CurveRendering

                                            Keys.onPressed: event => {
                                                if (event.key === Qt.Key_Space && (event.modifiers & Qt.ControlModifier)) {
                                                    root.togglePreview();
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if (root.showPreview
                                                    && (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown)) {
                                                    root.scrollPreview(event.key === Qt.Key_PageUp ? -1 : 1);
                                                    event.accepted = true;
                                                    return;
                                                }
                                                switch (event.key) {
                                                case Qt.Key_Escape:
                                                    searchInput.forceActiveFocus();
                                                    root.close();
                                                    event.accepted = true;
                                                    break;
                                                case Qt.Key_Up:
                                                    root.moveSelection(-1);
                                                    searchInput.forceActiveFocus();
                                                    event.accepted = true;
                                                    break;
                                                case Qt.Key_Down:
                                                    root.moveSelection(1);
                                                    searchInput.forceActiveFocus();
                                                    event.accepted = true;
                                                    break;
                                                case Qt.Key_Return:
                                                case Qt.Key_Enter:
                                                    if (event.modifiers & Qt.AltModifier)
                                                        root.copyCurrent();
                                                    else
                                                        root.launchCurrent();
                                                    event.accepted = true;
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                }

                                // Tag row: info pills + kind pill
                                // Selected row only. On hover the kind pill steps
                                // aside (animated, to the right) whenever keyword
                                // or category pills take over.
                                Row {
                                    id: tagRow
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: Math.min(tagRow.implicitWidth, appList.width * 0.5) * del.expand
                                    spacing: 6
                                    clip: true
                                    opacity: del.expand
                                    visible: Layout.preferredWidth > 1

                                    Row {
                                        id: infoRow
                                        spacing: 6

                                        Repeater {
                                            model: del.infoPills
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: Math.min(infoPillLabel.implicitWidth + 20, 140)
                                                height: infoPillLabel.implicitHeight + 10
                                                radius: height * 0.5
                                                color: "transparent"
                                                border.color: Theme.mutedAccent
                                                border.width: 1
                                                clip: true

                                                Text {
                                                    id: infoPillLabel
                                                    width: Math.max(0, Math.min(implicitWidth, parent.width - 20))
                                                    height: implicitHeight
                                                    anchors.centerIn: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    elide: Text.ElideRight
                                                    text: modelData
                                                    color: Theme.mutedFgColor
                                                    font.pointSize: Theme.labelFontSize * 0.85
                                                    font.family: Theme.labelFontFamily
                                                    renderType: Text.CurveRendering
                                                    antialiasing: true
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: kindPill
                                        width: del.kindStepsAside ? 0 : Math.min(kindPillLabel.implicitWidth + 20, 140)
                                        height: kindPillLabel.implicitHeight + 10
                                        visible: width > 1
                                        radius: height * 0.5
                                        color: Theme.accent
                                        opacity: del.kindStepsAside ? 0 : 1
                                        scale: del.kindStepsAside ? 0.7 : 1
                                        transformOrigin: Item.Right
                                        clip: true

                                        Behavior on width {
                                            SpatialAnim {}
                                        }
                                        Behavior on opacity {
                                            EffectsAnim {}
                                        }
                                        Behavior on scale {
                                            SpatialAnim {}
                                        }

                                        Text {
                                            id: kindPillLabel
                                            width: Math.max(0, Math.min(implicitWidth, parent.width - 20))
                                            height: implicitHeight
                                            anchors.centerIn: parent
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                            text: del.kindLabel
                                            color: Theme.fgColor
                                            font.bold: true
                                            font.pointSize: Theme.labelFontSize * 0.85
                                            font.family: Theme.labelFontFamily
                                            renderType: Text.CurveRendering
                                            antialiasing: true
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: delMa
                            anchors.fill: itemCard
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    appList.currentIndex = del.index;
                                    root.copyCommand(del.liveRow());
                                } else {
                                    root.activateItem(del.liveRow());
                                }
                            }
                            onEntered: {
                                appList.currentIndex = del.index;
                            }
                            onWheel: wheel => {
                                wheel.accepted = false; // Allow ListView to handle scrolling
                            }
                        }
                    }

                    Text {
                        visible: root.showEmptyMessage
                        anchors.centerIn: parent
                        text: root.emptyText
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        renderType: Text.CurveRendering
                        antialiasing: true
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        pickPlaceholder();
        if (!AppScanner.loaded)
            AppScanner.scan();
    }
}
