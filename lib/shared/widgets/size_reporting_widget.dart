import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A widget that reports its size whenever it changes.
class SizeReportingWidget extends StatefulWidget {
  final Widget child;
  final ValueChanged<ui.Size> onSizeChange;
  final Duration throttleDuration;

  const SizeReportingWidget({
    super.key,
    required this.child,
    required this.onSizeChange,
    this.throttleDuration = Duration.zero,
  });

  @override
  State<SizeReportingWidget> createState() => _SizeReportingWidgetState();
}

class _SizeReportingWidgetState extends State<SizeReportingWidget> {
  ui.Size? _oldSize;
  bool _isScheduled = false;

  @override
  Widget build(BuildContext context) {
    return _SizeReportingRenderObjectWidget(
      onSizeChange: _notifySizeChange,
      child: widget.child,
    );
  }

  void _notifySizeChange(ui.Size size) {
    if (_oldSize == size) return;
    _oldSize = size;
    
    if (widget.throttleDuration == Duration.zero) {
      widget.onSizeChange(size);
    } else if (!_isScheduled) {
      _isScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isScheduled = false;
        if (mounted && _oldSize != null) {
          widget.onSizeChange(_oldSize!);
        }
      });
    }
  }
}

class _SizeReportingRenderObjectWidget extends SingleChildRenderObjectWidget {
  final ValueChanged<ui.Size> onSizeChange;

  const _SizeReportingRenderObjectWidget({
    required Widget child,
    required this.onSizeChange,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeReportingObject(onSizeChange: onSizeChange);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderSizeReportingObject renderObject) {
    renderObject.onSizeChange = onSizeChange;
  }
}

class _RenderSizeReportingObject extends RenderProxyBox {
  ValueChanged<ui.Size> onSizeChange;
  Size? _oldSize;

  _RenderSizeReportingObject({required this.onSizeChange});

  @override
  void performLayout() {
    super.performLayout();
    if (size != _oldSize) {
      _oldSize = size;
      // notify callback
      onSizeChange(size);
    }
  }
}
