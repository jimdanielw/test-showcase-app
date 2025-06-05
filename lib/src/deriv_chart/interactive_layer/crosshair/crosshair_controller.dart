import 'package:deriv_chart/src/deriv_chart/interactive_layer/crosshair/find.dart';
import 'package:deriv_chart/src/deriv_chart/chart/data_visualization/chart_series/data_series.dart';
import 'package:deriv_chart/src/deriv_chart/chart/x_axis/x_axis_model.dart';
import 'package:deriv_chart/src/models/tick.dart';
import 'package:deriv_chart/src/models/candle.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A sample of cursor position and timestamp for velocity calculation.
///
/// This class stores a position snapshot along with its timestamp to enable
/// more accurate velocity calculations during rapid crosshair movements.
class _PositionSample {
  /// Creates a position sample with the given offset and timestamp.
  const _PositionSample({
    required this.offset,
    required this.timestamp,
  });

  /// The cursor position at the time of sampling.
  final Offset offset;

  /// The timestamp when this position was recorded.
  final DateTime timestamp;
}

/// Represents the immutable state of the crosshair at any given moment.
///
/// This class encapsulates all the information needed to render and manage
/// the crosshair's current state, including its position, visibility, and
/// the data it's currently highlighting.
///
/// The state is immutable and uses the copyWith pattern for updates, ensuring
/// predictable state management and easy debugging.
///
/// Example usage:
/// ```dart
/// final state = CrosshairState(
///   crosshairTick: someTick,
///   cursorPosition: Offset(100, 200),
///   isVisible: true,
/// );
///
/// final updatedState = state.copyWith(
///   cursorPosition: Offset(150, 250),
/// );
/// ```
class CrosshairState {
  /// Creates a new crosshair state with the specified parameters.
  ///
  /// All parameters are optional and have sensible defaults:
  /// - [crosshairTick]: The data point being highlighted (null if no data)
  /// - [cursorPosition]: Screen coordinates of the cursor (defaults to origin)
  /// - [isVisible]: Whether the crosshair should be rendered (defaults to false)
  /// - [showDetails]: Whether to display the data details popup (defaults to true)
  /// - [isTickWithinDataRange]: Whether the tick represents real data (defaults to true)
  CrosshairState({
    this.crosshairTick,
    this.cursorPosition = Offset.zero,
    this.isVisible = false,
    this.showDetails = true,
    this.isTickWithinDataRange = true,
  });

  /// The tick data point currently being highlighted by the crosshair.
  ///
  /// This can be either a [Tick] for line charts or a [Candle] for candlestick charts.
  /// When null, it indicates that no valid data point is available for the current
  /// cursor position.
  ///
  /// For positions outside the data range, this may contain a virtual tick created
  /// using the cursor's Y position to determine the quote value.
  final Tick? crosshairTick;

  /// The current position of the cursor in local widget coordinates.
  ///
  /// This represents the exact pixel position where the user's cursor or finger
  /// is located on the chart. The crosshair lines will be drawn through this point.
  ///
  /// Coordinates are relative to the chart widget's coordinate system:
  /// - X: horizontal position (left to right)
  /// - Y: vertical position (top to bottom)
  final Offset cursorPosition;

  /// Whether the crosshair should be visible and rendered on the chart.
  ///
  /// When false, the crosshair is completely hidden. When true, the crosshair
  /// lines and associated UI elements (like data tooltips) will be displayed.
  ///
  /// This is controlled by user interactions like long press, hover, or
  /// programmatic show/hide calls.
  final bool isVisible;

  /// Whether to display the detailed data popup/tooltip alongside the crosshair.
  ///
  /// When true, a popup showing the tick's data (price, time, OHLC values, etc.)
  /// will be displayed. When false, only the crosshair lines are shown without
  /// the data details.
  ///
  /// This can be useful for scenarios where you want the crosshair positioning
  /// but don't need the detailed information overlay.
  final bool showDetails;

  /// Indicates whether the current tick represents actual data from the series.
  ///
  /// - `true`: The tick is from the actual data series within the visible range
  /// - `false`: The tick is a virtual/synthetic tick created for cursor positions
  ///   outside the data range, using the cursor's Y position for quote calculation
  ///
  /// This distinction is important for:
  /// - UI styling (virtual ticks might be styled differently)
  /// - Data validation (virtual ticks shouldn't be used for trading decisions)
  /// - Analytics (tracking user interaction with real vs virtual data)
  final bool isTickWithinDataRange;

