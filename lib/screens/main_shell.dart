import 'package:flutter/material.dart';
import '../theme/ceylon_theme.dart';
import 'explore_home_screen.dart';
import 'chat_screen.dart';
import 'albums_screen.dart';
import 'recommendations_screen.dart';
import 'detector_home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

/// The single top-level shell for the merged "Ceylon Travel Planner" app.
/// Every screen that used to be its own app's home screen now lives here
/// as one tab, so none of the original feature logic is lost:
///   0. Explore   -> lib1's Explore / AI Plan / Saved home screen
///   1. Chat      -> lib2's AI tour-guide chat assistant
///   2. Albums    -> lib2's photo albums & location identifier
///   3. Discover  -> lib2's signal-based recommendations screen
///   4. Detector  -> lib3's Sinhala harsh/hate speech detector
///   5. Profile   -> shared profile screen
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    ExploreHomeScreen(),
    ChatScreen(),
    AlbumsScreen(),
    RecommendationsScreen(),
    _DetectorTab(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: CeylonSpiceTheme.darkSurface,
          border: Border(
            top: BorderSide(color: CeylonSpiceTheme.saffron.withOpacity(0.12)),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          selectedItemColor: CeylonSpiceTheme.saffron,
          unselectedItemColor: CeylonSpiceTheme.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_album_outlined),
              activeIcon: Icon(Icons.photo_album),
              label: 'Albums',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.travel_explore_outlined),
              activeIcon: Icon(Icons.travel_explore),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield),
              label: 'Detector',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Small wrapper so the Sinhala Harsh-Word Detector keeps its own
/// "Detector / History" pair of screens (exactly like lib3's original
/// MainShell) without needing a 7th bottom-nav tab.
class _DetectorTab extends StatefulWidget {
  const _DetectorTab();

  @override
  State<_DetectorTab> createState() => _DetectorTabState();
}

class _DetectorTabState extends State<_DetectorTab> {
  int _detectorIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CeylonSpiceTheme.deepJungle,
        title: Text(_detectorIndex == 0 ? '🛡️ Harsh Word Detector' : '📋 Detection History'),
        actions: [
          IconButton(
            tooltip: _detectorIndex == 0 ? 'View history' : 'Back to detector',
            icon: Icon(_detectorIndex == 0 ? Icons.history_outlined : Icons.shield_outlined),
            onPressed: () => setState(() => _detectorIndex = _detectorIndex == 0 ? 1 : 0),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: CeylonSpiceTheme.saffron),
        ),
      ),
      body: IndexedStack(
        index: _detectorIndex,
        children: const [
          DetectorHomeScreen(),
          HistoryScreen(),
        ],
      ),
    );
  }
}
