import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root

    property var panelHost
    //screen: panelHost ? panelHost.screen : null

    // View modes: 0 = Weeks, 1 = Months (default), 2 = Years
    property int currentView: 1
    property date today: new Date()
    property date viewDate: new Date()
    property date selectedDate: new Date()

    readonly property int currMonth: viewDate.getMonth()
    readonly property int currYear: viewDate.getFullYear()

    // Slide animation properties for date transitions
    property int animDirection: 1
    property real animTranslate: 0
    property real animOpacity: 1

    function openPanel() {
        today = new Date();
        viewDate = new Date();
        selectedDate = new Date();
        currentView = 1;
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("calendar");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["calendar"] = root;
    }

    function closePanel() {
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["calendar"] = false;
    }

    function togglePanel() {
        if (visible)
            closePanel();
        else
            openPanel();
    }

    function jumpToday() {
        today = new Date();
        selectedDate = new Date();
        animateToDate(new Date());
    }

    function animateToDate(newDate) {
        animDirection = newDate >= viewDate ? 1 : -1;
        animOpacity = 0;
        animTranslate = animDirection * 30;
        viewDate = newDate;
        contentAnim.restart();
    }

    function navigatePrev() {
        if (currentView === 0) {
            // Prev week
            const d = new Date(viewDate.getTime());
            d.setDate(d.getDate() - 7);
            animateToDate(d);
        } else if (currentView === 1) {
            // Prev month
            animateToDate(new Date(currYear, currMonth - 1, 1));
        } else {
            // Prev year
            animateToDate(new Date(currYear - 1, currMonth, 1));
        }
    }

    function navigateNext() {
        if (currentView === 0) {
            // Next week
            const d = new Date(viewDate.getTime());
            d.setDate(d.getDate() + 7);
            animateToDate(d);
        } else if (currentView === 1) {
            // Next month
            animateToDate(new Date(currYear, currMonth + 1, 1));
        } else {
            // Next year
            animateToDate(new Date(currYear + 1, currMonth, 1));
        }
    }

    function getWeekStart(d) {
        const date = new Date(d.getTime());
        const day = date.getDay();
        // Sunday = 0, so adjust so Monday is first day (or Sunday depending on locale)
        const diff = date.getDate() - day + (day === 0 ? -6 : 1);
        return new Date(date.setDate(diff));
    }

    function isSameDay(d1, d2) {
        if (!d1 || !d2)
            return false;
        return d1.getFullYear() === d2.getFullYear() && d1.getMonth() === d2.getMonth() && d1.getDate() === d2.getDate();
    }

    function getMonthName(monthIdx) {
        const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        return months[monthIdx];
    }

    function getShortMonthName(monthIdx) {
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return months[monthIdx];
    }

    ParallelAnimation {
        id: contentAnim
        Anim {
            target: root
            property: "animTranslate"
            to: 0
            type: Anim.DefaultSpatial
        }
        Anim {
            target: root
            property: "animOpacity"
            to: 1
            type: Anim.DefaultEffects
        }
    }

    visible: false
    focusable: true
    color: "transparent"
    implicitWidth: Screen.desktopAvailableWidth
    implicitHeight: Screen.desktopAvailableHeight

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Dismiss on clicking outside
    MouseArea {
        anchors.fill: parent
        onClicked: root.closePanel()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closePanel();
                event.accepted = true;
            }
        }
    }

    Rectangle {
        id: card
        width: Theme.clockPanelWidth
        height: Theme.clockPanelHeight
        anchors.right: parent.right
        anchors.rightMargin: Theme.barHorizontalPad
        y: Theme.dropdownOffset * 2 // yuh

        color: Theme.bgColor
        border.color: Theme.mutedAccent
        border.width: Theme.generalThickness
        radius: Theme.cornerLargeRadius
        clip: true

        // Prevent dismissal on clicking within card
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Scroll / trackpad gesture navigation
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const isCtrl = event.modifiers & Qt.ControlModifier;
                if (isCtrl) {
                    // Ctrl + scroll: cycle through view modes
                    // Scroll up (positive y) = go to narrower view (Year→Month→Week)
                    // Scroll down (negative y) = go to wider view (Week→Month→Year)
                    if (event.angleDelta.y > 0) {
                        root.currentView = (root.currentView + 2) % 3;  // go back in order
                    } else {
                        root.currentView = (root.currentView + 1) % 3;  // go forward in order
                    }
                } else {
                    // Plain scroll: navigate prev/next period
                    if (event.angleDelta.y > 0)
                        root.navigatePrev();
                    else
                        root.navigateNext();
                }
                event.accepted = true;
            }
        }

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94
        transformOrigin: Item.TopRight

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Top Header: Navigation & View Mode Pills
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // View Mode Segmented Selector (Weeks | Months | Years)
                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 210
                    radius: Theme.cornerRadius
                    color: Theme.mutedBgColor

                    RowLayout {
                        anchors.fill: parent
                        spacing: 2

                        Repeater {
                            model: [
                                {
                                    label: "Week",
                                    mode: 0
                                },
                                {
                                    label: "Month",
                                    mode: 1
                                },
                                {
                                    label: "Year",
                                    mode: 2
                                }
                            ]

                            delegate: Rectangle {
                                id: segBtn
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.cornerRadius

                                color: root.currentView === segBtn.modelData.mode ? Theme.accent : "transparent"
                                Behavior on color {
                                    CAnim {}
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentView = segBtn.modelData.mode;
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: segBtn.modelData.label
                                    color: root.currentView === segBtn.modelData.mode ? Theme.fgColor : Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize
                                    font.family: Theme.labelFontFamily
                                    font.bold: root.currentView === segBtn.modelData.mode
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Today Button
                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: todayTxt.implicitWidth + 16
                    radius: Theme.cornerRadius
                    color: Theme.mutedBgColor

                    Behavior on color {
                        CAnim {}
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.jumpToday()
                    }

                    Text {
                        id: todayTxt
                        anchors.centerIn: parent
                        text: "Today"
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize * 0.95
                        font.family: Theme.labelFontFamily
                    }
                }

                // Close Button
                ClickButton {
                    symbol: "window-close"
                    size: 28
                    onPress: root.closePanel()
                }
            }

            // Period Title & Arrow Controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ClickButton {
                    symbol: "go-previous"
                    size: 28
                    onPress: root.navigatePrev()
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.cornerRadius
                    color: titleMouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"

                    Behavior on color {
                        CAnim {}
                    }

                    MouseArea {
                        id: titleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Cycle views: Week -> Month -> Year -> Week
                            if (root.currentView === 0)
                                root.currentView = 1;
                            else if (root.currentView === 1)
                                root.currentView = 2;
                            else
                                root.currentView = 0;
                        }
                    }

                    Text {
                        id: periodTitle
                        anchors.centerIn: parent
                        opacity: root.animOpacity
                        transform: Translate {
                            x: root.animTranslate
                        }

                        text: {
                            if (root.currentView === 0) {
                                const start = root.getWeekStart(root.viewDate);
                                const end = new Date(start.getTime());
                                end.setDate(end.getDate() + 6);
                                return root.getShortMonthName(start.getMonth()) + " " + start.getDate() + " - " + root.getShortMonthName(end.getMonth()) + " " + end.getDate() + ", " + end.getFullYear();
                            } else if (root.currentView === 1) {
                                return root.getMonthName(root.currMonth) + " " + root.currYear;
                            } else {
                                return String(root.currYear);
                            }
                        }
                        color: Theme.fgColor
                        font.pointSize: Theme.labelFontSize * 1.2
                        font.family: Theme.labelFontFamily
                        font.bold: true
                    }
                }

                ClickButton {
                    symbol: "go-next"
                    size: 28
                    onPress: root.navigateNext()
                }
            }

            // Main Content Area with Views
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ================= MONTH VIEW (DEFAULT) =================
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.currentView === 1
                    opacity: root.currentView === 1 ? root.animOpacity : 0
                    transform: Translate {
                        x: root.currentView === 1 ? root.animTranslate : 0
                    }
                    spacing: 4

                    DayOfWeekRow {
                        Layout.fillWidth: true
                        locale: Qt.locale()

                        delegate: Text {
                            required property var model
                            horizontalAlignment: Text.AlignHCenter
                            text: model.shortName
                            font.pointSize: Theme.labelFontSize * 0.95
                            font.family: Theme.labelFontFamily
                            font.bold: true
                            color: (model.day === 0 || model.day === 6) ? Theme.mutedAccent : Theme.mutedFgColor
                        }
                    }

                    MonthGrid {
                        id: monthGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        month: root.currMonth
                        year: root.currYear
                        spacing: 2
                        locale: Qt.locale()

                        delegate: Rectangle {
                            id: dayCell
                            required property var model

                            radius: Theme.cornerRadius
                            color: {
                                if (dayCell.model.today)
                                    return Theme.accent;
                                if (root.isSameDay(dayCell.model.date, root.selectedDate))
                                    return Theme.hoveredBgColor;
                                if (cellMouse.containsMouse)
                                    return Theme.mutedBgColor;
                                return "transparent";
                            }

                            border.color: root.isSameDay(dayCell.model.date, root.selectedDate) && !dayCell.model.today ? Theme.accent : "transparent"
                            border.width: 1

                            Behavior on color {
                                CAnim {}
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedDate = dayCell.model.date;
                                    if (dayCell.model.month !== root.currMonth) {
                                        root.animateToDate(new Date(dayCell.model.year, dayCell.model.month, dayCell.model.day));
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: String(dayCell.model.day)
                                color: {
                                    if (dayCell.model.today)
                                        return Theme.fgColor;
                                    if (dayCell.model.month === root.currMonth)
                                        return Theme.fgColor;
                                    return Theme.mutedFgColor;
                                }
                                opacity: dayCell.model.month === root.currMonth ? 1.0 : 0.35
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                                font.bold: dayCell.model.today || root.isSameDay(dayCell.model.date, root.selectedDate)
                            }
                        }
                    }
                }

                // ================= WEEK VIEW =================
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.currentView === 0
                    opacity: root.currentView === 0 ? root.animOpacity : 0
                    transform: Translate {
                        x: root.currentView === 0 ? root.animTranslate : 0
                    }
                    spacing: 6

                    Repeater {
                        model: 7

                        delegate: Rectangle {
                            id: weekRow
                            required property int index

                            readonly property date rowDate: {
                                const start = root.getWeekStart(root.viewDate);
                                const d = new Date(start.getTime());
                                d.setDate(d.getDate() + weekRow.index);
                                return d;
                            }
                            readonly property bool isDayToday: root.isSameDay(rowDate, root.today)
                            readonly property bool isDaySelected: root.isSameDay(rowDate, root.selectedDate)

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.cornerRadius

                            color: {
                                if (isDayToday)
                                    return Theme.hoveredBgColor;
                                if (isDaySelected)
                                    return Theme.mutedBgColor;
                                if (weekMouse.containsMouse)
                                    return Theme.mutedBgColor;
                                return "transparent";
                            }

                            border.color: isDayToday ? Theme.accent : (isDaySelected ? Theme.mutedAccent : "transparent")
                            border.width: 1

                            Behavior on color {
                                CAnim {}
                            }

                            MouseArea {
                                id: weekMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedDate = weekRow.rowDate;
                                    root.viewDate = weekRow.rowDate;
                                    root.currentView = 1; // Smooth zoom into Month view on day click
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Rectangle {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    radius: 16
                                    color: weekRow.isDayToday ? Theme.accent : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: String(weekRow.rowDate.getDate())
                                        color: Theme.fgColor
                                        font.pointSize: Theme.labelFontSize
                                        font.family: Theme.labelFontFamily
                                        font.bold: weekRow.isDayToday
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 50
                                    text: Qt.formatDate(weekRow.rowDate, "ddd")
                                    color: (weekRow.rowDate.getDay() === 0 || weekRow.rowDate.getDay() === 6) ? Theme.mutedAccent : Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize
                                    font.family: Theme.labelFontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: Qt.formatDate(weekRow.rowDate, "MMMM d, yyyy")
                                    color: Theme.fgColor
                                    font.pointSize: Theme.labelFontSize * 0.95
                                    font.family: Theme.labelFontFamily
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: weekRow.isDayToday
                                    text: "Today"
                                    color: Theme.accent
                                    font.pointSize: Theme.labelFontSize * 0.85
                                    font.family: Theme.labelFontFamily
                                    font.bold: true
                                }
                            }
                        }
                    }
                }

                // ================= YEAR VIEW =================
                GridLayout {
                    anchors.fill: parent
                    visible: root.currentView === 2
                    opacity: root.currentView === 2 ? root.animOpacity : 0
                    transform: Translate {
                        x: root.currentView === 2 ? root.animTranslate : 0
                    }
                    columns: 3
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: 12

                        delegate: Rectangle {
                            id: monthCell
                            required property int index

                            readonly property bool isCurrentMonth: monthCell.index === root.today.getMonth() && root.currYear === root.today.getFullYear()
                            readonly property bool isSelectedMonth: monthCell.index === root.currMonth

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.cornerRadius

                            color: {
                                if (isSelectedMonth)
                                    return Theme.accent;
                                if (monthMouse.containsMouse)
                                    return Theme.hoveredBgColor;
                                return Theme.mutedBgColor;
                            }

                            border.color: isCurrentMonth && !isSelectedMonth ? Theme.accent : "transparent"
                            border.width: 1

                            Behavior on color {
                                CAnim {}
                            }

                            MouseArea {
                                id: monthMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.animateToDate(new Date(root.currYear, monthCell.index, 1));
                                    root.currentView = 1; // Zoom into selected month
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.getShortMonthName(monthCell.index)
                                    color: Theme.fgColor
                                    font.pointSize: Theme.labelFontSize * 1.15
                                    font.family: Theme.labelFontFamily
                                    font.bold: true
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.getMonthName(monthCell.index)
                                    color: isSelectedMonth ? Theme.fgColor : Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize * 0.8
                                    font.family: Theme.labelFontFamily
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Status Row: Current Time & Date summary
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Qt.formatDateTime(root.today, "dddd, MMMM d")
                    color: Theme.mutedFgColor
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Time.hourStr + ":" + Time.minuteStr + " " + Time.amPmStr
                    color: Theme.fgColor
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                    font.bold: true
                }
            }
        }
    }
}
