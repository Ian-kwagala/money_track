import 'package:flutter/material.dart';

import '../services.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'announcements_page.dart';
import 'change_password_dialog.dart';
import 'overview_page.dart';
import 'user_detail_page.dart';
import 'users_page.dart';

/// The signed-in frame: a navy sidebar (a drawer on narrow screens) with
/// the sections and the admin's account menu, and the page on the right.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.account});
  final AdminAccount account;

  static const wideBreakpoint = 1000.0;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _Section {
  const _Section(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _AdminShellState extends State<AdminShell> {
  static const _sections = [
    _Section('Overview', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
    _Section('Users', Icons.group_outlined, Icons.group_rounded),
    _Section('Announcements', Icons.campaign_outlined, Icons.campaign_rounded),
  ];

  var _index = 0;

  /// The user open under Users, if any.
  String? _openUid;

  final _scaffold = GlobalKey<ScaffoldState>();

  void _go(int index) {
    setState(() {
      _index = index;
      _openUid = null;
    });
    if (_scaffold.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
  }

  void _openUser(String uid) => setState(() {
        _index = 1;
        _openUid = uid;
      });

  Future<void> _changePassword() async {
    final changed = await ChangePasswordDialog.show(context, email: widget.account.email);
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed.')));
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You\'ll need your email and password to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true && mounted) await AdminServices.of(context).auth.signOut();
  }

  Widget _page() {
    final uid = _openUid;
    if (_index == 1 && uid != null) {
      return UserDetailPage(
        key: ValueKey(uid),
        uid: uid,
        admin: widget.account,
        onBack: () => setState(() => _openUid = null),
      );
    }
    return switch (_index) {
      0 => OverviewPage(onOpenUser: _openUser, onSeeAllUsers: () => _go(1)),
      1 => UsersPage(onOpenUser: _openUser),
      _ => AnnouncementsPage(admin: widget.account),
    };
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AdminShell.wideBreakpoint;
    final sidebar = _Sidebar(
      sections: _sections,
      index: _index,
      onSelect: _go,
      account: widget.account,
      projectId: AdminServices.of(context).projectId,
      onChangePassword: _changePassword,
      onSignOut: _signOut,
    );
    final content = SelectionArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: KeyedSubtree(key: ValueKey('$_index/$_openUid'), child: _page()),
        ),
      ),
    );

    return Scaffold(
      key: _scaffold,
      drawer: wide ? null : Drawer(width: 272, backgroundColor: AdminColors.navy, child: sidebar),
      appBar: wide
          ? null
          : AppBar(
              backgroundColor: AdminColors.navy,
              foregroundColor: Colors.white,
              title: Row(children: [
                const BrandMark(size: 28),
                const SizedBox(width: 10),
                Text(_sections[_index].label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ),
      body: wide ? Row(children: [SizedBox(width: 256, child: sidebar), Expanded(child: content)]) : content,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.sections,
    required this.index,
    required this.onSelect,
    required this.account,
    required this.projectId,
    required this.onChangePassword,
    required this.onSignOut,
  });

  final List<_Section> sections;
  final int index;
  final ValueChanged<int> onSelect;
  final AdminAccount account;
  final String projectId;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminColors.navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Row(
                children: [
                  BrandMark(size: 36),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MoneyTrack',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                      Text('Admin console', style: TextStyle(color: AdminColors.navyText, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('MENU',
                  style: TextStyle(color: AdminColors.navyText, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
            ),
            for (final (i, s) in sections.indexed)
              _NavItem(section: s, selected: i == index, onTap: () => onSelect(i)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Live · $projectId',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AdminColors.navyText, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Divider(color: AdminColors.navyLine, height: 1),
            _AccountMenu(account: account, onChangePassword: onChangePassword, onSignOut: onSignOut),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.section, required this.selected, required this.onTap});
  final _Section section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AdminColors.navyText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AdminColors.navyRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(selected ? section.selectedIcon : section.icon, size: 20, color: selected ? AdminColors.amber : color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(section.label,
                      style: TextStyle(color: color, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AdminColors.amber, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AccountAction { changePassword, signOut }

/// The signed-in admin at the foot of the sidebar; tap for the menu.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.account, required this.onChangePassword, required this.onSignOut});
  final AdminAccount account;
  final VoidCallback onChangePassword;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      tooltip: 'Account',
      offset: const Offset(12, -128),
      onSelected: (a) => switch (a) {
        _AccountAction.changePassword => onChangePassword(),
        _AccountAction.signOut => onSignOut(),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _AccountAction.changePassword,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.key_rounded, size: 20),
            title: Text('Change password'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _AccountAction.signOut,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded, size: 20, color: AdminColors.danger),
            title: Text('Sign out', style: TextStyle(color: AdminColors.danger)),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        child: Row(
          children: [
            InitialsAvatar(name: account.email, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const Text('Administrator', style: TextStyle(color: AdminColors.navyText, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.unfold_more_rounded, color: AdminColors.navyText, size: 20),
          ],
        ),
      ),
    );
  }
}