  /// Creates a copy of this state with the given fields replaced.
  ///
  /// This method follows the copyWith pattern common in Flutter for immutable
  /// state objects. Only the specified parameters will be updated in the new
  /// instance; all others will retain their current values.
  ///
  /// Parameters:
  /// - [crosshairTick]: New tick data to highlight (null to clear)
  /// - [cursorPosition]: New cursor position in local coordinates
  /// - [isVisible]: New visibility state for the crosshair
  /// - [showDetails]: New state for showing/hiding the details popup
  /// - [isTickWithinDataRange]: New state for data range validation
  ///
  /// Returns a new [CrosshairState] instance with the updated values.
  ///
  /// Example:
  /// ```dart
  /// final newState = currentState.copyWith(
  ///   isVisible: true,
  ///   cursorPosition: Offset(100, 200),
  /// );
  /// ```
  CrosshairState copyWith({
    Tick? crosshairTick,
    Offset? cursorPosition,
    bool? isVisible,
    bool? showDetails,
    bool? isTickWithinDataRange,
  }) {
    return CrosshairState(
      crosshairTick: crosshairTick,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      isVisible: isVisible ?? this.isVisible,
      showDetails: showDetails ?? this.showDetails,
      isTickWithinDataRange:
          isTickWithinDataRange ?? this.isTickWithinDataRange,
    );
  }
}

/// Controller that manages all crosshair functionality and user interactions.
///
/// This controller handles the complete lifecycle of crosshair interactions,
/// including gesture recognition, data point finding, state management, and
/// coordinate transformations. It extends [ValueNotifier] to provide reactive
/// updates to UI components that depend on crosshair state.
///
/// ## Key Features:
///
/// ### Gesture Handling
/// - **Long Press**: Activates crosshair and enables data point selection
/// - **Hover**: Shows crosshair on mouse hover (desktop/web)
/// - **Drag**: Updates crosshair position during long press drag
///
/// ### Smart Data Point Finding
/// - Snaps to closest data points within the visible range
/// - Creates virtual data points for positions outside the data range
/// - Handles both [Tick] (line charts) and [Candle] (candlestick charts) data
///
/// ### Auto-Panning
/// - Automatically scrolls the chart when dragging near edges
/// - Velocity-based animation duration for smooth interactions
/// - Configurable pan speed and trigger distances
///
/// ### State Management
/// - Immutable state updates through [CrosshairState]
/// - Reactive notifications to dependent widgets
/// - Proper cleanup and resource management
///
/// ## Usage Example:
///
/// ```dart
/// final controller = CrosshairController(
///   xAxisModel: xAxisModel,
///   series: dataSeries,
///   showCrosshair: true,
///   onCrosshairAppeared: () => print('Crosshair shown'),
///   onCrosshairDisappeared: () => print('Crosshair hidden'),
/// );
///
/// // Listen to state changes
/// controller.addListener(() {
///   final state = controller.value;
///   if (state.isVisible && state.crosshairTick != null) {
///     print('Highlighting: ${state.crosshairTick!.quote}');
///   }
/// });
///
/// // Handle gestures
/// GestureDetector(
///   onLongPressStart: controller.onLongPressStart,
///   onLongPressMoveUpdate: controller.onLongPressUpdate,
///   onLongPressEnd: controller.onLongPressEnd,
///   child: chartWidget,
/// );
/// ```
///
/// ## Performance Considerations:
///
/// - Uses efficient data point lookup algorithms
/// - Implements velocity-based animation timing
/// - Minimizes unnecessary state updates and notifications
/// - Handles large datasets without performance degradation
///
/// ## Coordinate Systems:
///
/// The controller works with multiple coordinate systems:
/// - **Local coordinates**: Widget-relative pixel positions
/// - **Epoch coordinates**: Time-based data point identifiers
/// - **Canvas coordinates**: Chart drawing coordinate system
///
/// See also:
/// - [CrosshairState] for state representation
/// - [XAxisModel] for time/position coordinate transformations
/// - [DataSeries] for data point management
class CrosshairController extends ValueNotifier<CrosshairState> {
  /// Creates a new crosshair controller with the specified configuration.
  ///
  /// Required parameters:
  /// - [xAxisModel]: Handles time-to-position coordinate transformations
  /// - [series]: The data series to find crosshair data points from
  /// - [showCrosshair]: Master switch to enable/disable crosshair functionality
  ///
  /// Optional parameters:
  /// - [onCrosshairAppeared]: Callback fired when crosshair becomes visible
  /// - [onCrosshairDisappeared]: Callback fired when crosshair is hidden
  /// - [isCrosshairActive]: Initial active state (defaults to false)
  /// - [quoteFromCanvasY]: Function to convert Y coordinates to quote values
  ///
  /// The [quoteFromCanvasY] function is essential for creating virtual data points
  /// when the cursor is outside the actual data range. It should convert a canvas
  /// Y coordinate to the corresponding price/quote value.
  ///
  /// Example:
  /// ```dart
  /// final controller = CrosshairController(
  ///   xAxisModel: myXAxisModel,
  ///   series: myDataSeries,
  ///   showCrosshair: true,
  ///   quoteFromCanvasY: (y) => yAxisModel.quoteFromCanvasY(y),
  ///   onCrosshairAppeared: () {
  ///     // Pause auto-refresh, show additional UI, etc.
  ///   },
  ///   onCrosshairDisappeared: () {
  ///     // Resume auto-refresh, hide additional UI, etc.
  ///   },
  /// );
  /// ```
  CrosshairController({
    required this.xAxisModel,
    required this.series,
    required this.showCrosshair,
    this.onCrosshairAppeared,
    this.onCrosshairDisappeared,
    this.isCrosshairActive = false,
    this.quoteFromCanvasY,
  }) : super(CrosshairState());

