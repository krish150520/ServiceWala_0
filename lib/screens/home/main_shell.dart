import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:service_wala_business/config/theme.dart';
import 'package:service_wala_business/providers/app_state.dart';
import 'package:service_wala_business/screens/home/home_screen.dart';
import 'package:service_wala_business/screens/jobs/jobs_screen.dart';
import 'package:service_wala_business/screens/chat/chat_list_screen.dart';
import 'package:service_wala_business/screens/profile/profile_screen.dart';
import 'package:service_wala_business/widgets/common_widgets.dart';

/// Main shell with redesigned floating bottom navigation bar matching the reference:
/// Soft outer light-colored dock, floating white inner surface, and dark elongated pill for selected tab.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    JobsScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  static const int _tabCount = 4;

  static const List<String> _labels = [
    'Home',
    'Jobs',
    'Chats',
    'Profile',
  ];

  static const List<IconData> _unselectedIcons = [
    Icons.home_outlined,
    Icons.work_outline_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.person_outline_rounded,
  ];

  static const List<IconData> _selectedIcons = [
    Icons.home_outlined,
    Icons.work_outline_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.person_outline_rounded,
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    // Auto-fetch latest bookings and updates whenever switching tabs
    context.read<AppState>().refreshBookings();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (appState.isDemoMode) const DemoModeBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  _tabCount,
                  (index) => _buildNavItem(index, appState),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, AppState appState) {
    final bool isSelected = index == _currentIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconWithBadge(index, isSelected, appState),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.centerLeft,
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          _labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconWithBadge(int index, bool isSelected, AppState appState) {
    final IconData iconData =
        isSelected ? _selectedIcons[index] : _unselectedIcons[index];
    final Color iconColor = isSelected ? Colors.white : AppColors.primary;

    Widget iconWidget = Icon(iconData, color: iconColor, size: isSelected ? 22 : 24);

    int badgeCount = 0;
    Color badgeColor = isSelected ? Colors.white : AppColors.error;
    Color badgeTextColor = isSelected ? AppColors.primary : Colors.white;

    if (index == 1 && appState.activeBookings.isNotEmpty) {
      badgeCount = appState.activeBookings.length;
      if (!isSelected) badgeColor = AppColors.primary;
    } else if (index == 2 && appState.totalUnreadCount > 0) {
      badgeCount = appState.totalUnreadCount;
      if (!isSelected) badgeColor = AppColors.error;
    }

    if (badgeCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.white,
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return iconWidget;
  }
}
