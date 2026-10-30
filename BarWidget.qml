import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.michaelsucks.pastel-stats"

  readonly property int interval: setting("interval", 2)
  // Each value is the script's raw field; "-" means it isn't readable on this machine.
  property string cpu: "-"
  property string cpuWatts: "-"
  property string gpu: "-"
  property string gpuWatts: "-"
  property string cpuTemp: "-"
  property string gpuTemp: "-"
  readonly property bool hasGpu: gpu !== "-" || gpuTemp !== "-"
  readonly property bool hasWatts: cpuWatts !== "-" || gpuWatts !== "-"
  readonly property int totalWatts: (cpuWatts !== "-" ? parseInt(cpuWatts) : 0) + (gpuWatts !== "-" ? parseInt(gpuWatts) : 0)
  property bool ready: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function parse(line) {
    var f = line.trim().split(/\s+/)
    if (f.length < 6) return
    cpu = f[0]
    cpuWatts = f[1]
    gpu = f[2]
    gpuWatts = f[3]
    cpuTemp = f[4]
    gpuTemp = f[5]
    ready = true
  }

  Process {
    id: stats
    running: true
    command: [Qt.resolvedUrl("pastel-stats").toString().replace("file://", ""), String(root.interval)]
    stdout: SplitParser { onRead: function(line) { root.parse(line) } }
    onExited: restartTimer.start()
  }

  Timer {
    id: restartTimer
    interval: 5000
    onTriggered: stats.running = true
  }

  // Pastel scale: green, yellow, peach, pink-red as a value crosses each threshold.
  readonly property var pastels: ["#a6e3a1", "#f9e2af", "#fab387", "#f38ba8"]

  function tint(value, warm, hot, critical) {
    var v = parseInt(value)
    if (isNaN(v)) return pastels[0]
    return pastels[v >= critical ? 3 : v >= hot ? 2 : v >= warm ? 1 : 0]
  }

  function paint(text, color) {
    return "<font color='" + color + "'>" + text + "</font>"
  }

  // Builds the label as a list of segments so unreadable values drop out cleanly.
  function segments(colored) {
    function part(text, color) { return colored ? paint(text, color) : text }
    var cpuPart = "CPU " + part(cpu + "%", tint(cpu, 50, 80, 90))
    if (cpuTemp !== "-") cpuPart += " " + part(cpuTemp + "°", tint(cpuTemp, setting("cpuTempWarm", 70), setting("cpuTempHot", 85), setting("cpuTempCritical", 95)))
    var out = [cpuPart]
    if (hasGpu) {
      var gpuPart = "GPU"
      if (gpu !== "-") gpuPart += " " + part(gpu + "%", tint(gpu, 50, 80, 90))
      if (gpuTemp !== "-") gpuPart += " " + part(gpuTemp + "°", tint(gpuTemp, setting("gpuTempWarm", 60), setting("gpuTempHot", 75), setting("gpuTempCritical", 83)))
      out.push(gpuPart)
    }
    if (hasWatts) out.push(part(totalWatts + "W", tint(totalWatts, 150, 300, 450)))
    return out.join(" · ")
  }

  function tooltipLine(name, usage, watts, temp) {
    var parts = [name, usage + "%"]
    if (watts !== "-") parts.push(watts + "W")
    if (temp !== "-") parts.push(temp + "°C")
    return parts.join("  ")
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Plain text keeps the button visible and sized; the colored label below is what gets drawn.
    text: !root.ready || root.vertical ? "" : root.segments(false)
    labelVisible: false
    horizontalMargin: 8.75
    verticalPadding: 8.75
    // Even width keeps the centered label on whole pixels so it renders as crisp as the clock.
    fixedWidth: root.vertical ? -1 : Math.ceil(coloredLabel.implicitWidth / 2) * 2 + Math.round(Style.spaceReal(8.75)) * 2
    tooltipText: root.tooltipLine("CPU", root.cpu, root.cpuWatts, root.cpuTemp)
      + (root.hasGpu ? "\n" + root.tooltipLine("GPU", root.gpu, root.gpuWatts, root.gpuTemp) : "")
      + (root.cpuWatts === "-" ? "\n(CPU wattage unavailable)" : "")

    onPressed: function(b) {
      if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
    }
  }

  Text {
    id: coloredLabel
    anchors.centerIn: parent
    visible: button.text !== ""
    textFormat: Text.StyledText
    text: root.ready ? root.segments(true) : ""
    color: button.foreground
    font.family: button.fontFamily
    font.pixelSize: button.fontSize
    renderType: Text.NativeRendering
  }
}
