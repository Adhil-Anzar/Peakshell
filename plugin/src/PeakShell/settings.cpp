#include "settings.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qmetaobject.h>

namespace peakshell {

using Qt::StringLiterals::operator""_s;

Settings::Settings(QObject* parent)
    : QObject(parent)
    , m_settings(u"PeakShell"_s, u"PeakShell"_s) {
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(250);
    connect(&m_debounce, &QTimer::timeout, this, &Settings::onResyncTimeout);
    const QMetaObject* mo = metaObject();
    for (int i = mo->propertyOffset(); i < mo->propertyCount(); ++i) {
        const QMetaProperty prop = mo->property(i);
        m_last.insert(QString::fromUtf8(prop.name()), prop.read(this));
    }
    watchConfig();
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged,
            this, [this] { watchConfig(); scheduleResync(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged,
            this, [this](const QString& path) {
                if (!m_watcher.files().contains(path))
                    m_watcher.addPath(path);
                scheduleResync();
            });
}

void Settings::scheduleResync() {
    m_debounce.start();
}

void Settings::onResyncTimeout() {
    resync();
}

void Settings::watchConfig() {
    const QFileInfo info(m_settings.fileName());
    const QString dirPath = info.absolutePath();
    if (QDir(dirPath).exists()) {
        if (!m_watcher.directories().contains(dirPath))
            m_watcher.addPath(dirPath);
        const QString filePath = info.absoluteFilePath();
        if (QFile::exists(filePath) && !m_watcher.files().contains(filePath))
            m_watcher.addPath(filePath);
        return;
    }
    QDir ancestor(dirPath);
    while (!ancestor.exists() && ancestor.cdUp()) {
    }
    const QString anchorPath = ancestor.absolutePath();
    if (!m_watcher.directories().contains(anchorPath))
        m_watcher.addPath(anchorPath);
}

void Settings::resync() {
    m_settings.sync();
    const QMetaObject* mo = metaObject();
    for (int i = mo->propertyOffset(); i < mo->propertyCount(); ++i) {
        const QMetaProperty prop = mo->property(i);
        const QString name = QString::fromUtf8(prop.name());
        const QVariant current = prop.read(this);
        if (current != m_last.value(name)) {
            m_last.insert(name, current);
            (void)QMetaObject::invokeMethod(this, (name + u"Changed"_s).toUtf8().constData());
        }
    }
}

QString Settings::getString(const QString& key, const QString& def) const {
    return m_settings.value(key, def).toString();
}

void Settings::setString(const QString& key, const QString& v, const QString& def) {
    if (getString(key, def) == v)
        return;
    if (v == def)
        m_settings.remove(key);
    else
        m_settings.setValue(key, v);
    m_settings.sync();
}

double Settings::getDouble(const QString& key, double def) const {
    return m_settings.value(key, def).toDouble();
}

void Settings::setDouble(const QString& key, double v, double def) {
    if (getDouble(key, def) == v)
        return;
    if (v == def)
        m_settings.remove(key);
    else
        m_settings.setValue(key, v);
    m_settings.sync();
}

int Settings::getInt(const QString& key, int def) const {
    return m_settings.value(key, def).toInt();
}

void Settings::setInt(const QString& key, int v, int def) {
    if (getInt(key, def) == v)
        return;
    if (v == def)
        m_settings.remove(key);
    else
        m_settings.setValue(key, v);
    m_settings.sync();
}

bool Settings::getBool(const QString& key, bool def) const {
    return m_settings.value(key, def).toBool();
}

void Settings::setBool(const QString& key, bool v, bool def) {
    if (getBool(key, def) == v)
        return;
    if (v == def)
        m_settings.remove(key);
    else
        m_settings.setValue(key, v);
    m_settings.sync();
}

#define PS_STR(NAME, SETTER, KEY, DEF) \
    QString Settings::NAME() const { return getString(QStringLiteral(KEY), QStringLiteral(DEF)); } \
    void Settings::set##SETTER(const QString& v) { \
        if (NAME() == v) return; \
        setString(QStringLiteral(KEY), v, QStringLiteral(DEF)); \
        emit NAME##Changed(); \
    }

#define PS_DBL(NAME, SETTER, KEY, DEF) \
    double Settings::NAME() const { return getDouble(QStringLiteral(KEY), DEF); } \
    void Settings::set##SETTER(double v) { \
        if (NAME() == v) return; \
        setDouble(QStringLiteral(KEY), v, DEF); \
        emit NAME##Changed(); \
    }

