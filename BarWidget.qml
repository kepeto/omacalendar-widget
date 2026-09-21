pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "CalendarModel.js" as Model

BarWidget {
  id: root
  moduleName: "org.omacalendar.widget"

  // LC_TIME can differ from LANG (for example LANG=en_US with LC_TIME=id_ID).
  // Build the formatter from LC_TIME explicitly so the shell does not fall back to English.
  readonly property string localeName: String(Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || "C")
  readonly property var activeLocale: Qt.locale(localeName)
  property date now: new Date()
  readonly property string privacy: String(setting("barPrivacy", "full"))
  readonly property string configuredFormat: vertical
    ? String(setting("verticalFormat", "HH\n—\nmm"))
    : String(setting("format", "ddd HH:mm"))
  readonly property bool showUpNext: setting("showUpNext", true) === true
  readonly property bool showCountdown: setting("showCountdown", true) === true
  readonly property var client: panelLoader.item ? panelLoader.item.client : null
  readonly property var rawUpNext: client && client.snapshot ? client.snapshot.upNext : null
  readonly property var allEvents: client && client.snapshot && Array.isArray(client.snapshot.events)
    ? client.snapshot.events : []
  readonly property var upNext: Model.barEvent(allEvents, now,
    24 * 60 * 60 * 1000, 2 * 60 * 60 * 1000, 5 * 60 * 1000,
    2 * 60 * 60 * 1000)
  readonly property string shortEventTitle: Model.truncateText(Model.eventTitle(upNext), 25)
  // Use Locale.toString(date, pattern) rather than Qt.formatDateTime(date, pattern),
  // because this lets LC_TIME override a different process UI language.
  readonly property string timeText: activeLocale.toString(now, configuredFormat)
  readonly property string eventTitle: privacy === "hidden" || !upNext ? "" : shortEventTitle
  readonly property string countdown: showCountdown && upNext ? Model.upNextLabel(upNext, now) : ""
  readonly property string meetingUrl: Model.meetingUrl(upNext)
  readonly property string horizontalText: {
    var values = [timeText]
    if (showUpNext && eventTitle) values.push(eventTitle)
    if (showUpNext && countdown) values.push(countdown)
    return values.join("  ·  ")
  }
  readonly property var verticalLines: timeText.split("\n")

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function cycleFormat() {
    var formats = vertical
      ? ["HH\n—\nmm", "dd\nMMM\nHH:mm", "ddd\ndd\nMMM"]
      : ["ddd HH:mm", "dddd d MMM HH:mm", "d MMMM yyyy · HH:mm", "HH:mm"]
    var current = String(configuredFormat)
    var index = formats.indexOf(current)
    var next = formats[(index + 1 + formats.length) % formats.length]
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry[vertical ? "verticalFormat" : "format"] = next
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function refresh() { if (panelLoader.item) panelLoader.item.refresh() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.now = date
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.horizontalText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.upNext
      ? (root.privacy === "hidden" ? (root.countdown || "Upcoming event") : root.shortEventTitle)
      : "Click: calendar · Right-click: format · Middle-click: refresh"
    active: false
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText

    onPressed: function(button) {
      if (button === Qt.RightButton) root.cycleFormat()
      else if (button === Qt.MiddleButton) root.refresh()
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines
        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3 ? button.fontSize * 0.9 : button.fontSize
          color: button.foreground
        }
      }
    }

    Rectangle {
      visible: !root.vertical && root.meetingUrl !== ""
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.top: parent.top
      anchors.topMargin: Style.space(4)
      width: Style.space(5)
      height: width
      radius: width / 2
      color: Color.accent
    }
  }
}