  /// The X-axis model responsible for time-to-position coordinate transformations.
  ///
  /// This model provides essential functionality for:
  /// - Converting screen X coordinates to epoch timestamps
  /// - Converting epoch timestamps back to screen positions
  /// - Managing chart panning and auto-pan behavior
  /// - Determining visible time ranges and chart boundaries
  ///
  /// The controller uses this model extensively for finding data points
  /// that correspond to cursor positions and for implementing auto-panning
  /// behavior during crosshair interactions.
  final XAxisModel xAxisModel;

  /// The data series containing the chart's tick/candle data.
  ///
  /// This series provides access to:
  /// - All visible data entries within the current chart viewport
  /// - Data point lookup and filtering capabilities
  /// - Type information (Tick vs Candle) for proper crosshair handling
  ///
  /// The controller queries this series to find the closest data points
  /// to cursor positions and to determine data range boundaries for
  /// virtual tick creation.
  ///
  /// Note: This is mutable to allow for dynamic data updates during
  /// the controller's lifetime.
  DataSeries<Tick> series;

  /// Master switch to enable or disable all crosshair functionality.
  ///
  /// When `false`, the crosshair will never be shown regardless of user
  /// interactions. When `true`, the crosshair can be activated through
  /// gestures like long press or mouse hover.
  ///
  /// This is useful for:
  /// - Temporarily disabling crosshair during certain chart states
  /// - Providing user preference controls
  /// - Conditional feature availability based on chart type or context
  final bool showCrosshair;

  /// Callback invoked when the crosshair becomes visible.
  ///
  /// This callback is triggered when:
  /// - A long press gesture starts and successfully finds a data point
  /// - Mouse hover begins and finds a valid crosshair position
  /// - The crosshair is programmatically shown
  ///
  /// Common use cases:
  /// - Pausing live data updates to prevent crosshair jumping
  /// - Showing additional UI elements (e.g., detailed info panels)
  /// - Analytics tracking for user interaction patterns
  /// - Triggering haptic feedback on mobile devices
  final VoidCallback? onCrosshairAppeared;

  /// Callback invoked when the crosshair is hidden.
  ///
  /// This callback is triggered when:
  /// - A long press gesture ends
  /// - Mouse cursor exits the chart area
  /// - The crosshair is programmatically hidden
  ///
  /// Common use cases:
  /// - Resuming live data updates
  /// - Hiding additional UI elements
  /// - Cleaning up temporary state or resources
  /// - Analytics tracking for interaction completion
  final VoidCallback? onCrosshairDisappeared;

  /// Indicates whether the crosshair is currently in an active interaction state.
  ///
  /// This differs from [CrosshairState.isVisible] in that it specifically tracks
  /// whether the user is actively interacting with the crosshair (e.g., during
  /// a long press drag), not just whether it's visible.
  ///
  /// Used internally for:
  /// - Coordinating with other chart interactions
  /// - Managing gesture recognition priorities
  /// - Optimizing performance during active interactions
  bool isCrosshairActive;

  /// Function to convert canvas Y coordinates to quote/price values.
  ///
  /// This function is essential for creating virtual data points when the cursor
  /// is positioned outside the actual data range. It should implement the inverse
  /// transformation of the Y-axis scaling used for chart rendering.
  ///
  /// Parameters:
  /// - `y`: The Y coordinate in canvas/widget coordinate system
  ///
  /// Returns:
  /// - The corresponding quote/price value at that Y position
  ///
  /// Example implementation:
  /// ```dart
  /// quoteFromCanvasY: (y) {
  ///   final double normalizedY = (y - chartTop) / chartHeight;
  ///   return maxPrice - (normalizedY * (maxPrice - minPrice));
  /// }
  /// ```
  ///
  /// This function is typically provided by the Y-axis model or price scale
  /// component of the chart.
  final double Function(double)? quoteFromCanvasY;