#define PS_INT(NAME, SETTER, KEY, DEF) \
    int Settings::NAME() const { return getInt(QStringLiteral(KEY), DEF); } \
    void Settings::set##SETTER(int v) { \
        if (NAME() == v) return; \
        setInt(QStringLiteral(KEY), v, DEF); \
        emit NAME##Changed(); \
    }

PS_STR(panelBg, PanelBg, "theme/panelBg", "transparent")
PS_STR(bgColor, BgColor, "theme/bgColor", "#77000000")
PS_STR(bgColorFilled, BgColorFilled, "theme/bgColorFilled", "#FF000000")
PS_STR(hoveredBgColor, HoveredBgColor, "theme/hoveredBgColor", "#77444444")
PS_STR(mutedBgColor, MutedBgColor, "theme/mutedBgColor", "#AA242424")
PS_STR(fgColor, FgColor, "theme/fgColor", "#FFFFFFFF")
PS_STR(mutedFgColor, MutedFgColor, "theme/mutedFgColor", "#FFA0A0A0")
PS_STR(altFgColor, AltFgColor, "theme/altFgColor", "#FF050505")
PS_STR(accent, Accent, "theme/accent", "#FF8C00BA")
bool Settings::accentFromWallpaper() const { return getBool(u"theme/accentFromWallpaper"_s, true); }
void Settings::setAccentFromWallpaper(bool v) {
    if (accentFromWallpaper() == v) return;
    setBool(u"theme/accentFromWallpaper"_s, v, true);
    emit accentFromWallpaperChanged();
}
bool Settings::accentCycleEnabled() const { return getBool(u"theme/accentCycleEnabled"_s, false); }
void Settings::setAccentCycleEnabled(bool v) {
    if (accentCycleEnabled() == v) return;
    setBool(u"theme/accentCycleEnabled"_s, v, false);
    emit accentCycleEnabledChanged();
}
PS_INT(accentCycleInterval, AccentCycleInterval, "theme/accentCycleInterval", 5)
PS_STR(mutedAccent, MutedAccent, "theme/mutedAccent", "#AA797979")
PS_STR(battery, Battery, "theme/battery", "#FF21AB5F")
PS_STR(danger, Danger, "theme/danger", "#55FF3333")
PS_STR(dangerPulse, DangerPulse, "theme/dangerPulse", "#FFFF3333")
PS_STR(urgentPulseColor, UrgentPulseColor, "theme/urgentPulseColor", "#CC8800FF")
PS_STR(iconFontFamily, IconFontFamily, "theme/iconFontFamily", "Jetbrains Mono NL")
PS_STR(labelFontFamily, LabelFontFamily, "theme/labelFontFamily", "JetBrains Mono NL")
PS_STR(launcherScopeKey, LauncherScopeKey, "launcher/scopeKey", "/")
PS_STR(launcherFolderTerm, LauncherFolderTerm, "launcher/folderTerm", "directory")

