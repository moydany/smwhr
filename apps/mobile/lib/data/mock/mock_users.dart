import '../models/user.dart';

/// Founder + 8 fictional LATAM users for the mock layer.
///
/// `mockCurrentUser` is the source of truth for "logged in as @moi".
final User mockCurrentUser = User(
  id: 'user-moi-001',
  handle: 'moi',
  displayName: 'Moi',
  email: 'moi@orbit-m.dev',
  avatarUrl: null,
  bio: 'Founder. Maker. Sometimes lost in concerts.',
  city: 'Tulancingo',
  countryCode: 'MX',
  interests: const ['music', 'sports', 'outdoor'],
  language: 'es',
  onboardingCompletedAt: DateTime(2026, 4, 22),
  createdAt: DateTime(2026, 4, 1),
  questsCount: 23,
  venuesCount: 8,
  artistsCount: 14,
);

/// Brand new user (post-OAuth, pre-onboarding). Used by the mock auth
/// repository when simulating a fresh signup.
final User mockNewUser = User(
  id: 'user-new-001',
  handle: '',
  displayName: '',
  email: 'new@example.com',
  city: '',
  countryCode: 'MX',
  interests: const [],
  language: 'es',
  onboardingCompletedAt: null,
  createdAt: DateTime.now(),
);

final List<User> mockOtherUsers = [
  User(
    id: 'user-002',
    handle: 'sofia',
    displayName: 'Sofía Cárdenas',
    city: 'Ciudad de México',
    countryCode: 'MX',
    interests: const ['music', 'festivals'],
    language: 'es',
    onboardingCompletedAt: DateTime(2026, 3, 15),
    createdAt: DateTime(2026, 3, 1),
    questsCount: 41,
    venuesCount: 14,
    artistsCount: 28,
    bio: 'Si toca, voy.',
  ),
  User(
    id: 'user-003',
    handle: 'carlos',
    displayName: 'Carlos Reyes',
    city: 'Monterrey',
    countryCode: 'MX',
    interests: const ['sports', 'music'],
    language: 'es',
    onboardingCompletedAt: DateTime(2026, 2, 20),
    createdAt: DateTime(2026, 2, 10),
    questsCount: 18,
    venuesCount: 6,
    artistsCount: 9,
  ),
  User(
    id: 'user-004',
    handle: 'andrea',
    displayName: 'Andrea Ruiz',
    city: 'Guadalajara',
    countryCode: 'MX',
    interests: const ['festivals', 'culture'],
    language: 'es',
    onboardingCompletedAt: DateTime(2026, 4, 5),
    createdAt: DateTime(2026, 4, 1),
    questsCount: 7,
    venuesCount: 5,
    artistsCount: 6,
  ),
  User(
    id: 'user-005',
    handle: 'beto',
    displayName: 'Beto Salazar',
    city: 'Ciudad de México',
    countryCode: 'MX',
    interests: const ['music'],
    language: 'es',
    onboardingCompletedAt: DateTime(2026, 1, 11),
    createdAt: DateTime(2026, 1, 1),
    questsCount: 52,
    venuesCount: 19,
    artistsCount: 33,
    bio: 'BTS Army desde 2015.',
  ),
  User(
    id: 'user-006',
    handle: 'lucia',
    displayName: 'Lucía Torres',
    city: 'Bogotá',
    countryCode: 'CO',
    interests: const ['outdoor', 'culture'],
    language: 'es',
    onboardingCompletedAt: DateTime(2026, 3, 30),
    createdAt: DateTime(2026, 3, 20),
    questsCount: 12,
    venuesCount: 9,
    artistsCount: 4,
  ),
  User(
    id: 'user-007',
    handle: 'diego',
    displayName: 'Diego Aguilar',
    city: 'Buenos Aires',
    countryCode: 'AR',
    interests: const ['sports', 'festivals'],
    language: 'es',
    onboardingCompletedAt: DateTime(2026, 2, 14),
    createdAt: DateTime(2026, 2, 1),
    questsCount: 27,
    venuesCount: 11,
    artistsCount: 14,
  ),
  User(
    id: 'user-008',
    handle: 'ximena',
    displayName: 'Ximena Vargas',
    city: 'Lima',
    countryCode: 'PE',
    interests: const ['music', 'culture'],
    language: 'es',
    onboardingCompletedAt: DateTime(2026, 4, 10),
    createdAt: DateTime(2026, 4, 5),
    questsCount: 5,
    venuesCount: 4,
    artistsCount: 3,
  ),
  User(
    id: 'user-009',
    handle: 'paula',
    displayName: 'Paula Hernández',
    city: 'Santiago',
    countryCode: 'CL',
    interests: const ['outdoor', 'sports'],
    language: 'es',
    onboardingCompletedAt: DateTime(2026, 3, 1),
    createdAt: DateTime(2026, 2, 25),
    questsCount: 16,
    venuesCount: 8,
    artistsCount: 7,
  ),
];

/// Reserved handles the mock auth repo rejects during onboarding.
const List<String> reservedHandles = [
  'admin', 'smwhr', 'support', 'help', 'official', 'staff',
  'team', 'api', 'root', 'test', 'demo', 'example', 'user',
  'moi', // founder reservation
];

/// Single lookup table used by the mock repos.
final Map<String, User> mockUsersById = {
  mockCurrentUser.id: mockCurrentUser,
  for (final u in mockOtherUsers) u.id: u,
};

final Map<String, User> mockUsersByHandle = {
  mockCurrentUser.handle: mockCurrentUser,
  for (final u in mockOtherUsers) u.handle: u,
};
