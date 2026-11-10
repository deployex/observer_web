import * as echarts from "echarts"

// Mirrors the app's own Tailwind dark palette (dark:bg-gray-800 surfaces,
// dark:text-gray-200 text, dark:border-gray-600 borders, dark:bg-gray-700
// raised panels) so chart chrome matches the rest of the dark UI instead of
// echarts' built-in "dark" theme, which ships its own unrelated surface color.
const THEME_NAME = "observer-dark"

const TEXT = "#e5e7eb" // gray-200
const MUTED = "#9ca3af" // gray-400 - axis/legend labels
const LINE = "#4b5563" // gray-600 - axis lines, borders
const SPLIT = "#374151" // gray-700 - gridlines, tooltip/panel background

const axisCommon = () => ({
  axisLine: { lineStyle: { color: LINE } },
  axisTick: { lineStyle: { color: LINE } },
  axisLabel: { color: MUTED },
  splitLine: { lineStyle: { color: SPLIT } }
})

echarts.registerTheme(THEME_NAME, {
  backgroundColor: "transparent",
  textStyle: { color: TEXT },
  title: { textStyle: { color: TEXT }, subtextStyle: { color: MUTED } },
  legend: { textStyle: { color: TEXT } },
  tooltip: {
    backgroundColor: SPLIT,
    borderColor: LINE,
    textStyle: { color: TEXT }
  },
  toolbox: {
    iconStyle: { borderColor: MUTED },
    emphasis: { iconStyle: { borderColor: TEXT } }
  },
  categoryAxis: axisCommon(),
  valueAxis: axisCommon(),
  timeAxis: axisCommon(),
  logAxis: axisCommon()
})

// Matches the bg-white / dark:bg-gray-800 containers these charts sit in, for
// chart elements (like a tree node's label backdrop) that need to blend into
// the page rather than the chart's own surface.
const PAGE_SURFACE = { light: "#ffffff", dark: "#1f2937" }

// For label text drawn directly against that page surface (as opposed to
// inside the chart's own themed area, where the theme's `textStyle.color`
// already applies) - e.g. a tree node's label, whose backdrop follows
// `pageSurfaceColor()` above.
const PAGE_TEXT = { light: "#111827", dark: TEXT } // gray-900 / gray-200

export function isDarkMode() {
  return document.documentElement.classList.contains("dark")
}

export function pageSurfaceColor() {
  return isDarkMode() ? PAGE_SURFACE.dark : PAGE_SURFACE.light
}

export function pageTextColor() {
  return isDarkMode() ? PAGE_TEXT.dark : PAGE_TEXT.light
}

export function initChart(dom) {
  return echarts.init(dom, isDarkMode() ? THEME_NAME : null)
}

// Calls `callback(isDark)` whenever the `dark` class on <html> is toggled (the
// Themer hook flips it - see assets/js/hooks/themer.js), so a chart can
// re-theme itself live when the user changes the theme setting. Returns a
// disposer.
export function onThemeChange(callback) {
  const observer = new MutationObserver(() => callback(isDarkMode()))
  observer.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })

  return () => observer.disconnect()
}