PS_DBL(barHeight, BarHeight, "theme/barHeight", 40)
PS_DBL(barHorizontalPad, BarHorizontalPad, "theme/barHorizontalPad", 20)
PS_DBL(barVerticalPad, BarVerticalPad, "theme/barVerticalPad", 10)
PS_DBL(cornerRadius, CornerRadius, "theme/cornerRadius", 14)
PS_DBL(cornerLargeRadius, CornerLargeRadius, "theme/cornerLargeRadius", 28)
PS_INT(generalThickness, GeneralThickness, "theme/generalThickness", 2)
PS_DBL(dropdownOffset, DropdownOffset, "theme/dropdownOffset", 10)
PS_DBL(thumbnailSize, ThumbnailSize, "theme/thumbnailSize", 56)
PS_DBL(dashboardWidth, DashboardWidth, "theme/dashboardWidth", 500)
PS_DBL(dashboardHeight, DashboardHeight, "theme/dashboardHeight", 750)
PS_DBL(soundPanelWidth, SoundPanelWidth, "theme/soundPanelWidth", 400)
PS_DBL(soundItemMaxCount, SoundItemMaxCount, "theme/soundItemMaxCount", 10)
PS_DBL(soundItemSize, SoundItemSize, "theme/soundItemSize", 100)
PS_DBL(wifiPanelWidth, WifiPanelWidth, "theme/wifiPanelWidth", 400)
PS_DBL(wifiItemMaxCount, WifiItemMaxCount, "theme/wifiItemMaxCount", 14)
PS_DBL(wifiItemSize, WifiItemSize, "theme/wifiItemSize", 60)
PS_DBL(bluetoothPanelWidth, BluetoothPanelWidth, "theme/bluetoothPanelWidth", 400)
PS_DBL(bluetoothItemMaxCount, BluetoothItemMaxCount, "theme/bluetoothItemMaxCount", 14)
PS_DBL(bluetoothItemSize, BluetoothItemSize, "theme/bluetoothItemSize", 60)
PS_DBL(brightnessPanelWidth, BrightnessPanelWidth, "theme/brightnessPanelWidth", 400)
PS_DBL(brightnessItemSize, BrightnessItemSize, "theme/brightnessItemSize", 76)
PS_DBL(mediaPanelWidth, MediaPanelWidth, "theme/mediaPanelWidth", 360)
PS_DBL(workspacePanelWidth, WorkspacePanelWidth, "theme/workspacePanelWidth", 400)
PS_DBL(workspacePanelHeight, WorkspacePanelHeight, "theme/workspacePanelHeight", 100)
PS_DBL(workspacePreviewWidth, WorkspacePreviewWidth, "theme/workspacePreviewWidth", 1000)
PS_DBL(workspacePreviewHeight, WorkspacePreviewHeight, "theme/workspacePreviewHeight", 650)
PS_DBL(clockPanelWidth, ClockPanelWidth, "theme/clockPanelWidth", 450)
PS_DBL(clockPanelHeight, ClockPanelHeight, "theme/clockPanelHeight", 460)
PS_DBL(timerPanelWidth, TimerPanelWidth, "theme/timerPanelWidth", 420)
PS_DBL(trayMenuWidth, TrayMenuWidth, "theme/trayMenuWidth", 260)
PS_DBL(trayMenuItemHeight, TrayMenuItemHeight, "theme/trayMenuItemHeight", 34)
PS_DBL(launcherWidth, LauncherWidth, "theme/launcherWidth", 600)
PS_DBL(launcherPadding, LauncherPadding, "theme/launcherPadding", 8)
PS_DBL(launcherSearchHeight, LauncherSearchHeight, "theme/launcherSearchHeight", 52)
PS_DBL(launcherItemHeight, LauncherItemHeight, "theme/launcherItemHeight", 56)
PS_DBL(launcherIconSize, LauncherIconSize, "theme/launcherIconSize", 28)
PS_DBL(clipboardWidth, ClipboardWidth, "theme/clipboardWidth", 640)
PS_DBL(clipboardItemHeight, ClipboardItemHeight, "theme/clipboardItemHeight", 60)
PS_DBL(notificationPanelWidth, NotificationPanelWidth, "theme/notificationPanelWidth", 420)
PS_DBL(notificationItemMaxCount, NotificationItemMaxCount, "theme/notificationItemMaxCount", 8)
PS_DBL(notificationPopupWidth, NotificationPopupWidth, "theme/notificationPopupWidth", 380)
PS_DBL(notificationIconSize, NotificationIconSize, "theme/notificationIconSize", 32)

PS_INT(labelFontSize, LabelFontSize, "theme/labelFontSize", 11)
PS_INT(iconFontSize, IconFontSize, "theme/iconFontSize", 24)
PS_INT(launcherSearchFontSize, LauncherSearchFontSize, "theme/launcherSearchFontSize", 15)
PS_INT(launcherMaxItems, LauncherMaxItems, "theme/launcherMaxItems", 5)
PS_INT(clipboardMaxItems, ClipboardMaxItems, "clipboard/maxItems", 100)
PS_INT(clipboardMaxVisibleItems, ClipboardMaxVisibleItems, "theme/clipboardMaxVisibleItems", 8)
PS_INT(animationDuration, AnimationDuration, "theme/animationDuration", 350)
PS_INT(spatialDuration, SpatialDuration, "theme/spatialDuration", 450)
PS_INT(fastSpatialDuration, FastSpatialDuration, "theme/fastSpatialDuration", 300)
PS_INT(slowSpatialDuration, SlowSpatialDuration, "theme/slowSpatialDuration", 600)
PS_INT(effectsDuration, EffectsDuration, "theme/effectsDuration", 200)
PS_INT(fastEffectsDuration, FastEffectsDuration, "theme/fastEffectsDuration", 150)
PS_INT(mediaPlayerUpdateDuration, MediaPlayerUpdateDuration, "theme/mediaPlayerUpdateDuration", 1000)
PS_INT(networkUpdateInterval, NetworkUpdateInterval, "theme/networkUpdateInterval", 1000)
PS_INT(hoverDuration, HoverDuration, "theme/hoverDuration", 3000)
PS_INT(notificationPopupTimeout, NotificationPopupTimeout, "theme/notificationPopupTimeout", 5000)
PS_INT(notificationMaxPopups, NotificationMaxPopups, "theme/notificationMaxPopups", 4)
PS_INT(lowPowerThreshold, LowPowerThreshold, "theme/lowPowerThreshold", 20)
PS_INT(osdDuration, OsdDuration, "osd/duration", 1000)
PS_DBL(osdBottomMargin, OsdBottomMargin, "osd/bottomMargin", 15)
PS_STR(osdMonitor, OsdMonitor, "osd/monitor", "")

