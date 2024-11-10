import * as echarts from "echarts";

let chart;

export default {
  mounted() {
    chart = echarts.init(this.el);
    chart.setOption({
      xAxis: {
        type: "time",
      },
      yAxis: [
        {
          type: "value",
        },
        {
          type: "value",
        },
      ],
      tooltip: {
        trigger: "axis",
        axisPointer: {
          type: "cross",
          animation: false,
          label: {
            backgroundColor: "#ccc",
            borderColor: "#aaa",
            borderWidth: 1,
            shadowBlur: 0,
            shadowOffsetX: 0,
            shadowOffsetY: 0,
            color: "#222",
          },
        },
      },
      series: [
        {
          name: "Average Sentiment",
          data: [],
          type: "line",
          yAxisIndex: 0,
          smooth: true,
          markLine: {
            show: true,
            data: [
              {
                name: "average line",
                type: "average",
              },
            ],
            lineStyle: {
              color: "red",
            },
          },
        },
        {
          name: "Post Count",
          data: [],
          type: "line",
          yAxisIndex: 1,
          smooth: true,
          markLine: {
            show: true,
            data: [
              {
                name: "average line",
                type: "average",
              },
            ],
            lineStyle: {
              color: "orange",
            },
          },
        },
      ],
    });

    this.handleEvent("datapoints", function (data) {
      const items = data.items.sort(
        (a, b) => new Date(a.inserted_at) - new Date(b.inserted_at),
      );
      const newAverages = items.map((datapoint) => [
        datapoint.inserted_at,
        datapoint.average,
      ]);

      const newCounts = items.map((datapoint) => [
        datapoint.inserted_at,
        datapoint.count,
      ]);

      const currentOption = chart.getOption();
      const currentAverages = currentOption.series[0].data || [];
      const currentCounts = currentOption.series[1].data || [];

      chart.setOption({
        series: [
          {
            name: "Average Sentiment",
            data: [...currentAverages, ...newAverages],
          },
          {
            name: "Post Count",
            data: [...currentCounts, ...newCounts],
          },
        ],
      });
    });

    this.handleEvent("averages", function (data) {
      const items = data.items.sort(
        (a, b) => new Date(a.inserted_at) - new Date(b.inserted_at),
      );

      const newAverages = items.map((datapoint) => [
        datapoint.inserted_at,
        datapoint.average,
      ]);

      const currentOption = chart.getOption();
      const currentAverages = currentOption.series[0].data || [];

      chart.setOption({
        series: [
          {
            name: "Average Sentiment",
            data: [...currentAverages, ...newAverages],
          },
        ],
      });
    });

    this.handleEvent("reset-datapoints", function () {
      chart.setOption({
        series: [
          {
            name: "Average Sentiment",
            data: [],
          },
          {
            name: "Post Count",
            data: [],
          },
        ],
      });
    });

    this.handleEvent("reset-averages", function () {
      chart.setOption({
        series: [
          {
            name: "Average Sentiment",
            data: [],
          },
          {
            name: "Post Count",
            data: [],
          },
        ],
      });
    });
  },
};
