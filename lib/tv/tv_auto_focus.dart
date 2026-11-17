import 'package:flutter/material.dart';
import 'package:kazumi/tv/tv_mode.dart';

/// Grabs initial focus for a page (or onboarding step) when the TV layer is
/// active and nothing else currently holds focus.
///
/// Wrap the top level body of a page. If any widget is already focused
/// (e.g. a dialog, a text field), this does nothing.
class TvAutoFocus extends StatefulWidget {
  const TvAutoFocus({super.key, required this.child});

  final Widget child;

  @override
  State<TvAutoFocus> createState() => _TvAutoFocusState();
}

class _TvAutoFocusState extends State<TvAutoFocus> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestFirstFocus());
  }

  void _requestFirstFocus() {
    if (!mounted || !TvModeController.instance.enabled) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.context != null) return;
    final context = this.context;
    final scope = FocusScope.of(context);
    final target = _findFirstFocusable(scope);
    if (target == null) return;
    target.requestFocus();
  }

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
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