bool Settings::launcherWebSearch() const { return getBool(u"launcher/webSearch"_s, true); }
bool Settings::launcherCalc() const { return getBool(u"launcher/calc"_s, true); }
bool Settings::launcherFuzzy() const { return getBool(u"launcher/fuzzy"_s, true); }
bool Settings::launcherPowerActions() const { return getBool(u"launcher/powerActions"_s, true); }
bool Settings::launcherWallpaperActions() const { return getBool(u"launcher/wallpaperActions"_s, true); }
bool Settings::launcherFileSearch() const { return getBool(u"launcher/fileSearch"_s, true); }
bool Settings::launcherFolderSearch() const { return getBool(u"launcher/folderSearch"_s, true); }
bool Settings::launcherFileFuzzy() const { return getBool(u"launcher/fileFuzzy"_s, true); }
bool Settings::launcherFolderFuzzy() const { return getBool(u"launcher/folderFuzzy"_s, true); }
bool Settings::launcherFullFilesystemSearch() const { return getBool(u"launcher/fullFilesystemSearch"_s, false); }
bool Settings::clipboardFuzzy() const { return getBool(u"clipboard/fuzzy"_s, true); }
QString Settings::searchEngine() const { return getString(u"launcher/searchEngine"_s, u"DuckDuckGo"_s); }
QString Settings::customSearchUrl() const { return getString(u"launcher/customSearchUrl"_s, QString()); }
QString Settings::notificationPosition() const { return getString(u"notifications/position"_s, u"bottomRight"_s); }
bool Settings::notificationShowCopyButton() const { return getBool(u"notifications/showCopyButton"_s, true); }

void Settings::setLauncherWebSearch(bool v) {
    if (launcherWebSearch() == v) return;
    setBool(u"launcher/webSearch"_s, v, true);
    emit launcherWebSearchChanged();
}
void Settings::setLauncherCalc(bool v) {
    if (launcherCalc() == v) return;
    setBool(u"launcher/calc"_s, v, true);
    emit launcherCalcChanged();
}
void Settings::setLauncherFuzzy(bool v) {
    if (launcherFuzzy() == v) return;
    setBool(u"launcher/fuzzy"_s, v, true);
    emit launcherFuzzyChanged();
}
void Settings::setLauncherPowerActions(bool v) {
    if (launcherPowerActions() == v) return;
    setBool(u"launcher/powerActions"_s, v, true);
    emit launcherPowerActionsChanged();
}
void Settings::setLauncherWallpaperActions(bool v) {
    if (launcherWallpaperActions() == v) return;
    setBool(u"launcher/wallpaperActions"_s, v, true);
    emit launcherWallpaperActionsChanged();
}
void Settings::setLauncherFileSearch(bool v) {
    if (launcherFileSearch() == v) return;
    setBool(u"launcher/fileSearch"_s, v, true);
    emit launcherFileSearchChanged();
}
void Settings::setLauncherFolderSearch(bool v) {
    if (launcherFolderSearch() == v) return;
    setBool(u"launcher/folderSearch"_s, v, true);
    emit launcherFolderSearchChanged();
}
void Settings::setLauncherFileFuzzy(bool v) {
    if (launcherFileFuzzy() == v) return;
    setBool(u"launcher/fileFuzzy"_s, v, true);
    emit launcherFileFuzzyChanged();
}
void Settings::setLauncherFolderFuzzy(bool v) {
    if (launcherFolderFuzzy() == v) return;
    setBool(u"launcher/folderFuzzy"_s, v, true);
    emit launcherFolderFuzzyChanged();
}
void Settings::setLauncherFullFilesystemSearch(bool v) {
    if (launcherFullFilesystemSearch() == v) return;
    setBool(u"launcher/fullFilesystemSearch"_s, v, false);
    emit launcherFullFilesystemSearchChanged();
}
void Settings::setClipboardFuzzy(bool v) {
    if (clipboardFuzzy() == v) return;
    setBool(u"clipboard/fuzzy"_s, v, true);
    emit clipboardFuzzyChanged();
}
void Settings::setSearchEngine(const QString& v) {
    if (searchEngine() == v) return;
    setString(u"launcher/searchEngine"_s, v, u"DuckDuckGo"_s);
    emit searchEngineChanged();
    emit searchUrlChanged();
    emit searchEngineLabelChanged();
}
void Settings::setCustomSearchUrl(const QString& v) {
    if (customSearchUrl() == v) return;
    setString(u"launcher/customSearchUrl"_s, v, QString());
    emit customSearchUrlChanged();
    emit searchUrlChanged();
    emit searchEngineLabelChanged();
}
void Settings::setNotificationPosition(const QString& v) {
    static const QStringList valid{ u"topLeft"_s, u"topRight"_s, u"bottomLeft"_s, u"bottomRight"_s };
    const QString nv = valid.contains(v) ? v : u"bottomRight"_s;
    if (notificationPosition() == nv) return;
    setString(u"notifications/position"_s, nv, u"bottomRight"_s);
    emit notificationPositionChanged();
}
void Settings::setNotificationShowCopyButton(bool v) {
    if (notificationShowCopyButton() == v) return;
    setBool(u"notifications/showCopyButton"_s, v, true);
    emit notificationShowCopyButtonChanged();
}

