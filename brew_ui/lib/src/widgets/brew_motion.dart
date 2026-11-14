import 'package:flutter/material.dart';

import '../tokens/brew_layout.dart';

/// [inner]'s route transition, or a plain cross-fade under reduced motion
/// ([BrewMotion.reduced]). [BrewMotion.pageTransitions] wraps every platform's
/// builder in one; wrap your own builder the same way.
class BrewReducedMotionTransitionsBuilder extends PageTransitionsBuilder {
  const BrewReducedMotionTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (BrewMotion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Fades [child] through when [index] changes: peers (a shell's tabs) have no
/// direction, so the incoming one fades and settles in place. The child itself
/// is kept, so an `IndexedStack` under it keeps every tab's state. Under
/// reduced motion the switch is instant.
class BrewFadeThrough extends StatefulWidget {
  const BrewFadeThrough({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<BrewFadeThrough> createState() => _BrewFadeThroughState();
}

class _BrewFadeThroughState extends State<BrewFadeThrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BrewMotion.fast,
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: BrewMotion.enter,
  );
  late final Animation<double> _scale = Tween(
    begin: 0.985,
    end: 1.0,
  ).animate(_opacity);

  @override
  void didUpdateWidget(BrewFadeThrough old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (BrewMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}
