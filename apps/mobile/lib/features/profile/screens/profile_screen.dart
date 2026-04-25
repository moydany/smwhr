import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  /// Null = current user.
  final String? handle;
  const ProfileScreen({super.key, this.handle});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        route: handle == null ? '/profile' : '/profile/$handle',
        session: 'session 10 · profile + collection',
        notes: const [
          'profile stats (quests / venues / artists)',
          'collection grid pulled from BadgesRepository.listMyBadges',
          'tap badge → /badge/:badgeId',
        ],
      );
}
