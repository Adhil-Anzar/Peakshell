#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qsettings.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qfilesystemwatcher.h>
#include <qtimer.h>
#include <qvariant.h>

namespace peakshell {

class Settings : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString panelBg READ panelBg WRITE setPanelBg NOTIFY panelBgChanged)
    Q_PROPERTY(QString bgColor READ bgColor WRITE setBgColor NOTIFY bgColorChanged)
    Q_PROPERTY(QString bgColorFilled READ bgColorFilled WRITE setBgColorFilled NOTIFY bgColorFilledChanged)
    Q_PROPERTY(QString hoveredBgColor READ hoveredBgColor WRITE setHoveredBgColor NOTIFY hoveredBgColorChanged)
    Q_PROPERTY(QString mutedBgColor READ mutedBgColor WRITE setMutedBgColor NOTIFY mutedBgColorChanged)
    Q_PROPERTY(QString fgColor READ fgColor WRITE setFgColor NOTIFY fgColorChanged)
    Q_PROPERTY(QString mutedFgColor READ mutedFgColor WRITE setMutedFgColor NOTIFY mutedFgColorChanged)
    Q_PROPERTY(QString altFgColor READ altFgColor WRITE setAltFgColor NOTIFY altFgColorChanged)
    Q_PROPERTY(QString accent READ accent WRITE setAccent NOTIFY accentChanged)
    Q_PROPERTY(bool accentFromWallpaper READ accentFromWallpaper WRITE setAccentFromWallpaper NOTIFY accentFromWallpaperChanged)
    Q_PROPERTY(bool accentCycleEnabled READ accentCycleEnabled WRITE setAccentCycleEnabled NOTIFY accentCycleEnabledChanged)
    Q_PROPERTY(int accentCycleInterval READ accentCycleInterval WRITE setAccentCycleInterval NOTIFY accentCycleIntervalChanged)
    Q_PROPERTY(QString mutedAccent READ mutedAccent WRITE setMutedAccent NOTIFY mutedAccentChanged)
    Q_PROPERTY(QString battery READ battery WRITE setBattery NOTIFY batteryChanged)
    Q_PROPERTY(QString danger READ danger WRITE setDanger NOTIFY dangerChanged)
    Q_PROPERTY(QString dangerPulse READ dangerPulse WRITE setDangerPulse NOTIFY dangerPulseChanged)
    Q_PROPERTY(QString urgentPulseColor READ urgentPulseColor WRITE setUrgentPulseColor NOTIFY urgentPulseColorChanged)
    Q_PROPERTY(QString iconFontFamily READ iconFontFamily WRITE setIconFontFamily NOTIFY iconFontFamilyChanged)
    Q_PROPERTY(QString labelFontFamily READ labelFontFamily WRITE setLabelFontFamily NOTIFY labelFontFamilyChanged)

    Q_PROPERTY(double barHeight READ barHeight WRITE setBarHeight NOTIFY barHeightChanged)
    Q_PROPERTY(double barHorizontalPad READ barHorizontalPad WRITE setBarHorizontalPad NOTIFY barHorizontalPadChanged)
    Q_PROPERTY(double barVerticalPad READ barVerticalPad WRITE setBarVerticalPad NOTIFY barVerticalPadChanged)
    Q_PROPERTY(double cornerRadius READ cornerRadius WRITE setCornerRadius NOTIFY cornerRadiusChanged)
    Q_PROPERTY(double cornerLargeRadius READ cornerLargeRadius WRITE setCornerLargeRadius NOTIFY cornerLargeRadiusChanged)
    Q_PROPERTY(int generalThickness READ generalThickness WRITE setGeneralThickness NOTIFY generalThicknessChanged)
    Q_PROPERTY(double dropdownOffset READ dropdownOffset WRITE setDropdownOffset NOTIFY dropdownOffsetChanged)
    Q_PROPERTY(double thumbnailSize READ thumbnailSize WRITE setThumbnailSize NOTIFY thumbnailSizeChanged)
    Q_PROPERTY(double dashboardWidth READ dashboardWidth WRITE setDashboardWidth NOTIFY dashboardWidthChanged)
    Q_PROPERTY(double dashboardHeight READ dashboardHeight WRITE setDashboardHeight NOTIFY dashboardHeightChanged)
    Q_PROPERTY(double soundPanelWidth READ soundPanelWidth WRITE setSoundPanelWidth NOTIFY soundPanelWidthChanged)
    Q_PROPERTY(double soundItemMaxCount READ soundItemMaxCount WRITE setSoundItemMaxCount NOTIFY soundItemMaxCountChanged)
    Q_PROPERTY(double soundItemSize READ soundItemSize WRITE setSoundItemSize NOTIFY soundItemSizeChanged)
    Q_PROPERTY(double wifiPanelWidth READ wifiPanelWidth WRITE setWifiPanelWidth NOTIFY wifiPanelWidthChanged)
    Q_PROPERTY(double wifiItemMaxCount READ wifiItemMaxCount WRITE setWifiItemMaxCount NOTIFY wifiItemMaxCountChanged)
    Q_PROPERTY(double wifiItemSize READ wifiItemSize WRITE setWifiItemSize NOTIFY wifiItemSizeChanged)
    Q_PROPERTY(double bluetoothPanelWidth READ bluetoothPanelWidth WRITE setBluetoothPanelWidth NOTIFY bluetoothPanelWidthChanged)
    Q_PROPERTY(double bluetoothItemMaxCount READ bluetoothItemMaxCount WRITE setBluetoothItemMaxCount NOTIFY bluetoothItemMaxCountChanged)
    Q_PROPERTY(double bluetoothItemSize READ bluetoothItemSize WRITE setBluetoothItemSize NOTIFY bluetoothItemSizeChanged)
    Q_PROPERTY(double brightnessPanelWidth READ brightnessPanelWidth WRITE setBrightnessPanelWidth NOTIFY brightnessPanelWidthChanged)
    Q_PROPERTY(double brightnessItemSize READ brightnessItemSize WRITE setBrightnessItemSize NOTIFY brightnessItemSizeChanged)
    Q_PROPERTY(double mediaPanelWidth READ mediaPanelWidth WRITE setMediaPanelWidth NOTIFY mediaPanelWidthChanged)
    Q_PROPERTY(double workspacePanelWidth READ workspacePanelWidth WRITE setWorkspacePanelWidth NOTIFY workspacePanelWidthChanged)
    Q_PROPERTY(double workspacePanelHeight READ workspacePanelHeight WRITE setWorkspacePanelHeight NOTIFY workspacePanelHeightChanged)
    Q_PROPERTY(double workspacePreviewWidth READ workspacePreviewWidth WRITE setWorkspacePreviewWidth NOTIFY workspacePreviewWidthChanged)
    Q_PROPERTY(double workspacePreviewHeight READ workspacePreviewHeight WRITE setWorkspacePreviewHeight NOTIFY workspacePreviewHeightChanged)
    Q_PROPERTY(double clockPanelWidth READ clockPanelWidth WRITE setClockPanelWidth NOTIFY clockPanelWidthChanged)
    Q_PROPERTY(double clockPanelHeight READ clockPanelHeight WRITE setClockPanelHeight NOTIFY clockPanelHeightChanged)
    Q_PROPERTY(double timerPanelWidth READ timerPanelWidth WRITE setTimerPanelWidth NOTIFY timerPanelWidthChanged)
    Q_PROPERTY(double trayMenuWidth READ trayMenuWidth WRITE setTrayMenuWidth NOTIFY trayMenuWidthChanged)
    Q_PROPERTY(double trayMenuItemHeight READ trayMenuItemHeight WRITE setTrayMenuItemHeight NOTIFY trayMenuItemHeightChanged)
    Q_PROPERTY(double launcherWidth READ launcherWidth WRITE setLauncherWidth NOTIFY launcherWidthChanged)
    Q_PROPERTY(double launcherPadding READ launcherPadding WRITE setLauncherPadding NOTIFY launcherPaddingChanged)
    Q_PROPERTY(double launcherSearchHeight READ launcherSearchHeight WRITE setLauncherSearchHeight NOTIFY launcherSearchHeightChanged)
    Q_PROPERTY(double launcherItemHeight READ launcherItemHeight WRITE setLauncherItemHeight NOTIFY launcherItemHeightChanged)
    Q_PROPERTY(double launcherIconSize READ launcherIconSize WRITE setLauncherIconSize NOTIFY launcherIconSizeChanged)
    Q_PROPERTY(double clipboardWidth READ clipboardWidth WRITE setClipboardWidth NOTIFY clipboardWidthChanged)
    Q_PROPERTY(double clipboardItemHeight READ clipboardItemHeight WRITE setClipboardItemHeight NOTIFY clipboardItemHeightChanged)
    Q_PROPERTY(double notificationPanelWidth READ notificationPanelWidth WRITE setNotificationPanelWidth NOTIFY notificationPanelWidthChanged)
    Q_PROPERTY(double notificationItemMaxCount READ notificationItemMaxCount WRITE setNotificationItemMaxCount NOTIFY notificationItemMaxCountChanged)
    Q_PROPERTY(double notificationPopupWidth READ notificationPopupWidth WRITE setNotificationPopupWidth NOTIFY notificationPopupWidthChanged)
    Q_PROPERTY(double notificationIconSize READ notificationIconSize WRITE setNotificationIconSize NOTIFY notificationIconSizeChanged)

    Q_PROPERTY(int labelFontSize READ labelFontSize WRITE setLabelFontSize NOTIFY labelFontSizeChanged)
    Q_PROPERTY(int iconFontSize READ iconFontSize WRITE setIconFontSize NOTIFY iconFontSizeChanged)
    Q_PROPERTY(int launcherSearchFontSize READ launcherSearchFontSize WRITE setLauncherSearchFontSize NOTIFY launcherSearchFontSizeChanged)
    Q_PROPERTY(int launcherMaxItems READ launcherMaxItems WRITE setLauncherMaxItems NOTIFY launcherMaxItemsChanged)
    Q_PROPERTY(int clipboardMaxItems READ clipboardMaxItems WRITE setClipboardMaxItems NOTIFY clipboardMaxItemsChanged)
    Q_PROPERTY(int clipboardMaxVisibleItems READ clipboardMaxVisibleItems WRITE setClipboardMaxVisibleItems NOTIFY clipboardMaxVisibleItemsChanged)
    Q_PROPERTY(int animationDuration READ animationDuration WRITE setAnimationDuration NOTIFY animationDurationChanged)
    Q_PROPERTY(int spatialDuration READ spatialDuration WRITE setSpatialDuration NOTIFY spatialDurationChanged)
    Q_PROPERTY(int fastSpatialDuration READ fastSpatialDuration WRITE setFastSpatialDuration NOTIFY fastSpatialDurationChanged)
    Q_PROPERTY(int slowSpatialDuration READ slowSpatialDuration WRITE setSlowSpatialDuration NOTIFY slowSpatialDurationChanged)
    Q_PROPERTY(int effectsDuration READ effectsDuration WRITE setEffectsDuration NOTIFY effectsDurationChanged)
    Q_PROPERTY(int fastEffectsDuration READ fastEffectsDuration WRITE setFastEffectsDuration NOTIFY fastEffectsDurationChanged)
    Q_PROPERTY(int mediaPlayerUpdateDuration READ mediaPlayerUpdateDuration WRITE setMediaPlayerUpdateDuration NOTIFY mediaPlayerUpdateDurationChanged)
    Q_PROPERTY(int networkUpdateInterval READ networkUpdateInterval WRITE setNetworkUpdateInterval NOTIFY networkUpdateIntervalChanged)
    Q_PROPERTY(int hoverDuration READ hoverDuration WRITE setHoverDuration NOTIFY hoverDurationChanged)
    Q_PROPERTY(int notificationPopupTimeout READ notificationPopupTimeout WRITE setNotificationPopupTimeout NOTIFY notificationPopupTimeoutChanged)
    Q_PROPERTY(int notificationMaxPopups READ notificationMaxPopups WRITE setNotificationMaxPopups NOTIFY notificationMaxPopupsChanged)
    Q_PROPERTY(int lowPowerThreshold READ lowPowerThreshold WRITE setLowPowerThreshold NOTIFY lowPowerThresholdChanged)
    Q_PROPERTY(int osdDuration READ osdDuration WRITE setOsdDuration NOTIFY osdDurationChanged)
    Q_PROPERTY(double osdBottomMargin READ osdBottomMargin WRITE setOsdBottomMargin NOTIFY osdBottomMarginChanged)
    Q_PROPERTY(QString osdMonitor READ osdMonitor WRITE setOsdMonitor NOTIFY osdMonitorChanged)

    // System monitor overlay
    Q_PROPERTY(bool overlayBackground READ overlayBackground WRITE setOverlayBackground NOTIFY overlayBackgroundChanged)
    Q_PROPERTY(bool overlayBorder READ overlayBorder WRITE setOverlayBorder NOTIFY overlayBorderChanged)
    Q_PROPERTY(QString overlayDisplayMode READ overlayDisplayMode WRITE setOverlayDisplayMode NOTIFY overlayDisplayModeChanged)
    Q_PROPERTY(QString overlayOrder READ overlayOrder WRITE setOverlayOrder NOTIFY overlayOrderChanged)
    Q_PROPERTY(bool overlayCpuEnabled READ overlayCpuEnabled WRITE setOverlayCpuEnabled NOTIFY overlayCpuEnabledChanged)
    Q_PROPERTY(bool overlayCpuLoad READ overlayCpuLoad WRITE setOverlayCpuLoad NOTIFY overlayCpuLoadChanged)
    Q_PROPERTY(bool overlayCpuTemp READ overlayCpuTemp WRITE setOverlayCpuTemp NOTIFY overlayCpuTempChanged)
    Q_PROPERTY(bool overlayGpuEnabled READ overlayGpuEnabled WRITE setOverlayGpuEnabled NOTIFY overlayGpuEnabledChanged)
    Q_PROPERTY(bool overlayGpuLoad READ overlayGpuLoad WRITE setOverlayGpuLoad NOTIFY overlayGpuLoadChanged)
    Q_PROPERTY(bool overlayGpuTemp READ overlayGpuTemp WRITE setOverlayGpuTemp NOTIFY overlayGpuTempChanged)
    Q_PROPERTY(bool overlayRamEnabled READ overlayRamEnabled WRITE setOverlayRamEnabled NOTIFY overlayRamEnabledChanged)
    Q_PROPERTY(bool overlayRamUsage READ overlayRamUsage WRITE setOverlayRamUsage NOTIFY overlayRamUsageChanged)

    Q_PROPERTY(bool launcherWebSearch READ launcherWebSearch WRITE setLauncherWebSearch NOTIFY launcherWebSearchChanged)
    Q_PROPERTY(bool launcherCalc READ launcherCalc WRITE setLauncherCalc NOTIFY launcherCalcChanged)
    Q_PROPERTY(bool launcherFuzzy READ launcherFuzzy WRITE setLauncherFuzzy NOTIFY launcherFuzzyChanged)
    Q_PROPERTY(bool launcherPowerActions READ launcherPowerActions WRITE setLauncherPowerActions NOTIFY launcherPowerActionsChanged)
    Q_PROPERTY(bool launcherWallpaperActions READ launcherWallpaperActions WRITE setLauncherWallpaperActions NOTIFY launcherWallpaperActionsChanged)
    Q_PROPERTY(bool launcherFileSearch READ launcherFileSearch WRITE setLauncherFileSearch NOTIFY launcherFileSearchChanged)
    Q_PROPERTY(bool launcherFolderSearch READ launcherFolderSearch WRITE setLauncherFolderSearch NOTIFY launcherFolderSearchChanged)
    Q_PROPERTY(bool launcherFileFuzzy READ launcherFileFuzzy WRITE setLauncherFileFuzzy NOTIFY launcherFileFuzzyChanged)
    Q_PROPERTY(bool launcherFolderFuzzy READ launcherFolderFuzzy WRITE setLauncherFolderFuzzy NOTIFY launcherFolderFuzzyChanged)
    Q_PROPERTY(bool launcherFullFilesystemSearch READ launcherFullFilesystemSearch WRITE setLauncherFullFilesystemSearch NOTIFY launcherFullFilesystemSearchChanged)
    Q_PROPERTY(QString launcherScopeKey READ launcherScopeKey WRITE setLauncherScopeKey NOTIFY launcherScopeKeyChanged)
    Q_PROPERTY(QString launcherFolderTerm READ launcherFolderTerm WRITE setLauncherFolderTerm NOTIFY launcherFolderTermChanged)
    Q_PROPERTY(bool clipboardFuzzy READ clipboardFuzzy WRITE setClipboardFuzzy NOTIFY clipboardFuzzyChanged)
    Q_PROPERTY(QString searchEngine READ searchEngine WRITE setSearchEngine NOTIFY searchEngineChanged)
    Q_PROPERTY(QString customSearchUrl READ customSearchUrl WRITE setCustomSearchUrl NOTIFY customSearchUrlChanged)
    Q_PROPERTY(QString searchUrl READ searchUrl NOTIFY searchUrlChanged)
    Q_PROPERTY(QString searchEngineLabel READ searchEngineLabel NOTIFY searchEngineLabelChanged)
    Q_PROPERTY(QString notificationPosition READ notificationPosition WRITE setNotificationPosition NOTIFY notificationPositionChanged)
    Q_PROPERTY(bool notificationShowCopyButton READ notificationShowCopyButton WRITE setNotificationShowCopyButton NOTIFY notificationShowCopyButtonChanged)

    Q_PROPERTY(bool moduleMediaPlayer READ moduleMediaPlayer WRITE setModuleMediaPlayer NOTIFY moduleMediaPlayerChanged)
    Q_PROPERTY(bool moduleNotifications READ moduleNotifications WRITE setModuleNotifications NOTIFY moduleNotificationsChanged)
    Q_PROPERTY(bool moduleSound READ moduleSound WRITE setModuleSound NOTIFY moduleSoundChanged)
    Q_PROPERTY(bool moduleWifi READ moduleWifi WRITE setModuleWifi NOTIFY moduleWifiChanged)
    Q_PROPERTY(bool moduleBluetooth READ moduleBluetooth WRITE setModuleBluetooth NOTIFY moduleBluetoothChanged)
    Q_PROPERTY(bool moduleBrightness READ moduleBrightness WRITE setModuleBrightness NOTIFY moduleBrightnessChanged)
    Q_PROPERTY(bool brightnessScreenOffAtMin READ brightnessScreenOffAtMin WRITE setBrightnessScreenOffAtMin NOTIFY brightnessScreenOffAtMinChanged)
    Q_PROPERTY(bool moduleDateTime READ moduleDateTime WRITE setModuleDateTime NOTIFY moduleDateTimeChanged)
    Q_PROPERTY(bool moduleWorkspaces READ moduleWorkspaces WRITE setModuleWorkspaces NOTIFY moduleWorkspacesChanged)
    Q_PROPERTY(bool moduleSysTray READ moduleSysTray WRITE setModuleSysTray NOTIFY moduleSysTrayChanged)

