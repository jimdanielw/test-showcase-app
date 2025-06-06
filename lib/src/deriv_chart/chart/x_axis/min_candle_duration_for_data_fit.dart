import 'x_axis_model.dart';

/// Minimum candle duration with which [entriesDuration] can fit into available
/// width in data fit mode.
///
/// This function is meant for external usage, to choose initial granularity for
/// contract details.
///
/// Default scale is used.
/// Default scale means each interval (in other words candle) is
/// [XAxisModel.defaultIntervalWidth] pixels in width.
///
/// [entriesDuration] is a total duration of all entries.
/// [chartWidth] is pixel width of the chart widget.
/// [chartDefaultIntervalWidth] is the default interval width in pixels for the
/// The chart also should be set to have this default value on its first build
/// after changing interval. can be customized in chart as well using
/// [ChartAxisConfig].
Duration minCandleDurationForDataFit(
  Duration entriesDuration,
  double chartWidth,
  double chartDefaultIntervalWidth,
) {
  final double availableWidth = chartWidth - defaultDataFitPadding.horizontal;
  final double msPerPx = entriesDuration.inMilliseconds / availableWidth;
  return Duration(
    milliseconds: (msPerPx * chartDefaultIntervalWidth).ceil(),
  );
}
