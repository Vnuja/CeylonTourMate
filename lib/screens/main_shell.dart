import 'package:flutter/material.dart';
import '../theme/ceylon_theme.dart';
import 'explore_home_screen.dart';
import 'chat_screen.dart';
import 'albums_screen.dart';
import 'recommendations_screen.dart';
import 'detector_home_screen.dart';
import 'food_identifier_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

/// The single top-level shell for the merged "CeylonTourMate" app.
/// Every screen that used to be its own app's home screen now lives here
/// as one tab, so none of the original feature logic is lost:
///   0. Explore   -> lib1's Explore / AI Plan / Saved home screen
///   1. Chat      -> lib2's AI tour-guide chat assistant
///   2. Albums    -> lib2's photo albums & location identifier
///   3. Discover  -> lib2's signal-based recommendations screen
///   4. Detector  -> lib3's Sinhala harsh/hate speech detector + Food Identifier
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

// ─── Detector Tab (3-in-1: Hate Speech | Food Identifier | History) ───────────

/// Wraps the Detector section with three sub-screens selectable via a
/// custom pill tab-bar in the AppBar:
///   Tab 0 → 🛡️ Hate Speech Detector   (existing DetectorHomeScreen)
///   Tab 1 → 🍛 Food Identifier         (new FoodIdentifierScreen)
///   History is accessible via the history icon in the top-right action.
class _DetectorTab extends StatefulWidget {
  const _DetectorTab();

  @override
  State<_DetectorTab> createState() => _DetectorTabState();
}

class _DetectorTabState extends State<_DetectorTab> {
  /// null = Selection Menu, 0 = Hate Speech, 1 = Food Identifier
  int? _subTab;
  bool _showHistory = false;

  String get _appBarTitle {
    if (_showHistory) return '📋 Detection History';
    if (_subTab == null) return '🔍 Choose Detector';
    return _subTab == 0 ? '🛡️ Hate Speech Detector' : '🍛 Food Identifier';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeylonSpiceTheme.darkBg,
      appBar: AppBar(
        backgroundColor: CeylonSpiceTheme.darkSurface,
        elevation: 0,
        titleSpacing: (_subTab != null || _showHistory) ? 0 : 16,
        leading: (_subTab != null || _showHistory)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: CeylonSpiceTheme.textPrimary),
                onPressed: () {
                  if (_showHistory) {
                    setState(() => _showHistory = false);
                  } else {
                    setState(() => _subTab = null);
                  }
                },
              )
            : null,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _appBarTitle,
            key: ValueKey(_appBarTitle),
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CeylonSpiceTheme.textPrimary,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _showHistory ? 'Back' : 'View history',
            icon: Icon(
              _showHistory
                  ? Icons.close_rounded
                  : Icons.history_outlined,
              color: CeylonSpiceTheme.saffron,
            ),
            onPressed: () => setState(() => _showHistory = !_showHistory),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: CeylonSpiceTheme.saffron.withOpacity(0.5)),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _showHistory
            ? const HistoryScreen(key: ValueKey('history'))
            : _subTab == null
                ? _buildSelectionMenu(key: const ValueKey('selection'))
                : IndexedStack(
                    key: const ValueKey('detector'),
                    index: _subTab!,
                    children: const [
                      DetectorHomeScreen(),
                      FoodIdentifierScreen(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSelectionMenu({Key? key}) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SelectionCard(
              title: 'Hate Speech Detector',
              subtitle: 'Identify offensive or hateful Sinhala text.',
              icon: Icons.shield_rounded,
              color: CeylonSpiceTheme.deepJungle,
              onTap: () => setState(() => _subTab = 0),
            ),
            const SizedBox(height: 24),
            _SelectionCard(
              title: 'Food Identifier',
              subtitle: 'Scan photos of Sri Lankan food for info.',
              icon: Icons.dinner_dining_rounded,
              color: CeylonSpiceTheme.cinnamon,
              onTap: () => setState(() => _subTab = 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Selection Card ────────────────────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: CeylonSpiceTheme.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: color,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: CeylonSpiceTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: CeylonSpiceTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
