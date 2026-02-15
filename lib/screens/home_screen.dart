import 'package:Watt/screens/main_screens/add_events/events.dart';
import 'package:Watt/screens/main_screens/insights.dart';
import 'package:Watt/screens/main_screens/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,

        backgroundColor: Colors.transparent, // or your chosen solid color
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        forceMaterialTransparency: true,
        title: Stack(
          alignment: Alignment.center,
          children: [
            const Text(
              'Watt',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
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

      // ✅ Keep state between tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: const [_InsightsTab(), _AddEventTab(), ProfileTabBody()],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(
          bottom: 24,
          left: 18,
          right: 18,
          top: 10,
        ),
        child: _GlassBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _onNavTap,
          items: const [
            _NavItemData('assets/icons/insights.svg', 'Insights'),
            _NavItemData('assets/icons/addEvent.svg', 'Add event'),
            _NavItemData('assets/icons/user.svg', 'Profile'),
          ],
        ),
      ),

      // bottomNavigationBar:

      // Container(
      //   height: 60,
      //   margin: const EdgeInsets.only(bottom: 24, left: 30, right: 30, top: 24),
      //   decoration: BoxDecoration(
      //     color: const Color(0xFF354975),
      //     borderRadius: BorderRadius.circular(40),
      //     boxShadow: const [
      //       BoxShadow(
      //         color: Color.fromARGB(
      //           179,
      //           5,
      //           36,
      //           211,
      //         ), // subtle black with opacity
      //         blurRadius: 32,
      //         spreadRadius: 0,
      //         offset: Offset(0, 0), // pushes shadow downward
      //       ),
      //     ],
      //   ),

      //   child: Padding(
      //     padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      //     child: Row(
      //       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      //       children: [
      //         _NavBarItem(
      //           iconPath: 'assets/icons/insights.svg',
      //           label: 'Insights',
      //           selected: _selectedIndex == 0,
      //           onTap: () => _onNavTap(0),
      //         ),
      //         _NavBarItem(
      //           iconPath: 'assets/icons/addEvent.svg',
      //           label: 'Add event',
      //           selected: _selectedIndex == 1,
      //           onTap: () => _onNavTap(1),
      //         ),
      //         _NavBarItem(
      //           iconPath: 'assets/icons/user.svg',
      //           label: 'Profile',
      //           selected: _selectedIndex == 2,
      //           onTap: () => _onNavTap(2),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }
}

class _InsightsTab extends StatelessWidget {
  const _InsightsTab();

  @override
  Widget build(BuildContext context) {
    return InsightsScreen();
  }
}

class _AddEventTab extends StatelessWidget {
  const _AddEventTab();

  @override
  Widget build(BuildContext context) {
    return AddEventsScreen();
  }
}

// class _NavBarItem extends StatelessWidget {
//   final String iconPath;
//   final String label;
//   final bool selected;
//   final VoidCallback onTap;

//   const _NavBarItem({
//     required this.iconPath,
//     required this.label,
//     required this.selected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 50,
//         height: 50,
//         decoration: BoxDecoration(
//           color: Colors.transparent,
//           borderRadius: BorderRadius.circular(40),
//         ),
//         child: Column(
//           children: [
//             SvgPicture.asset(
//               iconPath,
//               height: 30,
//               color: selected ? Colors.amber : Colors.white,
//             ),
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 9,
//                 color: selected ? Colors.amber : Colors.white,
//                 fontWeight: selected ? FontWeight.bold : FontWeight.normal,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class _NavItemData {
  final String iconPath;
  final String label;
  const _NavItemData(this.iconPath, this.label);
}

class _GlassBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItemData> items;

  const _GlassBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  Color _activeColorForIndex(int i) {
    // 0 = Insights, 1 = Add, 2 = Profile
    switch (i) {
      case 0:
        return const Color(0xFFF5D76E); // yellow
      case 1:
        return const Color(0xFF6EE7B7); // green
      case 2:
        return const Color(0xFFC4B5FD); // purple
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),

        // ✅ outer border
        border: Border.all(color: const Color.fromARGB(255, 0, 0, 0), width: 1),

        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 52,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Expanded(
            child: _PillNavItem(
              iconPath: item.iconPath,
              label: item.label,
              selected: i == currentIndex,
              activeColor: _activeColorForIndex(i),
              onTap: () => onTap(i),
            ),
          );
        }),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _PillNavItem({
    required this.iconPath,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? const Color(0xFF1F2937)
        : const Color(0xFF94A3B8);
    final textColor = selected
        ? const Color(0xFF111827)
        : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      splashColor: Colors.black.withOpacity(0.04),
      highlightColor: Colors.black.withOpacity(0.03),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? activeColor.withOpacity(0.55)
                    : Colors.transparent,
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconPath,
                  height: 22,
                  width: 22,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),

            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
