import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/tv/tv_mode.dart';

/// Global TV / D-pad layer installed via [MaterialApp.builder].
///
/// Uses a [HardwareKeyboard] handler so it can observe keys even when no
/// widget holds focus (the common case on TV before focus is "ignited").
///
/// Behavior:
/// - Arrow keys: when no widget holds focus, kick-start focus on the first
///   focusable widget. Once something is focused, Flutter's built-in
///   directional traversal takes over (we do not intercept).
/// - Menu key: toggles the virtual cursor overlay.
/// - Virtual cursor mode: arrows move the cursor, Enter / DPAD_CENTER /
///   Gamepad A tap at the cursor position via injected pointer events.
///
/// Enter activation and back navigation are left to Flutter and Material.
class TvShortcutLayer extends StatefulWidget {
  const TvShortcutLayer({super.key, required this.child});

  final Widget child;

  @override
  State<TvShortcutLayer> createState() => _TvShortcutLayerState();
}

class _TvShortcutLayerState extends State<TvShortcutLayer> {
  static const _pointerId = 24680;

  /// Logical pixels per arrow press (faster while key repeats).
  static const _cursorStep = 24.0;
  static const _cursorRepeatStep = 48.0;

  Offset _cursor = Offset.zero;
  bool _cursorInitialized = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    TvModeController.instance.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    TvModeController.instance.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  bool _isArrow(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.arrowLeft ||
      key == LogicalKeyboardKey.arrowRight;

  bool _isMenu(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.contextMenu ||
      key == LogicalKeyboardKey.settings;

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.gameButtonA ||
      key == LogicalKeyboardKey.space;

  /// Global keyboard hook. Returns true when the event is consumed and must
  /// not reach the regular focus system.
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    final controller = TvModeController.instance;
    final key = event.logicalKey;

    if (!controller.enabled) {
      if (controller.mode == 0 && _isArrow(key)) {
        controller.onDpadSeen();
        return _kickStartFocus();
      }
      return false;
    }

    if (_isMenu(key)) {
      controller.toggleVirtualCursor();
      return true;
    }

    if (controller.virtualCursorOn) {
      if (_isSelect(key)) {
        _tapAtCursor();
        return true;
      }
      final step = event is KeyRepeatEvent ? _cursorRepeatStep : _cursorStep;
      Offset delta = Offset.zero;
      if (key == LogicalKeyboardKey.arrowUp) delta = const Offset(0, -1);
      if (key == LogicalKeyboardKey.arrowDown) delta = const Offset(0, 1);
      if (key == LogicalKeyboardKey.arrowLeft) delta = const Offset(-1, 0);
      if (key == LogicalKeyboardKey.arrowRight) delta = const Offset(1, 0);
      if (delta == Offset.zero) {
        return false;
      }
      if (mounted) {
        setState(() {
          _cursor = _clampCursor(_cursor + delta * step);
        });
      }
      return true;
    }

    if (_isArrow(key)) {
      return _kickStartFocus();
    }

    return false;
  }

  bool _kickStartFocus() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.context != null) {
      // Focus already lives somewhere; default traversal handles it.
      return false;
    }
    final target = _findFirstFocusable(FocusManager.instance.rootScope);
    if (target == null) {
      return false;
    }
    target.requestFocus();
    return true;
  }

  /// Walks the focus tree in registration order and returns the first node
  /// that can actually take focus. The root scope has no BuildContext, so
  /// policy-based lookup cannot be used for the initial ignition.
  FocusNode? _findFirstFocusable(FocusScopeNode scope) {
    for (final child in scope.children) {
      if (child is FocusScopeNode) {
        if (!child.canRequestFocus) {
          continue;
        }
        final found = _findFirstFocusable(child);
        if (found != null) {
          return found;
        }
      } else if (child.canRequestFocus && child.context != null) {
        return child;
      }
    }
    return null;
  }

  Offset _clampCursor(Offset position) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return position;
    final size = mediaQuery.size;
    return Offset(
      position.dx.clamp(0, size.width - 1),
      position.dy.clamp(0, size.height - 1),
    );
  }

  void _ensureCursorInitialized(BoxConstraints constraints) {
    if (_cursorInitialized) return;
    _cursor = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    _cursorInitialized = true;
  }

  void _tapAtCursor() {
    final position = _cursor;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        pointer: _pointerId,
        position: position,
        kind: PointerDeviceKind.touch,
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      GestureBinding.instance.handlePointerEvent(
        PointerUpEvent(
          pointer: _pointerId,
          position: position,
          kind: PointerDeviceKind.touch,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureCursorInitialized(constraints);
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            if (TvModeController.instance.virtualCursorOn)
              Positioned(
                left: _cursor.dx,
                top: _cursor.dy,
                child: IgnorePointer(
                  child: _VirtualCursorPointer(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _VirtualCursorPointer extends StatelessWidget {
  const _VirtualCursorPointer({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
