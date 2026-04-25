import '../models/event.dart';
import 'mock_users.dart';

/// @moi already RSVP'd to all 3 BTS nights and the Corona Capital festival.
final List<Intent> mockSeededIntents = [
  Intent(
    id: 'int-001',
    eventId: 'evt-bts-mx-n1',
    userId: mockCurrentUser.id,
    createdAt: DateTime(2026, 4, 18, 22, 14),
  ),
  Intent(
    id: 'int-002',
    eventId: 'evt-bts-mx-n2',
    userId: mockCurrentUser.id,
    createdAt: DateTime(2026, 4, 18, 22, 14),
  ),
  Intent(
    id: 'int-003',
    eventId: 'evt-bts-mx-n3',
    userId: mockCurrentUser.id,
    createdAt: DateTime(2026, 4, 18, 22, 15),
  ),
  Intent(
    id: 'int-004',
    eventId: 'evt-corona-capital',
    userId: mockCurrentUser.id,
    createdAt: DateTime(2026, 4, 20, 11, 0),
  ),
];
