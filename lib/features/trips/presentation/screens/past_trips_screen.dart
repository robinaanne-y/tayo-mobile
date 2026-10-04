import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/networking/api_exception.dart';
import '../../../../core/theme/app_color_tokens.dart';
import '../../domain/trip.dart';
import '../providers/trip_providers.dart';
import 'trip_detail_screen.dart';

/// A grid gallery of trips that have already happened -- each tile is a
/// thumbnail (or a placeholder when none was uploaded) with the trip's
/// title and year underneath, matching the "family photo album" framing
/// of a past-trips page rather than the Trips screen's upcoming list.
class PastTripsScreen extends ConsumerWidget {
  const PastTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(currentHouseholdPastTripsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Past Trips')),
      body: SafeArea(
        child: tripsAsync.when(
          data: (trips) {
            if (trips.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No past trips yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: trips.length,
              itemBuilder: (context, index) => _PastTripTile(trip: trips[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(error is ApiException ? error.message : 'Something went wrong.'),
          ),
        ),
      ),
    );
  }
}

class _PastTripTile extends StatelessWidget {
  const _PastTripTile({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: trip.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                image: trip.thumbnailUrl != null
                    ? DecorationImage(image: NetworkImage(trip.thumbnailUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: trip.thumbnailUrl == null
                  ? Center(child: Icon(LucideIcons.images, size: 28, color: context.colors.primary))
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trip.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            '${trip.startAt.year}',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