  /// Smoothing factor for velocity calculations to reduce jitter during fast movements.
  /// Value between 0.0 (no smoothing) and 1.0 (maximum smoothing).
  /// Higher values provide smoother movement but may introduce slight lag.
  static const double _velocitySmoothing = 0.3;

  /// Smoothed velocity for more stable crosshair movement during fast panning.
  Offset _smoothedVelocity = Offset.zero;

  /// Minimum time interval between position updates to prevent excessive calculations.
  /// This helps maintain smooth performance during very fast gesture updates.
  static const Duration _minUpdateInterval = Duration(milliseconds: 8);

  /// Timestamp of the last position update to enforce minimum update intervals.
  DateTime _lastUpdateTime = DateTime.now();

  /// Buffer for storing recent position samples for improved velocity calculation.
  /// This helps provide more accurate velocity estimates during rapid movements.
  final List<_PositionSample> _positionSamples = <_PositionSample>[];

  /// Maximum number of position samples to keep for velocity calculation.
  static const int _maxSamples = 5;

  /// Updates the drag velocity based on current and previous cursor positions.
  ///
  /// This enhanced method provides improved velocity calculation for smoother
  /// crosshair movement during fast panning on small screens. It includes:
  ///
  /// - **Throttling**: Enforces minimum update intervals to prevent excessive calculations
  /// - **Sample buffering**: Maintains a history of recent positions for better accuracy
  /// - **Velocity smoothing**: Applies exponential smoothing to reduce jitter
  /// - **Multi-point calculation**: Uses multiple samples for more stable velocity estimates
  ///
  /// The calculated velocity is used by [animationDuration] to determine
  /// appropriate animation timing for smooth crosshair interactions.
  ///
  /// Parameters:
  /// - [currentOffset]: The current cursor position in local coordinates
  ///
  /// The method automatically updates internal tracking variables for the next cycle.
  void _updateDragVelocity(Offset currentOffset) {
    final DateTime currentTime = DateTime.now();

    // Throttle updates to prevent excessive calculations during very fast movements
    if (currentTime.difference(_lastUpdateTime) < _minUpdateInterval) {
      return;
    }

    // Add current position to sample buffer
    _addPositionSample(currentOffset, currentTime);

    // Calculate velocity using multiple samples for better accuracy
    final Offset rawVelocity = _calculateVelocityFromSamples();

    // Apply smoothing to reduce jitter during fast movements
    _smoothedVelocity = _applyVelocitySmoothing(rawVelocity);

    _lastUpdateTime = currentTime;
  }

  /// Adds a position sample to the buffer for velocity calculation.
  ///
  /// This method maintains a rolling buffer of recent position samples to enable
  /// more accurate velocity calculations during rapid movements. The buffer is
  /// limited to [_maxSamples] entries to prevent memory growth.
  ///
  /// Parameters:
  /// - [position]: The cursor position to add
  /// - [timestamp]: The time when this position was recorded
  void _addPositionSample(Offset position, DateTime timestamp) {
    _positionSamples.add(_PositionSample(
      offset: position,
      timestamp: timestamp,
    ));

    // Remove old samples to maintain buffer size
    while (_positionSamples.length > _maxSamples) {
      _positionSamples.removeAt(0);
    }
  }

  /// Calculates velocity using multiple position samples for improved accuracy.
  ///
  /// This method analyzes the position sample buffer to compute a more stable
  /// velocity estimate than simple two-point calculation. It uses the oldest
  /// and newest samples to calculate velocity over a longer time period,
  /// which helps reduce noise from rapid gesture updates.
  ///
  /// Returns:
  /// - The calculated velocity in pixels per second as an [Offset]
  /// - Returns [Offset.zero] if insufficient samples are available
  Offset _calculateVelocityFromSamples() {
    if (_positionSamples.length < 2) {
      return Offset.zero;
    }

    final _PositionSample oldest = _positionSamples.first;
    final _PositionSample newest = _positionSamples.last;

    final Duration timeDiff = newest.timestamp.difference(oldest.timestamp);
    final Offset offsetDiff = newest.offset - oldest.offset;

    if (timeDiff.inMilliseconds <= 0) {
      return Offset.zero;
    }

    // Calculate velocity in pixels per second
    final double vx = (offsetDiff.dx / timeDiff.inMilliseconds) * 1000;
    final double vy = (offsetDiff.dy / timeDiff.inMilliseconds) * 1000;

    return Offset(vx, vy);
  }

