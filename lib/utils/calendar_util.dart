import '../models/session_model.dart';

Map<DateTime, bool> buildAvailabilityMap(
  List<Session> sessions,
) {
  final Map<DateTime, bool> availability = {};

  for (final session in sessions) {
    final dateKey = DateTime(
      session.startsAt.year,
      session.startsAt.month,
      session.startsAt.day,
    );

    final hasSpace = !session.isFull;

    if (!availability.containsKey(dateKey)) {
      availability[dateKey] = hasSpace;
    } else {
      availability[dateKey] = availability[dateKey]! || hasSpace;
    }
  }

  return availability;
}
