import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_colors.dart';
import '../../features/calendar/domain/event.dart';
import 'member_avatar.dart';

/// Overlapping avatars for an event's participants, each ringed in the
/// surrounding surface color so stacked avatars read as distinct circles
/// instead of showing through each other's semi-transparent fill (every
/// [MemberAvatar] has a tinted, non-opaque background by design). Once
/// there are more than [maxShown] participants, the remainder collapses
/// into a single "+N" circle instead of silently being dropped.
class ParticipantAvatarStack extends StatelessWidget {
  const ParticipantAvatarStack({
    super.key,
    required this.participants,
    required this.colorForMember,
    this.size = 22,
    this.maxShown = 3,
  });

  final List<EventParticipant> participants;
  final Map<int, Color> colorForMember;
  final double size;
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    final shown = participants.take(maxShown).toList();
    final overflow = participants.length - shown.length;
    final overlap = size * 0.65;
    final slotCount = shown.length + (overflow > 0 ? 1 : 0);

    return SizedBox(
      height: size,
      width: size + (slotCount - 1) * overlap,
      child: Stack(
        children: [
          for (final entry in shown.asMap().entries)
            Positioned(
              left: entry.key * overlap,
              child: _ring(
                context,
                MemberAvatar(
                  name: entry.value.name,
                  colorIndex: AppColors.memberPalette.indexOf(
                    colorForMember[entry.value.id] ?? AppColors.memberPalette.first,
                  ),
                  avatarUrl: entry.value.avatarUrl,
                  size: size,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: shown.length * overlap,
              child: _ring(
                context,
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.colors.border, shape: BoxShape.circle),
                  child: Text(
                    '+$overflow',
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ring(BuildContext context, Widget child) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: context.colors.surface, shape: BoxShape.circle),
      child: child,
    );
  }
}