  /// Applies exponential smoothing to velocity for reduced jitter.
  ///
  /// This method smooths the raw velocity calculation to provide more stable
  /// crosshair movement during fast panning. The smoothing helps eliminate
  /// sudden velocity spikes that can cause jarring visual effects.
  ///
  /// The smoothing uses the formula:
  /// `smoothed = (1 - factor) * previous + factor * current`
  ///
  /// Parameters:
  /// - [rawVelocity]: The unsmoothed velocity calculation
  ///
  /// Returns:
  /// - The smoothed velocity as an [Offset]
  Offset _applyVelocitySmoothing(Offset rawVelocity) {
    final double smoothedX = (1 - _velocitySmoothing) * _smoothedVelocity.dx +
        _velocitySmoothing * rawVelocity.dx;
    final double smoothedY = (1 - _velocitySmoothing) * _smoothedVelocity.dy +
        _velocitySmoothing * rawVelocity.dy;

    return Offset(smoothedX, smoothedY);
  }

  /// Clears velocity tracking data when crosshair interaction ends.
  ///
  /// This method resets all velocity-related state to ensure clean startup
  /// for the next crosshair interaction. It should be called when the
  /// crosshair is hidden or interaction ends.
  void _clearVelocityTracking() {
    _positionSamples.clear();
    _smoothedVelocity = Offset.zero;
  }

  /// Calculates the appropriate animation duration based on current drag velocity.
  ///
  /// This enhanced getter provides velocity-adaptive animation timing optimized for
  /// smooth crosshair interactions on small screens during fast panning. The duration
  /// is inversely related to drag velocity with improved responsiveness:
  ///
  /// **Enhanced Duration Mapping for Small Screens:**
  /// - **No movement** (velocity = 0): 3ms (immediate)
  /// - **Very fast** (velocity > 2500 px/s): 1ms (ultra-responsive)
  /// - **Fast** (velocity > 1500 px/s): 3ms (very responsive)
  /// - **Medium** (velocity 800-1500 px/s): 8-15ms (balanced)
  /// - **Slow** (velocity < 800 px/s): 25ms (smooth but not sluggish)
  ///
  /// The calculation uses the smoothed velocity to provide stable animation timing
  /// that adapts to user interaction patterns, with special optimizations for
  /// rapid movements common on small touch screens.
  ///
  /// Returns the calculated [Duration] for use in chart animations and transitions.
  Duration get animationDuration {
    // Use smoothed velocity for more stable animation timing
    final double dragXVelocity = _smoothedVelocity.dx.abs();

    // Ultra-fast movements: immediate response for touch screen flicks
    if (dragXVelocity > 2500) {
      return const Duration(milliseconds: 1);
    }

    // Very fast movements: minimal delay for responsive feel
    if (dragXVelocity > 1500) {
      return const Duration(milliseconds: 3);
    }

    // Fast movements: short animation for smooth tracking
    if (dragXVelocity > 800) {
      // Linear interpolation: 1500px/s -> 3ms, 800px/s -> 15ms
      final double factor = (dragXVelocity - 800) / 700; // 0 to 1
      final int duration = (15 - (factor * 12)).round(); // 15ms to 3ms
      return Duration(milliseconds: duration);
    }

    // Slow movements: longer animation for smoothness, but not too long
    if (dragXVelocity > 0) {
      // Linear interpolation: 800px/s -> 15ms, 0px/s -> 25ms
      final double factor = dragXVelocity / 800; // 0 to 1
      final int duration = (25 - (factor * 10)).round(); // 25ms to 15ms
      return Duration(milliseconds: duration);
    }

    // No movement: immediate response
    return const Duration(milliseconds: 3);
  }

  /// Handles the start of a long press gesture to activate the crosshair.
  ///
  /// This method is called when the user begins a long press on the chart.
  /// It initializes the crosshair interaction by:
  ///
  /// 1. **Velocity tracking setup**: Initializes position and time tracking
  ///    for velocity calculations during subsequent drag movements
  /// 2. **Callback notification**: Triggers the [onCrosshairAppeared] callback
  /// 3. **Auto-pan control**: Disables chart auto-panning to prevent interference
  ///    with crosshair positioning
  /// 4. **Data point finding**: Locates the closest data point to the press position
  /// 5. **Crosshair display**: Shows the crosshair if a valid data point is found
  ///
  /// The method converts the screen coordinates to epoch time and searches for
  /// the nearest data point within the visible series entries.
  ///
  /// Parameters:
  /// - [details]: Contains the local position and other gesture information
  ///
  /// Usage:
  /// ```dart
  /// GestureDetector(
  ///   onLongPressStart: controller.onLongPressStart,
  ///   child: chartWidget,
  /// )
  /// ```
  void onLongPressStart(LongPressStartDetails details) {
    // Initialize velocity tracking with the starting position
    _addPositionSample(details.localPosition, DateTime.now());

    onCrosshairAppeared?.call();

    // Stop auto-panning to make it easier to select candle or tick.
    xAxisModel.disableAutoPan();

    final double x = details.localPosition.dx;
    final int epoch = xAxisModel.epochFromX(x);
    final Tick? tick = _findClosestTick(epoch);

    if (tick != null) {
      _showCrosshair(tick, details.localPosition);
    }
  }

