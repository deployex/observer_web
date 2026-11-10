import { initChart, onThemeChange, themeSeriesSymbol } from "../lib/echarts_theme"

// echarts' default line-series symbol always fills with a hardcoded white
// center - fine on a light page, a stark white dot on the dark surface.
// themeSeriesSymbol swaps it for a solid circle in dark mode (see its
// definition), recomputed fresh each time against whichever theme is
// current, so this.currentOption itself stays a plain, theme-independent
// record of the data (same reasoning as the comment below).
const themedSeries = (series) => series.map(themeSeriesSymbol)

const LiveMetricsEChart = {
  mounted() {
    const selector = "#" + this.el.id

    const dataConfig = JSON.parse(this.el.dataset.config)
    const columns = JSON.parse(this.el.dataset.columns)

    this.dom = this.el.querySelector(selector + "-chart")
    // Our own record of the option in force, kept as plain (unresolved) values -
    // unlike `chart.getOption()`, which bakes in the *resolved* colors of
    // whichever theme was active when it ran, and would silently re-pin the old
    // theme's colors if replayed after a theme switch.
    this.currentOption = dataConfig
    this.chart = initChart(this.dom)
    this.chart.setOption({ ...this.currentOption, series: themedSeries(this.currentOption.series) })
    this.graph_cols = columns

    // echarts binds its theme at init time, so following a theme change means
    // disposing and re-initializing the chart, then re-applying our own record
    // of the option (including the data accumulated so far) to it.
    this.disposeThemeWatcher = onThemeChange(() => {
      this.chart.dispose()
      this.chart = initChart(this.dom)
      this.chart.setOption({ ...this.currentOption, series: themedSeries(this.currentOption.series) })
    })
  },
  updated() {
    const dataConfig = JSON.parse(this.el.dataset.config)
    const reset = JSON.parse(this.el.dataset.reset)
    const columns = JSON.parse(this.el.dataset.columns)

    if (reset) {
      this.currentOption = dataConfig
      this.chart.setOption({ ...this.currentOption, series: themedSeries(this.currentOption.series) })
    } else {
      const updatedXAxisData = this.currentOption.xAxis.data.concat(dataConfig.xAxis.data)
      const updatedSeries = this.currentOption.series.map((series, index) => ({
        ...series,
        // Concatenate the corresponding dataset to each series
        data: series.data.concat(dataConfig.series[index] ? dataConfig.series[index].data : [])
      }))

      this.currentOption = {
        ...this.currentOption,
        xAxis: { ...this.currentOption.xAxis, data: updatedXAxisData },
        series: updatedSeries
      }

      this.chart.setOption({ xAxis: { data: updatedXAxisData }, series: themedSeries(updatedSeries) })
    }
    if (columns != this.columns) {
      this.chart.resize()
      this.columns = columns
    }
  },
  destroyed() {
    this.disposeThemeWatcher()
    this.chart.dispose()
  }
};

export default LiveMetricsEChart