public:
    explicit Settings(QObject* parent = nullptr);

    QString panelBg() const;
    QString bgColor() const;
    QString bgColorFilled() const;
    QString hoveredBgColor() const;
    QString mutedBgColor() const;
    QString fgColor() const;
    QString mutedFgColor() const;
    QString altFgColor() const;
    QString accent() const;
    bool accentFromWallpaper() const;
    bool accentCycleEnabled() const;
    int accentCycleInterval() const;
    QString mutedAccent() const;
    QString battery() const;
    QString danger() const;
    QString dangerPulse() const;
    QString urgentPulseColor() const;
    QString iconFontFamily() const;
    QString labelFontFamily() const;
    void setPanelBg(const QString& v);
    void setBgColor(const QString& v);
    void setBgColorFilled(const QString& v);
    void setHoveredBgColor(const QString& v);
    void setMutedBgColor(const QString& v);
    void setFgColor(const QString& v);
    void setMutedFgColor(const QString& v);
    void setAltFgColor(const QString& v);
    void setAccent(const QString& v);
    void setAccentFromWallpaper(bool v);
    void setAccentCycleEnabled(bool v);
    void setAccentCycleInterval(int v);
    void setMutedAccent(const QString& v);
    void setBattery(const QString& v);
    void setDanger(const QString& v);
    void setDangerPulse(const QString& v);
    void setUrgentPulseColor(const QString& v);
    void setIconFontFamily(const QString& v);
    void setLabelFontFamily(const QString& v);

    double barHeight() const;
    double barHorizontalPad() const;
    double barVerticalPad() const;
    double cornerRadius() const;
    double cornerLargeRadius() const;
    int generalThickness() const;
    double dropdownOffset() const;
    double thumbnailSize() const;
    double dashboardWidth() const;
    double dashboardHeight() const;
    double soundPanelWidth() const;
    double soundItemMaxCount() const;
    double soundItemSize() const;
    double wifiPanelWidth() const;
    double wifiItemMaxCount() const;
    double wifiItemSize() const;
    double bluetoothPanelWidth() const;
    double bluetoothItemMaxCount() const;
    double bluetoothItemSize() const;
    double brightnessPanelWidth() const;
    double brightnessItemSize() const;
    double mediaPanelWidth() const;
    double workspacePanelWidth() const;
    double workspacePanelHeight() const;
    double workspacePreviewWidth() const;
    double workspacePreviewHeight() const;
    double clockPanelWidth() const;
    double clockPanelHeight() const;
    double timerPanelWidth() const;
    double trayMenuWidth() const;
    double trayMenuItemHeight() const;
    double launcherWidth() const;
    double launcherPadding() const;
    double launcherSearchHeight() const;
    double launcherItemHeight() const;
    double launcherIconSize() const;
    double clipboardWidth() const;
    double clipboardItemHeight() const;
    double notificationPanelWidth() const;
    double notificationItemMaxCount() const;
    double notificationPopupWidth() const;
    double notificationIconSize() const;
    void setBarHeight(double v);
    void setBarHorizontalPad(double v);
    void setBarVerticalPad(double v);
    void setCornerRadius(double v);
    void setCornerLargeRadius(double v);
    void setGeneralThickness(int v);
    void setDropdownOffset(double v);
    void setThumbnailSize(double v);
    void setDashboardWidth(double v);
    void setDashboardHeight(double v);
    void setSoundPanelWidth(double v);
    void setSoundItemMaxCount(double v);
    void setSoundItemSize(double v);
    void setWifiPanelWidth(double v);
    void setWifiItemMaxCount(double v);
    void setWifiItemSize(double v);
    void setBluetoothPanelWidth(double v);
    void setBluetoothItemMaxCount(double v);
    void setBluetoothItemSize(double v);
    void setBrightnessPanelWidth(double v);
    void setBrightnessItemSize(double v);
    void setMediaPanelWidth(double v);
    void setWorkspacePanelWidth(double v);
    void setWorkspacePanelHeight(double v);
    void setWorkspacePreviewWidth(double v);
    void setWorkspacePreviewHeight(double v);
    void setClockPanelWidth(double v);
    void setClockPanelHeight(double v);
    void setTimerPanelWidth(double v);
    void setTrayMenuWidth(double v);
    void setTrayMenuItemHeight(double v);
    void setLauncherWidth(double v);
    void setLauncherPadding(double v);
    void setLauncherSearchHeight(double v);
    void setLauncherItemHeight(double v);
    void setLauncherIconSize(double v);
    void setClipboardWidth(double v);
    void setClipboardItemHeight(double v);
    void setNotificationPanelWidth(double v);
    void setNotificationItemMaxCount(double v);
    void setNotificationPopupWidth(double v);
    void setNotificationIconSize(double v);

    int labelFontSize() const;
    int iconFontSize() const;
    int launcherSearchFontSize() const;
    int launcherMaxItems() const;
    int clipboardMaxItems() const;
    int clipboardMaxVisibleItems() const;
    int animationDuration() const;
    int spatialDuration() const;
    int fastSpatialDuration() const;
    int slowSpatialDuration() const;
    int effectsDuration() const;
    int fastEffectsDuration() const;
    int mediaPlayerUpdateDuration() const;
    int networkUpdateInterval() const;
    int hoverDuration() const;
    int notificationPopupTimeout() const;
    int notificationMaxPopups() const;
    int lowPowerThreshold() const;
    int osdDuration() const;
    double osdBottomMargin() const;
    QString osdMonitor() const;
    void setLabelFontSize(int v);
    void setIconFontSize(int v);
    void setLauncherSearchFontSize(int v);
    void setLauncherMaxItems(int v);
    void setClipboardMaxItems(int v);
    void setClipboardMaxVisibleItems(int v);
    void setAnimationDuration(int v);
    void setSpatialDuration(int v);
    void setFastSpatialDuration(int v);
    void setSlowSpatialDuration(int v);
    void setEffectsDuration(int v);
    void setFastEffectsDuration(int v);
    void setMediaPlayerUpdateDuration(int v);
    void setNetworkUpdateInterval(int v);
    void setHoverDuration(int v);
    void setNotificationPopupTimeout(int v);
    void setNotificationMaxPopups(int v);
    void setLowPowerThreshold(int v);
    void setOsdDuration(int v);
    void setOsdBottomMargin(double v);
    void setOsdMonitor(const QString& v);

    bool overlayBackground() const;
    bool overlayBorder() const;
    QString overlayDisplayMode() const;
    QString overlayOrder() const;
    bool overlayCpuEnabled() const;
    bool overlayCpuLoad() const;
    bool overlayCpuTemp() const;
    bool overlayGpuEnabled() const;
    bool overlayGpuLoad() const;
    bool overlayGpuTemp() const;
    bool overlayRamEnabled() const;
    bool overlayRamUsage() const;
    void setOverlayBackground(bool v);
    void setOverlayBorder(bool v);
    void setOverlayDisplayMode(const QString& v);
    void setOverlayOrder(const QString& v);
    void setOverlayCpuEnabled(bool v);
    void setOverlayCpuLoad(bool v);
    void setOverlayCpuTemp(bool v);
    void setOverlayGpuEnabled(bool v);
    void setOverlayGpuLoad(bool v);
    void setOverlayGpuTemp(bool v);
    void setOverlayRamEnabled(bool v);
    void setOverlayRamUsage(bool v);

    bool launcherWebSearch() const;
    bool launcherCalc() const;
    bool launcherFuzzy() const;
    bool launcherPowerActions() const;
    bool launcherWallpaperActions() const;
    bool launcherFileSearch() const;
    bool launcherFolderSearch() const;
    bool launcherFileFuzzy() const;
    bool launcherFolderFuzzy() const;
    bool launcherFullFilesystemSearch() const;
    QString launcherScopeKey() const;
    QString launcherFolderTerm() const;
    bool clipboardFuzzy() const;
    QString searchEngine() const;
    QString customSearchUrl() const;
    QString searchUrl() const;
    QString searchEngineLabel() const;
    QString notificationPosition() const;
    bool notificationShowCopyButton() const;
    void setLauncherWebSearch(bool v);
    void setLauncherCalc(bool v);
    void setLauncherFuzzy(bool v);
    void setLauncherPowerActions(bool v);
    void setLauncherWallpaperActions(bool v);
    void setLauncherFileSearch(bool v);
    void setLauncherFolderSearch(bool v);
    void setLauncherFileFuzzy(bool v);
    void setLauncherFolderFuzzy(bool v);
    void setLauncherFullFilesystemSearch(bool v);
    void setLauncherScopeKey(const QString& v);
    void setLauncherFolderTerm(const QString& v);
    void setClipboardFuzzy(bool v);
    void setSearchEngine(const QString& v);
    void setCustomSearchUrl(const QString& v);
    void setNotificationPosition(const QString& v);
    void setNotificationShowCopyButton(bool v);

    bool moduleMediaPlayer() const;
    bool moduleNotifications() const;
    bool moduleSound() const;
    bool moduleWifi() const;
    bool moduleBluetooth() const;
    bool moduleBrightness() const;
    bool brightnessScreenOffAtMin() const;
    bool moduleDateTime() const;
    bool moduleWorkspaces() const;
    bool moduleSysTray() const;
    void setModuleMediaPlayer(bool v);
    void setModuleNotifications(bool v);
    void setModuleSound(bool v);
    void setModuleWifi(bool v);
    void setModuleBluetooth(bool v);
    void setModuleBrightness(bool v);
    void setBrightnessScreenOffAtMin(bool v);
    void setModuleDateTime(bool v);
    void setModuleWorkspaces(bool v);
    void setModuleSysTray(bool v);

    Q_INVOKABLE QStringList searchEngineNames() const;
    Q_INVOKABLE QString searchEngineUrl(const QString& name) const;
    Q_INVOKABLE void resetTheme();
    Q_INVOKABLE void resetConfig();
    Q_INVOKABLE void resetAnimation();
    Q_INVOKABLE void resetLayout();
    Q_INVOKABLE void resetLauncher();
    Q_INVOKABLE void resetClipboard();
    Q_INVOKABLE void resetNotifications();
    Q_INVOKABLE void resetOsd();
    Q_INVOKABLE void resetOverlay();
    Q_INVOKABLE void resetModules();
    Q_INVOKABLE void resync();

    static bool webSearchEnabled();
    static bool calcEnabled();
    static bool fuzzyEnabled();
    static bool powerActionsEnabled();
    static bool wallpaperActionsEnabled();
    static bool fileSearchEnabled();
    static bool folderSearchEnabled();
    static bool fileFuzzyEnabled();
    static bool folderFuzzyEnabled();
    static bool fullFilesystemSearchEnabled();
    static bool clipboardFuzzyEnabled();
    static int clipboardMaxItemCount();
    static QString activeSearchName();
    static QString activeSearchUrl();
    static QString activeNotificationPosition();