  /// Handles updates during a long press drag to move the crosshair.
  ///
  /// This method is called continuously while the user drags during a long press.
  /// It performs several key operations:
  ///
  /// 1. **Velocity calculation**: Updates drag velocity for animation timing
  /// 2. **Position conversion**: Converts screen coordinates to epoch time
  /// 3. **Data point lookup**: Finds the closest data point to the new position
  /// 4. **Crosshair update**: Updates the crosshair position and highlighted data
  /// 5. **Auto-panning**: Triggers chart scrolling when near edges
  ///
  /// The auto-panning feature allows users to explore data beyond the current
  /// viewport by dragging the crosshair near the chart edges.
  ///
  /// Parameters:
  /// - [details]: Contains the current position and movement information
  ///
  /// Usage:
  /// ```dart
  /// GestureDetector(
  ///   onLongPressMoveUpdate: controller.onLongPressUpdate,
  ///   child: chartWidget,
  /// )
  /// ```
  void onLongPressUpdate(LongPressMoveUpdateDetails details) {
    // Update drag velocity with the latest gesture data
    _updateDragVelocity(details.localPosition);

    final double x = details.localPosition.dx;
    final int epoch = xAxisModel.epochFromX(x);
    final Tick? tick = _findClosestTick(epoch);

    if (tick != null) {
      _showCrosshair(tick, details.localPosition);
    }

    // Handle auto-panning near the edges
    _updatePanSpeed(x);
  }

  /// Handles the end of a long press gesture to deactivate the crosshair.
  ///
  /// This method is called when the user releases a long press. It performs
  /// cleanup and restoration operations:
  ///
  /// 1. **Velocity capture**: Captures final velocity from Flutter's gesture system
  ///    if available, which may be more accurate than our manual calculation
  /// 2. **Callback notification**: Triggers the [onCrosshairDisappeared] callback
  /// 3. **Auto-pan restoration**: Stops any active panning and re-enables auto-pan
  /// 4. **Crosshair hiding**: Hides the crosshair and resets interaction state
  ///
  /// The captured velocity is stored for potential use in subsequent animations
  /// or interactions.
  ///
  /// Parameters:
  /// - [details]: Contains final gesture information including velocity
  ///
  /// Usage:
  /// ```dart
  /// GestureDetector(
  ///   onLongPressEnd: controller.onLongPressEnd,
  ///   child: chartWidget,
  /// )
  /// ```
  void onLongPressEnd(LongPressEndDetails details) {
    // Use the velocity provided by the gesture system if available for smoothed velocity
    if (details.velocity != Velocity.zero) {
      _smoothedVelocity = details.velocity.pixelsPerSecond;
    }

    onCrosshairDisappeared?.call();
    xAxisModel
      ..pan(0)
      ..enableAutoPan();

    _hideCrosshair();
  }

  /// Handles mouse hover events to show crosshair on desktop/web platforms.
  ///
  /// This method provides crosshair functionality for mouse-based interactions,
  /// typically on desktop and web platforms. Unlike long press gestures, hover
  /// interactions are immediate and don't require gesture initiation.
  ///
  /// Key differences from touch interactions:
  /// - **Immediate activation**: No long press delay required
  /// - **Virtual tick support**: Can create virtual ticks outside data range
  ///   using the Y coordinate for price calculation
  /// - **Continuous updates**: Updates on every mouse movement
  ///
  /// The method uses [_findTickForCrosshair] instead of [_findClosestTick]
  /// to enable virtual tick creation when the cursor is outside the data range.
  ///
  /// Parameters:
  /// - [event]: Contains mouse position and other pointer information
  ///
  /// Usage:
  /// ```dart
  /// Listener(
  ///   onPointerHover: controller.onHover,
  ///   child: chartWidget,
  /// )
  /// ```
  void onHover(PointerHoverEvent event) {
    final double x = event.localPosition.dx;
    final double y = event.localPosition.dy;
    final int epoch = xAxisModel.epochFromX(x);
    final Tick? tick = _findTickForCrosshair(epoch, x, y);

    if (tick != null) {
      _showCrosshair(tick, event.localPosition);
    }

    notifyListeners();
  }

  /// Handles mouse exit events to hide crosshair when cursor leaves the chart.
  ///
  /// This method is called when the mouse cursor exits the chart area on
  /// desktop/web platforms. It immediately hides the crosshair to provide
  /// clear visual feedback that the interaction has ended.
  ///
  /// The method simply calls [_hideCrosshair] to clean up the crosshair state
  /// and trigger appropriate callbacks.
  ///
  /// Parameters:
  /// - [event]: Contains information about the pointer exit event
  ///
  /// Usage:
  /// ```dart
  /// Listener(
  ///   onPointerExit: controller.onExit,
  ///   child: chartWidget,
  /// )
  /// ```
  void onExit(PointerExitEvent event) {
    _hideCrosshair();
  }