bool Settings::moduleMediaPlayer() const { return getBool(u"modules/mediaPlayer"_s, true); }
bool Settings::moduleNotifications() const { return getBool(u"modules/notifications"_s, true); }
bool Settings::moduleSound() const { return getBool(u"modules/sound"_s, true); }
bool Settings::moduleWifi() const { return getBool(u"modules/wifi"_s, true); }
bool Settings::moduleBluetooth() const { return getBool(u"modules/bluetooth"_s, true); }
bool Settings::moduleBrightness() const { return getBool(u"modules/brightness"_s, true); }
bool Settings::brightnessScreenOffAtMin() const { return getBool(u"modules/brightnessScreenOffAtMin"_s, false); }
bool Settings::moduleDateTime() const { return getBool(u"modules/dateTime"_s, true); }
bool Settings::moduleWorkspaces() const { return getBool(u"modules/workspaces"_s, true); }
bool Settings::moduleSysTray() const { return getBool(u"modules/sysTray"_s, true); }

void Settings::setModuleMediaPlayer(bool v) {
    if (moduleMediaPlayer() == v) return;
    setBool(u"modules/mediaPlayer"_s, v, true);
    emit moduleMediaPlayerChanged();
}
void Settings::setModuleNotifications(bool v) {
    if (moduleNotifications() == v) return;
    setBool(u"modules/notifications"_s, v, true);
    emit moduleNotificationsChanged();
}
void Settings::setModuleSound(bool v) {
    if (moduleSound() == v) return;
    setBool(u"modules/sound"_s, v, true);
    emit moduleSoundChanged();
}
void Settings::setModuleWifi(bool v) {
    if (moduleWifi() == v) return;
    setBool(u"modules/wifi"_s, v, true);
    emit moduleWifiChanged();
}
void Settings::setModuleBluetooth(bool v) {
    if (moduleBluetooth() == v) return;
    setBool(u"modules/bluetooth"_s, v, true);
    emit moduleBluetoothChanged();
}
void Settings::setModuleBrightness(bool v) {
    if (moduleBrightness() == v) return;
    setBool(u"modules/brightness"_s, v, true);
    emit moduleBrightnessChanged();
}
void Settings::setBrightnessScreenOffAtMin(bool v) {
    if (brightnessScreenOffAtMin() == v) return;
    setBool(u"modules/brightnessScreenOffAtMin"_s, v, false);
    emit brightnessScreenOffAtMinChanged();
}
void Settings::setModuleDateTime(bool v) {
    if (moduleDateTime() == v) return;
    setBool(u"modules/dateTime"_s, v, true);
    emit moduleDateTimeChanged();
}
void Settings::setModuleWorkspaces(bool v) {
    if (moduleWorkspaces() == v) return;
    setBool(u"modules/workspaces"_s, v, true);
    emit moduleWorkspacesChanged();
}
void Settings::setModuleSysTray(bool v) {
    if (moduleSysTray() == v) return;
    setBool(u"modules/sysTray"_s, v, true);
    emit moduleSysTrayChanged();
}

