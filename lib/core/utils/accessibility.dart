import 'package:flutter/material.dart';

/// Respects the user's reduced-motion preference (`Settings > Accessibility
/// > Reduce Motion` on iOS, the matching Android/OS setting, or
/// `prefers-reduced-motion` on web) by collapsing an animation's duration to
/// zero instead of skipping the animation code path entirely — simpler than
/// branching every animated widget, and the end state is identical either
/// way.
extension MotionDurationX on BuildContext {
  Duration motionDuration(Duration duration) {
    return MediaQuery.of(this).disableAnimations ? Duration.zero : duration;
  }
}