  /// Hides the crosshair and resets the interaction state.
  ///
  /// This private method handles the complete process of hiding the crosshair:
  ///
  /// 1. **Callback notification**: Triggers [onCrosshairDisappeared] if the
  ///    crosshair was previously visible
  /// 2. **State update**: Updates the crosshair state to invisible
  /// 3. **Interaction reset**: Sets [isCrosshairActive] to false
  /// 4. **Velocity cleanup**: Clears velocity tracking data for next interaction
  /// 5. **Listener notification**: Notifies all listeners of the state change
  ///
  /// This method is called from various places including gesture end handlers
  /// and mouse exit events to ensure consistent cleanup behavior.
  void _hideCrosshair() {
    if (value.isVisible) {
      onCrosshairDisappeared?.call();
    }

    value = value.copyWith(
      isVisible: false,
    );

    isCrosshairActive = false;

    // Clear velocity tracking data for clean startup of next interaction
    _clearVelocityTracking();

    notifyListeners(); // Notify listeners when enabled changes
  }

  /// Shows the crosshair with the specified tick data and cursor position.
  ///
  /// This private method handles the complete process of displaying the crosshair:
  ///
  /// 1. **Permission check**: Verifies that [showCrosshair] is enabled
  /// 2. **Callback notification**: Triggers [onCrosshairAppeared] if the
  ///    crosshair was previously hidden
  /// 3. **Data range validation**: Determines if the tick represents real or virtual data
  /// 4. **State update**: Updates the crosshair state with new data and position
  /// 5. **Interaction activation**: Sets [isCrosshairActive] to true
  /// 6. **Listener notification**: Notifies all listeners of the state change
  ///
  /// Parameters:
  /// - [crosshairTick]: The tick data to highlight (real or virtual)
  /// - [position]: The cursor position in local coordinates
  ///
  /// The method ensures that callbacks are only triggered when the visibility
  /// state actually changes, preventing unnecessary notifications.
  void _showCrosshair(Tick crosshairTick, Offset position) {
    // Only show the crosshair if showCrosshair is true
    if (!showCrosshair) {
      return;
    }

    if (!value.isVisible) {
      onCrosshairAppeared?.call();
    }

    // Determine if the tick is within the data range
    final bool isWithinRange = _isCursorWithinDataRange(
      crosshairTick.epoch,
      series.visibleEntries.entries,
    );

    value = value.copyWith(
      crosshairTick: crosshairTick,
      cursorPosition: position,
      isVisible: true,
      isTickWithinDataRange: isWithinRange,
    );
    isCrosshairActive = true;
    notifyListeners(); // Notify listeners when enabled changes
  }

  /// Finds the closest tick to the specified epoch timestamp.
  ///
  /// This private method provides a simple wrapper around the [findClosestToEpoch]
  /// utility function, using the current series' visible entries as the search space.
  ///
  /// This method is used for touch-based interactions (long press) where we always
  /// want to snap to actual data points within the visible range. For mouse hover
  /// interactions that support virtual ticks, use [_findTickForCrosshair] instead.
  ///
  /// Parameters:
  /// - [epoch]: The target epoch timestamp to find the closest tick for
  ///
  /// Returns:
  /// - The closest [Tick] to the specified epoch, or null if no data is available
  ///
  /// See also:
  /// - [_findTickForCrosshair] for hover interactions with virtual tick support
  /// - [findClosestToEpoch] for the underlying search algorithm
  Tick? _findClosestTick(int epoch) {
    return findClosestToEpoch(epoch, series.visibleEntries.entries);
  }

