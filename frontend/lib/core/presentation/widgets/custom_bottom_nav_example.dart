import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Alternative Implementation using Flutter's BottomNavigationBar
/// This version uses the built-in BottomNavigationBar with custom theming
/// to prevent overflow issues and ensure proper SafeArea handling.

class CustomBottomNavigationExample extends StatefulWidget {
  const CustomBottomNavigationExample({super.key});

  @override
  State<CustomBottomNavigationExample> createState() => _CustomBottomNavigationExampleState();
}

class _CustomBottomNavigationExampleState extends State<CustomBottomNavigationExample> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const Center(child: Text('Home Screen', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Study Screen', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Saved Screen', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Settings Screen', style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
    );

  Widget _buildCustomBottomNavigationBar() => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Theme(
          data: Theme.of(context).copyWith(
            // Remove splash color to prevent animations
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF1E1E1E),
            elevation: 0,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFF6A4FB6),
            unselectedItemColor: const Color(0xFF5E5E5E),
            selectedLabelStyle: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 20),
                activeIcon: Icon(Icons.home, size: 20),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.edit_note_outlined, size: 20),
                activeIcon: Icon(Icons.edit_note, size: 20),
                label: 'Study',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bookmark_outline, size: 20),
                activeIcon: Icon(Icons.bookmark, size: 20),
                label: 'Saved',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined, size: 20),
                activeIcon: Icon(Icons.settings, size: 20),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedIndex = index;
      });
    }
  }
}

/// Complete Solution for App Shell with Fixed Bottom Navigation
/// This implementation addresses all the requirements:
/// ✅ No overflow issues
/// ✅ Dark background (#1E1E1E)
/// ✅ Correct theme colors
/// ✅ Rounded top corners
/// ✅ No unnecessary padding
/// ✅ No swipe animations
/// ✅ Proper SafeArea usage

class FixedAppShell extends StatefulWidget {
  const FixedAppShell({super.key});

  @override
  State<FixedAppShell> createState() => _FixedAppShellState();
}

class _FixedAppShellState extends State<FixedAppShell> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const Center(child: Text('Home Screen', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Study Screen', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Saved Screen', style: TextStyle(color: Colors.white))),
    const Center(child: Text('Settings Screen', style: TextStyle(color: Colors.white))),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );

  Widget _buildBottomNavigationBar() => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SizedBox(
            height: 60, // Fixed height to prevent overflow
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.edit_note_outlined, Icons.edit_note, 'Study'),
                _buildNavItem(2, Icons.bookmark_outline, Icons.bookmark, 'Saved'),
                _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _selectedIndex == index;
    const activeColor = Color(0xFF6A4FB6);
    const inactiveColor = Color(0xFF5E5E5E);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(12),
          splashColor: activeColor.withOpacity(0.1),
          highlightColor: activeColor.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? activeColor.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 18,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedIndex = index;
      });
    }
  }
}

/// Usage Instructions:
/// 
/// 1. Replace your existing AppShell with FixedAppShell
/// 2. The implementation uses IndexedStack to prevent swipe animations
/// 3. Fixed height (60px) prevents overflow issues
/// 4. SafeArea with top: false prevents extra padding
/// 5. ClipRRect with borderRadius creates rounded corners
/// 6. Container decoration provides shadow and background color
/// 
/// Key Benefits:
/// ✅ No 13-pixel overflow
/// ✅ Dark theme (#1E1E1E background)
/// ✅ Proper theme colors (Active: #6A4FB6, Inactive: #5E5E5E)
/// ✅ Rounded top corners (20px radius)
/// ✅ No unnecessary padding or margins
/// ✅ No swipe animations
/// ✅ Proper SafeArea usage
/// ✅ Accessibility support
/// ✅ Haptic feedback