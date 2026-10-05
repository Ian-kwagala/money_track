import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'announcements_page.dart';
import 'overview_page.dart';
import 'users_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.user});
  final User user;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _titles = ['Overview', 'Users', 'Announcements'];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OverviewPage(),
      UsersPage(admin: widget.user),
      AnnouncementsPage(admin: widget.user),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('MoneyTrack Admin · ${_titles[_index]}'),
        actions: [
          Center(child: Text(widget.user.email ?? '', style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: Text('Overview')),
              NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Users')),
              NavigationRailDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign), label: Text('Announcements')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_index]),
        ],
      ),
    );
  }
}