  /// Finds the appropriate tick for crosshair display based on cursor position.
  ///
  /// This method implements smart tick finding logic that adapts based on whether
  /// the cursor is within the actual data range:
  ///
  /// **Within data range**: Snaps to the closest actual data point using the
  /// same logic as [_findClosestTick].
  ///
  /// **Outside data range**: Creates a virtual tick using the cursor's Y position
  /// to calculate the quote value via [quoteFromCanvasY]. This allows users to
  /// see price information even when hovering outside the time range of actual data.
  ///
  /// Virtual tick creation:
  /// - For [Candle] data: Creates a candle with all OHLC values set to the calculated quote
  /// - For [Tick] data: Creates a simple tick with the calculated quote
  /// - Uses the cursor's epoch time for the virtual tick's timestamp
  ///
  /// Parameters:
  /// - [epoch]: The epoch timestamp corresponding to the cursor's X position
  /// - [x]: The cursor's X coordinate (currently unused but available for future enhancements)
  /// - [y]: The cursor's Y coordinate used for quote calculation in virtual ticks
  ///
  /// Returns:
  /// - A [Tick] or [Candle] representing either real data or a virtual data point,
  ///   or null if no data is available and virtual tick creation fails
  ///
  /// Throws:
  /// - May throw if [quoteFromCanvasY] is null when trying to create virtual ticks
  ///
  /// This method is primarily used for mouse hover interactions where virtual
  /// tick support enhances the user experience.
  Tick? _findTickForCrosshair(int epoch, double x, double y) {
    final List<Tick> entries = series.visibleEntries.entries;

    if (entries.isEmpty) {
      return null;
    }

    // Check if cursor is within the data range
    final bool isWithinDataRange = _isCursorWithinDataRange(epoch, entries);

    if (isWithinDataRange) {
      // Within data range: snap to closest tick
      return findClosestToEpoch(epoch, entries);
    } else {
      // Outside data range: create virtual tick using cursor's Y position for quote
      final Tick latestTick = entries.last;

      final double quote = quoteFromCanvasY!(y);

      if (latestTick is Candle) {
        return Candle(
          epoch: epoch,
          open: quote,
          close: quote,
          high: quote,
          low: quote,
          currentEpoch: epoch,
        );
      } else {
        return Tick(
          epoch: epoch,
          quote: quote,
        );
      }
    }
  }

  /// Determines whether the cursor position falls within the actual data range.
  ///
  /// This method checks if the specified epoch timestamp falls between the first
  /// and last data points in the visible entries. This information is used to:
  ///
  /// - Decide whether to create virtual ticks for positions outside the data range
  /// - Set the [CrosshairState.isTickWithinDataRange] flag for UI styling
  /// - Validate data interactions for analytics and business logic
  ///
  /// The method uses inclusive bounds, meaning positions exactly at the first or
  /// last data point are considered within range.
  ///
  /// Parameters:
  /// - [epoch]: The epoch timestamp to check
  /// - [entries]: The list of data entries to check against
  ///
  /// Returns:
  /// - `true` if the epoch falls within the data range (inclusive)
  /// - `false` if the epoch is outside the data range or if entries is empty
  ///
  /// Example:
  /// ```dart
  /// final entries = [tick1, tick2, tick3]; // epochs: 100, 200, 300
  /// _isCursorWithinDataRange(150, entries); // returns true
  /// _isCursorWithinDataRange(50, entries);  // returns false
  /// _isCursorWithinDataRange(350, entries); // returns false
  /// ```
  bool _isCursorWithinDataRange(int epoch, List<Tick> entries) {
    if (entries.isEmpty) {
      return false;
    }

    final int firstEpoch = entries.first.epoch;
    final int lastEpoch = entries.last.epoch;

    // Consider cursor within range if it's between first and last tick epochs
    return epoch >= firstEpoch && epoch <= lastEpoch;
  }

  /// Updates the chart panning speed based on cursor proximity to chart edges.
  ///
  /// This method implements auto-panning functionality that allows users to
  /// explore data beyond the current viewport by dragging the crosshair near
  /// the chart edges. The panning is triggered when the cursor is within a
  /// specified distance from either edge.
  ///
  /// **Panning behavior**:
  /// - **Left edge** (x < 60px): Pans left (negative direction) to show earlier data
  /// - **Right edge** (x > width - 60px): Pans right (positive direction) to show later data
  /// - **Center area**: Stops panning (speed = 0)
  ///
  /// **Configuration**:
  /// - `closeDistance`: 60px trigger zone from each edge
  /// - `panSpeed`: 0.08 units per update cycle
  ///
  /// The panning speed is constant within the trigger zones, providing predictable
  /// and smooth scrolling behavior. The method is called continuously during
  /// long press drag operations via [onLongPressUpdate].
  ///
  /// Parameters:
  /// - [x]: The current cursor X position in local coordinates
  ///
  /// The method directly calls [XAxisModel.pan] to perform the actual chart
  /// scrolling, which handles the coordinate transformations and viewport updates.
  ///
  /// Note: Auto-panning is automatically disabled when the long press gesture
  /// starts and re-enabled when it ends to prevent conflicts with crosshair
  /// positioning.
  void _updatePanSpeed(double x) {
    const double closeDistance = 60;
    const double panSpeed = 0.08;

    if (x < closeDistance) {
      xAxisModel.pan(-panSpeed);
    } else if (xAxisModel.width! - x < closeDistance) {
      xAxisModel.pan(panSpeed);
    } else {
      xAxisModel.pan(0);
    }
  }
}
