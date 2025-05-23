import 'package:deriv_chart/src/deriv_chart/interactive_layer/crosshair/crosshair_highlight_painter.dart';
import 'package:deriv_chart/src/deriv_chart/interactive_layer/crosshair/crosshair_ohlc_highlight_painter.dart';
import 'package:deriv_chart/src/models/candle.dart';
import 'package:deriv_chart/src/theme/chart_theme.dart';
import 'package:deriv_chart/src/theme/painting_styles/barrier_style.dart';
import 'package:deriv_chart/src/theme/painting_styles/candle_style.dart';

import '../../data_series.dart';
import '../../series_painter.dart';
import '../ohlc_type_series.dart';
import 'ohlc_candle_painter.dart';

/// Ohlc CandleStick series
class OhlcCandleSeries extends OHLCTypeSeries {
  /// Initializes
  OhlcCandleSeries(
    List<Candle> entries, {
    String? id,
    CandleStyle? style,
    HorizontalBarrierStyle? lastTickIndicatorStyle,
  }) : super(
          entries,
          id ?? 'OhlcCandleSeries',
          style: style,
          lastTickIndicatorStyle: lastTickIndicatorStyle,
        );

  @override
  SeriesPainter<DataSeries<Candle>> createPainter() => OhlcCandlePainter(this);

  @override
  CrosshairHighlightPainter? getCrosshairHighlightPainter(
    Candle crosshairTick,
    double Function(double) quoteToY,
    double xCenter,
    double elementWidth,
    ChartTheme theme,
  ) {
    // Check if the current candle is bullish or bearish.
    // Bullish means price went up (close > open)
    final bool isBullishCandle = crosshairTick.close > crosshairTick.open;

    return CrosshairOhlcHighlightPainter(
      candle: crosshairTick,
      quoteToY: quoteToY,
      xCenter: xCenter,
      candleWidth: elementWidth,
      highlightColor: isBullishCandle
          ? theme.candleBullishWickActive
          : theme.candleBearishWickActive,
    );
  }
}
