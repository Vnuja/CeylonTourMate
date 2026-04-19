// CeylonTourMate — 4px grid spacing + layout constants
export const Spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  '2xl': 24,
  '3xl': 32,
  '4xl': 40,
  '5xl': 48,
  '6xl': 64,
} as const;

export const BorderRadius = {
  sm: 6,
  md: 10,
  lg: 14,
  xl: 20,
  full: 999,
} as const;

export const Layout = {
  screenPadding: 16,
  cardPadding: 16,
  sectionGap: 24,
  headerHeight: 56,
  tabBarHeight: 64,
  mapHeightRatio: 0.55, // 55% of screen for map
} as const;