QStringList Settings::searchEngineNames() const {
    return { u"DuckDuckGo"_s, u"Brave"_s, u"Startpage"_s, u"Ecosia"_s, u"Mojeek"_s, u"Google"_s, u"Custom"_s };
}

QString Settings::searchEngineUrl(const QString& name) const {
    if (name == u"DuckDuckGo"_s) return u"https://duckduckgo.com/?q="_s;
    if (name == u"Brave"_s) return u"https://search.brave.com/search?q="_s;
    if (name == u"Startpage"_s) return u"https://www.startpage.com/sp/search?query="_s;
    if (name == u"Ecosia"_s) return u"https://www.ecosia.org/search?q="_s;
    if (name == u"Mojeek"_s) return u"https://www.mojeek.com/search?q="_s;
    if (name == u"Google"_s) return u"https://www.google.com/search?q="_s;
    if (name == u"Custom"_s) return customSearchUrl();
    return u"https://duckduckgo.com/?q="_s;
}

QString Settings::searchUrl() const {
    if (searchEngine() == u"Custom"_s) {
        const QString c = customSearchUrl().trimmed();
        return c.isEmpty() ? u"https://duckduckgo.com/?q="_s : c;
    }
    return searchEngineUrl(searchEngine());
}

QString Settings::searchEngineLabel() const {
    return searchEngine() == u"Custom"_s ? u"Custom"_s : searchEngine();
}

// Removes a set of keys from the config and syncs once. Used to reset a single
// settings page without disturbing the others (all pages share the "theme" group).
void Settings::removeKeys(const QStringList& keys) {
    for (const QString& key : keys)
        m_settings.remove(key);
    m_settings.sync();
}

// Theme page: colors only.
void Settings::resetTheme() {
    removeKeys({
        u"theme/panelBg"_s,
        u"theme/bgColor"_s,
        u"theme/bgColorFilled"_s,
        u"theme/hoveredBgColor"_s,
        u"theme/mutedBgColor"_s,
        u"theme/fgColor"_s,
        u"theme/mutedFgColor"_s,
        u"theme/altFgColor"_s,
        u"theme/accent"_s,
        u"theme/accentFromWallpaper"_s,
        u"theme/accentCycleEnabled"_s,
        u"theme/accentCycleInterval"_s,
        u"theme/mutedAccent"_s,
        u"theme/battery"_s,
        u"theme/danger"_s,
        u"theme/dangerPulse"_s,
        u"theme/urgentPulseColor"_s,
    });
    emit panelBgChanged();
    emit bgColorChanged();
    emit bgColorFilledChanged();
    emit hoveredBgColorChanged();
    emit mutedBgColorChanged();
    emit fgColorChanged();
    emit mutedFgColorChanged();
    emit altFgColorChanged();
    emit accentChanged();
    emit accentFromWallpaperChanged();
    emit accentCycleEnabledChanged();
    emit accentCycleIntervalChanged();
    emit mutedAccentChanged();
    emit batteryChanged();
    emit dangerChanged();
    emit dangerPulseChanged();
    emit urgentPulseColorChanged();
}

// Config page: fonts, refresh intervals and power warnings.
void Settings::resetConfig() {
    removeKeys({
        u"theme/labelFontFamily"_s,
        u"theme/iconFontFamily"_s,
        u"theme/labelFontSize"_s,
        u"theme/iconFontSize"_s,
        u"theme/mediaPlayerUpdateDuration"_s,
        u"theme/networkUpdateInterval"_s,
        u"theme/lowPowerThreshold"_s,
    });
    emit labelFontFamilyChanged();
    emit iconFontFamilyChanged();
    emit labelFontSizeChanged();
    emit iconFontSizeChanged();
    emit mediaPlayerUpdateDurationChanged();
    emit networkUpdateIntervalChanged();
    emit lowPowerThresholdChanged();
}

// Animation page: animation durations.
void Settings::resetAnimation() {
    removeKeys({
        u"theme/animationDuration"_s,
        u"theme/spatialDuration"_s,
        u"theme/fastSpatialDuration"_s,
        u"theme/slowSpatialDuration"_s,
        u"theme/effectsDuration"_s,
        u"theme/fastEffectsDuration"_s,
        u"theme/hoverDuration"_s,
    });
    emit animationDurationChanged();
    emit spatialDurationChanged();
    emit fastSpatialDurationChanged();
    emit slowSpatialDurationChanged();
    emit effectsDurationChanged();
    emit fastEffectsDurationChanged();
    emit hoverDurationChanged();
}

