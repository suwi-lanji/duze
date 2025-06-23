import 'package:flutter/material.dart';
import 'package:duze/shared/widgets/app_colors.dart';
import 'package:duze/shared/widgets/custom_card.dart';
import '../../features/discovery/models/event_model.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;
  final String? distance;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Category Icon + Title + Distance
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(event.category),
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.category,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (distance != null)
                    Text(
                      distance!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              /// Description
              Text(
                event.description,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              /// Time + Location
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: AppColors.iconLight),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(event.startTime),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on, size: 16, color: AppColors.iconLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.address,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// Attendees + Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${event.attendees.length} attending',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'music':
        return Icons.music_note;
      case 'food':
        return Icons.restaurant;
      case 'sports':
        return Icons.sports_soccer;
      case 'business':
        return Icons.business_center;
      case 'education':
        return Icons.school;
      case 'technology':
        return Icons.computer;
      case 'art':
        return Icons.palette;
      case 'party':
        return Icons.celebration;
      default:
        return Icons.event;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = dateTime.difference(now);

    if (diff.inDays > 0) return '${diff.inDays}d from now';
    if (diff.inHours > 0) return '${diff.inHours}h from now';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m from now';
    return 'Now';
  }
}
