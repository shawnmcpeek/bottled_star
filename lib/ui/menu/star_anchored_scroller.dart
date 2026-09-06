import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'menu_atmosphere.dart';
import 'menu_page_scaffold.dart';

/// Vertically centers [child] on the bottled-star core, then scrolls if the
/// child is taller than the remaining space.
class StarAnchoredScroller extends StatefulWidget {
  const StarAnchoredScroller({
    super.key,
    required this.child,
    this.padding = MenuPageScaffold.starPinnedPadding,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  State<StarAnchoredScroller> createState() => _StarAnchoredScrollerState();
}

class _StarAnchoredScrollerState extends State<StarAnchoredScroller> {
  final GlobalKey _childKey = GlobalKey();
  final ScrollController _scroll = ScrollController();

  /// First-frame estimate so the list does not jump after measure.
  static const double _estimatedChildHeight = 360;

  double _childHeight = _estimatedChildHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void didUpdateWidget(covariant StarAnchoredScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final height = box.size.height;
    if ((height - _childHeight).abs() >= 0.5) {
      setState(() => _childHeight = height);
      WidgetsBinding.instance.addPostFrameCallback(_syncScroll);
      return;
    }
    _syncScroll(Duration.zero);
  }

  void _syncScroll(Duration _) {
    if (!mounted || !_scroll.hasClients) return;
    final size = MediaQuery.sizeOf(context);
    final geo = MenuStarGeometry.of(size);
    final top = geo.center.dy - _childHeight / 2;
    final target = (top < 0 ? -top : 0.0).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if ((_scroll.offset - target).abs() > 0.5) {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final geo = MenuStarGeometry.of(size);
    final media = MediaQuery.paddingOf(context);
    final top = geo.center.dy - _childHeight / 2;
    final topPad = math.max(0.0, top);
    final bottomPad = math.max(
      widget.padding.bottom + media.bottom,
      size.height - (topPad + _childHeight),
    );

    return SingleChildScrollView(
      controller: _scroll,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.padding.left,
          0,
          widget.padding.right,
          0,
        ),
        child: Column(
          children: [
            SizedBox(height: topPad),
            KeyedSubtree(key: _childKey, child: widget.child),
            SizedBox(height: bottomPad),
          ],
        ),
      ),
    );
  }
}
