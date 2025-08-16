import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:setup/screens/main_screens/add_events.dart';
import 'package:setup/screens/main_screens/insights.dart';
import 'package:setup/screens/main_screens/user_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Lazy build pages instead of pre-building them.
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const InsightsScreen();
      case 1:
        return const AddEventsScreen();
      case 2:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              'Setup',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 15.0),
                child: SvgPicture.asset('assets/icons/logo.svg', height: 30),
              ),
            ),
          ],
        ),
      ),
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: Container(
        height: 60,
        margin: const EdgeInsets.only(bottom: 24, left: 30, right: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF354975),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBarItem(
                iconPath: 'assets/icons/insights.svg',
                label: 'Insights',
                selected: _selectedIndex == 0,
                onTap: () => _onNavTap(0),
              ),
              _NavBarItem(
                iconPath: 'assets/icons/addEvent.svg',
                label: 'Add event',
                selected: _selectedIndex == 1,
                onTap: () => _onNavTap(1),
              ),
              _NavBarItem(
                iconPath: 'assets/icons/user.svg',
                label: 'Profile',
                selected: _selectedIndex == 2,
                onTap: () => _onNavTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.iconPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              iconPath,
              height: 30,
              color: selected ? Colors.amber : Colors.white,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: selected ? Colors.amber : Colors.white,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
