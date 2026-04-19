// CeylonTourMate — Sri Lanka-inspired color palette
export const Colors = {
  // Primary palette — Deep tropical greens & gold
  primary: {
    deepGreen: '#1A2E1A',
    green: '#1D9E75',
    lightGreen: '#2ED89C',
    gold: '#C9A84C',
    lightGold: '#E8D5A0',
  },

  // Accent
  accent: {
    teal: '#1D9E75',
    coral: '#E85D4A',
    amber: '#F5A623',
    indigo: '#5B6ABF',
  },

  // Backgrounds
  background: {
    primary: '#0D1117',
    secondary: '#161B22',
    tertiary: '#21262D',
    card: '#1C2333',
    elevated: '#242D3D',
  },

  // Text
  text: {
    primary: '#F0F6FC',
    secondary: '#8B949E',
    tertiary: '#6E7681',
    inverse: '#0D1117',
    accent: '#1D9E75',
  },

  // Status colors
  status: {
    safe: '#2ED89C',
    warning: '#F5A623',
    danger: '#E85D4A',
    info: '#5B9BD5',
  },

  // Alert severity
  alert: {
    safe: { bg: 'rgba(46, 216, 156, 0.12)', border: '#2ED89C', text: '#2ED89C' },
    warning: { bg: 'rgba(245, 166, 35, 0.12)', border: '#F5A623', text: '#F5A623' },
    danger: { bg: 'rgba(232, 93, 74, 0.12)', border: '#E85D4A', text: '#E85D4A' },
  },

  // Borders
  border: {
    default: '#30363D',
    strong: '#484F58',
    subtle: '#21262D',
  },

  // Gradients (as arrays for LinearGradient)
  gradients: {
    primary: ['#1A2E1A', '#1D9E75'],
    gold: ['#C9A84C', '#E8D5A0'],
    danger: ['#E85D4A', '#C93434'],
    dark: ['#0D1117', '#161B22'],
    card: ['#1C2333', '#242D3D'],
  },

  // Overlay
  overlay: 'rgba(0, 0, 0, 0.65)',
  transparent: 'transparent',
  white: '#FFFFFF',
  black: '#000000',
} as const;

export type ColorTheme = typeof Colors;