// Layout page: bar shape, panel sizes, launcher sizing and notification sizing.
void Settings::resetLayout() {
    removeKeys({
        u"theme/barHeight"_s,
        u"theme/barHorizontalPad"_s,
        u"theme/barVerticalPad"_s,
        u"theme/cornerRadius"_s,
        u"theme/cornerLargeRadius"_s,
        u"theme/generalThickness"_s,
        u"theme/dropdownOffset"_s,
        u"theme/thumbnailSize"_s,
        u"theme/dashboardWidth"_s,
        u"theme/dashboardHeight"_s,
        u"theme/soundPanelWidth"_s,
        u"theme/soundItemMaxCount"_s,
        u"theme/soundItemSize"_s,
        u"theme/wifiPanelWidth"_s,
        u"theme/wifiItemMaxCount"_s,
        u"theme/wifiItemSize"_s,
        u"theme/bluetoothPanelWidth"_s,
        u"theme/bluetoothItemMaxCount"_s,
        u"theme/bluetoothItemSize"_s,
        u"theme/brightnessPanelWidth"_s,
        u"theme/brightnessItemSize"_s,
        u"theme/mediaPanelWidth"_s,
        u"theme/workspacePanelWidth"_s,
        u"theme/workspacePanelHeight"_s,
        u"theme/workspacePreviewWidth"_s,
        u"theme/workspacePreviewHeight"_s,
        u"theme/clockPanelWidth"_s,
        u"theme/clockPanelHeight"_s,
        u"theme/timerPanelWidth"_s,
        u"theme/trayMenuWidth"_s,
        u"theme/trayMenuItemHeight"_s,
        u"theme/launcherWidth"_s,
        u"theme/launcherPadding"_s,
        u"theme/launcherSearchHeight"_s,
        u"theme/launcherItemHeight"_s,
        u"theme/launcherIconSize"_s,
        u"theme/launcherSearchFontSize"_s,
        u"theme/launcherMaxItems"_s,
        u"theme/notificationPanelWidth"_s,
        u"theme/notificationItemMaxCount"_s,
        u"theme/notificationPopupWidth"_s,
        u"theme/notificationIconSize"_s,
        u"theme/notificationPopupTimeout"_s,
        u"theme/notificationMaxPopups"_s,
    });
    emit barHeightChanged();
    emit barHorizontalPadChanged();
    emit barVerticalPadChanged();
    emit cornerRadiusChanged();
    emit cornerLargeRadiusChanged();
    emit generalThicknessChanged();
    emit dropdownOffsetChanged();
    emit thumbnailSizeChanged();
    emit dashboardWidthChanged();
    emit dashboardHeightChanged();
    emit soundPanelWidthChanged();
    emit soundItemMaxCountChanged();
    emit soundItemSizeChanged();
    emit wifiPanelWidthChanged();
    emit wifiItemMaxCountChanged();
    emit wifiItemSizeChanged();
    emit bluetoothPanelWidthChanged();
    emit bluetoothItemMaxCountChanged();
    emit bluetoothItemSizeChanged();
    emit brightnessPanelWidthChanged();
    emit brightnessItemSizeChanged();
    emit mediaPanelWidthChanged();
    emit workspacePanelWidthChanged();
    emit workspacePanelHeightChanged();
    emit workspacePreviewWidthChanged();
    emit workspacePreviewHeightChanged();
    emit clockPanelWidthChanged();
    emit clockPanelHeightChanged();
    emit timerPanelWidthChanged();
    emit trayMenuWidthChanged();
    emit trayMenuItemHeightChanged();
    emit launcherWidthChanged();
    emit launcherPaddingChanged();
    emit launcherSearchHeightChanged();
    emit launcherItemHeightChanged();
    emit launcherIconSizeChanged();
    emit launcherSearchFontSizeChanged();
    emit launcherMaxItemsChanged();
    emit notificationPanelWidthChanged();
    emit notificationItemMaxCountChanged();
    emit notificationPopupWidthChanged();
    emit notificationIconSizeChanged();
    emit notificationPopupTimeoutChanged();
    emit notificationMaxPopupsChanged();
}