signals:
    void panelBgChanged();
    void bgColorChanged();
    void bgColorFilledChanged();
    void hoveredBgColorChanged();
    void mutedBgColorChanged();
    void fgColorChanged();
    void mutedFgColorChanged();
    void altFgColorChanged();
    void accentChanged();
    void accentFromWallpaperChanged();
    void accentCycleEnabledChanged();
    void accentCycleIntervalChanged();
    void mutedAccentChanged();
    void batteryChanged();
    void dangerChanged();
    void dangerPulseChanged();
    void urgentPulseColorChanged();
    void iconFontFamilyChanged();
    void labelFontFamilyChanged();
    void barHeightChanged();
    void barHorizontalPadChanged();
    void barVerticalPadChanged();
    void cornerRadiusChanged();
    void cornerLargeRadiusChanged();
    void generalThicknessChanged();
    void dropdownOffsetChanged();
    void thumbnailSizeChanged();
    void dashboardWidthChanged();
    void dashboardHeightChanged();
    void soundPanelWidthChanged();
    void soundItemMaxCountChanged();
    void soundItemSizeChanged();
    void wifiPanelWidthChanged();
    void wifiItemMaxCountChanged();
    void wifiItemSizeChanged();
    void bluetoothPanelWidthChanged();
    void bluetoothItemMaxCountChanged();
    void bluetoothItemSizeChanged();
    void brightnessPanelWidthChanged();
    void brightnessItemSizeChanged();
    void mediaPanelWidthChanged();
    void workspacePanelWidthChanged();
    void workspacePanelHeightChanged();
    void workspacePreviewWidthChanged();
    void workspacePreviewHeightChanged();
    void clockPanelWidthChanged();
    void clockPanelHeightChanged();
    void timerPanelWidthChanged();
    void trayMenuWidthChanged();
    void trayMenuItemHeightChanged();
    void launcherWidthChanged();
    void launcherPaddingChanged();
    void launcherSearchHeightChanged();
    void launcherItemHeightChanged();
    void launcherIconSizeChanged();
    void clipboardWidthChanged();
    void clipboardItemHeightChanged();
    void notificationPanelWidthChanged();
    void notificationItemMaxCountChanged();
    void notificationPopupWidthChanged();
    void notificationIconSizeChanged();
    void labelFontSizeChanged();
    void iconFontSizeChanged();
    void launcherSearchFontSizeChanged();
    void launcherMaxItemsChanged();
    void clipboardMaxItemsChanged();
    void clipboardMaxVisibleItemsChanged();
    void animationDurationChanged();
    void spatialDurationChanged();
    void fastSpatialDurationChanged();
    void slowSpatialDurationChanged();
    void effectsDurationChanged();
    void fastEffectsDurationChanged();
    void mediaPlayerUpdateDurationChanged();
    void networkUpdateIntervalChanged();
    void hoverDurationChanged();
    void notificationPopupTimeoutChanged();
    void notificationMaxPopupsChanged();
    void lowPowerThresholdChanged();
    void osdDurationChanged();
    void osdBottomMarginChanged();
    void osdMonitorChanged();
    void overlayBackgroundChanged();
    void overlayBorderChanged();
    void overlayDisplayModeChanged();
    void overlayOrderChanged();
    void overlayCpuEnabledChanged();
    void overlayCpuLoadChanged();
    void overlayCpuTempChanged();
    void overlayGpuEnabledChanged();
    void overlayGpuLoadChanged();
    void overlayGpuTempChanged();
    void overlayRamEnabledChanged();
    void overlayRamUsageChanged();
    void launcherWebSearchChanged();
    void launcherCalcChanged();
    void launcherFuzzyChanged();
    void launcherPowerActionsChanged();
    void launcherWallpaperActionsChanged();
    void launcherFileSearchChanged();
    void launcherFolderSearchChanged();
    void launcherFileFuzzyChanged();
    void launcherFolderFuzzyChanged();
    void launcherFullFilesystemSearchChanged();
    void launcherScopeKeyChanged();
    void launcherFolderTermChanged();
    void clipboardFuzzyChanged();
    void searchEngineChanged();
    void customSearchUrlChanged();
    void searchUrlChanged();
    void searchEngineLabelChanged();
    void notificationPositionChanged();
    void notificationShowCopyButtonChanged();
    void moduleMediaPlayerChanged();
    void moduleNotificationsChanged();
    void moduleSoundChanged();
    void moduleWifiChanged();
    void moduleBluetoothChanged();
    void moduleBrightnessChanged();
    void brightnessScreenOffAtMinChanged();
    void moduleDateTimeChanged();
    void moduleWorkspacesChanged();
    void moduleSysTrayChanged();

private:
    QString getString(const QString& key, const QString& def) const;
    void setString(const QString& key, const QString& v, const QString& def);
    double getDouble(const QString& key, double def) const;
    void setDouble(const QString& key, double v, double def);
    int getInt(const QString& key, int def) const;
    void setInt(const QString& key, int v, int def);
    bool getBool(const QString& key, bool def) const;
    void setBool(const QString& key, bool v, bool def);
    void removeKeys(const QStringList& keys);

    mutable QSettings m_settings;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce;
    QVariantMap m_last;

    void scheduleResync();
    void onResyncTimeout();
    void watchConfig();
};

} // namespace peakshell
