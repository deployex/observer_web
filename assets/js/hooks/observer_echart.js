import * as echarts from "echarts"

// Hovering fires the tooltip formatter on every mousemove, so wait for the
// pointer to settle on a node before requesting its details from the server.
const TOOLTIP_DEBOUNCE_MS = 200

const ObserverEChart = {
  mounted() {
    const selector = "#" + this.el.id

    this.chart = echarts.init(this.el.querySelector(selector + "-chart"))
    const option = JSON.parse(this.el.querySelector(selector + "-data").textContent)

    this.setChartOption(option)
    this.guardWheelZoom()
  },
  // The tree series has `roam: "zoom"`, which binds the mouse wheel to
  // chart zoom. That steals the wheel event from the page, so scrolling
  // past the chart instead zooms it in and out. Capture the wheel event
  // above the chart and stop it from reaching echarts' own listener
  // unless a modifier key is held, so a plain scroll passes through to
  // the page and only a deliberate ctrl/cmd+scroll zooms the chart.
  guardWheelZoom() {
    this.onWheel = (event) => {
      if (!event.ctrlKey && !event.metaKey) event.stopPropagation()
    }
    this.el.addEventListener("wheel", this.onWheel, { capture: true, passive: true })
  },
  updated() {
    const selector = "#" + this.el.id
    // This flag will indicate to Echart to not merge the data
    const notMerge = !this.el.dataset.merge ?? true

    const newOption = JSON.parse(this.el.querySelector(selector + "-data").textContent)

    // Compare the new option series with the previous one
    if (this.previousSeries && JSON.stringify(this.previousSeries) === JSON.stringify(newOption.series)) {
      // If the data is the same, skip the update
      return
    }

    // Save the new option as the previous one for future comparisons
    this.previousSeries = newOption.series

    this.setChartOption(newOption, notMerge)
  },
  destroyed() {
    clearTimeout(this.tooltipTimer)
    this.el.removeEventListener("wheel", this.onWheel, { capture: true })
  },
  setChartOption(option, notMerge) {
    const formatter = (args) => {
      const id = args.data.id
      const seriesName = args.seriesName

      clearTimeout(this.tooltipTimer)
      this.tooltipTimer = setTimeout(() => {
        this.pushEventTo(this.el, "request-process", { id: id, series_name: seriesName })
      }, TOOLTIP_DEBOUNCE_MS)

      return id
    }

    option.tooltip = { ...option.tooltip, formatter: formatter }

    this.chart.setOption(option, notMerge)
  }
};

export default ObserverEChart