void Settings::resetLauncher() {
    m_settings.remove(u"launcher"_s);
    m_settings.sync();
    emit launcherWebSearchChanged();
    emit launcherCalcChanged();
    emit launcherFuzzyChanged();
    emit launcherPowerActionsChanged();
    emit launcherWallpaperActionsChanged();
    emit launcherFileSearchChanged();
    emit launcherFolderSearchChanged();
    emit launcherFileFuzzyChanged();
    emit launcherFolderFuzzyChanged();
    emit launcherFullFilesystemSearchChanged();
    emit launcherScopeKeyChanged();
    emit launcherFolderTermChanged();
    emit searchEngineChanged();
    emit customSearchUrlChanged();
    emit searchUrlChanged();
    emit searchEngineLabelChanged();
}

void Settings::resetClipboard() {
    removeKeys({
        u"clipboard/maxItems"_s,
        u"clipboard/fuzzy"_s,
        u"theme/clipboardWidth"_s,
        u"theme/clipboardItemHeight"_s,
        u"theme/clipboardMaxVisibleItems"_s,
    });
    emit clipboardMaxItemsChanged();
    emit clipboardFuzzyChanged();
    emit clipboardWidthChanged();
    emit clipboardItemHeightChanged();
    emit clipboardMaxVisibleItemsChanged();
}

void Settings::resetNotifications() {
    removeKeys({
        u"notifications/position"_s,
        u"notifications/showCopyButton"_s,
        u"theme/notificationPopupTimeout"_s,
        u"theme/notificationMaxPopups"_s,
    });
    emit notificationPositionChanged();
    emit notificationShowCopyButtonChanged();
    emit notificationPopupTimeoutChanged();
    emit notificationMaxPopupsChanged();
}

void Settings::resetOsd() {
    removeKeys({
        u"osd/duration"_s,
        u"osd/bottomMargin"_s,
        u"osd/monitor"_s,
    });
    emit osdDurationChanged();
    emit osdBottomMarginChanged();
    emit osdMonitorChanged();
}

void Settings::resetModules() {
    m_settings.remove(u"modules"_s);
    m_settings.sync();
    emit moduleMediaPlayerChanged();
    emit moduleNotificationsChanged();
    emit moduleSoundChanged();
    emit moduleWifiChanged();
    emit moduleBluetoothChanged();
    emit moduleBrightnessChanged();
    emit brightnessScreenOffAtMinChanged();
    emit moduleDateTimeChanged();
    emit moduleWorkspacesChanged();
    emit moduleSysTrayChanged();
}

bool Settings::webSearchEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/webSearch"_s, true).toBool();
}

bool Settings::calcEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/calc"_s, true).toBool();
}

bool Settings::fuzzyEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/fuzzy"_s, true).toBool();
}

bool Settings::powerActionsEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/powerActions"_s, true).toBool();
}

bool Settings::wallpaperActionsEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/wallpaperActions"_s, true).toBool();
}

bool Settings::fileSearchEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/fileSearch"_s, true).toBool();
}

bool Settings::folderSearchEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/folderSearch"_s, true).toBool();
}

bool Settings::fileFuzzyEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/fileFuzzy"_s, true).toBool();
}

bool Settings::folderFuzzyEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/folderFuzzy"_s, true).toBool();
}

bool Settings::fullFilesystemSearchEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/fullFilesystemSearch"_s, false).toBool();
}

bool Settings::clipboardFuzzyEnabled() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"clipboard/fuzzy"_s, true).toBool();
}

int Settings::clipboardMaxItemCount() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"clipboard/maxItems"_s, 100).toInt();
}

QString Settings::activeSearchName() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"launcher/searchEngine"_s, u"DuckDuckGo"_s).toString();
}

QString Settings::activeSearchUrl() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    const QString name = s.value(u"launcher/searchEngine"_s, u"DuckDuckGo"_s).toString();
    if (name == u"Google"_s) return u"https://www.google.com/search?q="_s;
    if (name == u"Brave"_s) return u"https://search.brave.com/search?q="_s;
    if (name == u"Startpage"_s) return u"https://www.startpage.com/sp/search?query="_s;
    if (name == u"Ecosia"_s) return u"https://www.ecosia.org/search?q="_s;
    if (name == u"Mojeek"_s) return u"https://www.mojeek.com/search?q="_s;
    if (name == u"Custom"_s) {
        const QString c = s.value(u"launcher/customSearchUrl"_s, QString()).toString().trimmed();
        return c.isEmpty() ? u"https://duckduckgo.com/?q="_s : c;
    }
    return u"https://duckduckgo.com/?q="_s;
}

QString Settings::activeNotificationPosition() {
    QSettings s(u"PeakShell"_s, u"PeakShell"_s);
    return s.value(u"notifications/position"_s, u"bottomRight"_s).toString();
}

} // namespace peakshell
