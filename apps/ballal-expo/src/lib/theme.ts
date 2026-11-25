/** Palette et typographie BALLAL (identiques à l'application Flutter). */
export const C = {
  primary: '#1A56DB',
  primaryDark: '#0B2A6F',
  primarySoft: '#E8F0FF',
  accent: '#FF7A1A',
  accentSoft: '#FFF1E6',
  bg: '#F3F6FD',
  field: '#F0F3F9',
  white: '#FFFFFF',
  text: '#0F172A',
  muted: '#64748B',
  border: '#E2E8F0',
  success: '#16A34A',
  danger: '#DC2626',
  star: '#F5A623',
} as const;

export const brandGradient = ['#2F6BFF', '#1A56DB', '#0B2A6F'] as const;

export const F = {
  display: 'Sora-700',
  displayHeavy: 'Sora-800',
  body: 'Jakarta-400',
  medium: 'Jakarta-500',
  semibold: 'Jakarta-600',
  bold: 'Jakarta-700',
  heavy: 'Jakarta-800',
} as const;

export const fontAssets = {
  'Sora-400': require('../../assets/fonts/Sora-400.ttf'),
  'Sora-600': require('../../assets/fonts/Sora-600.ttf'),
  'Sora-700': require('../../assets/fonts/Sora-700.ttf'),
  'Sora-800': require('../../assets/fonts/Sora-800.ttf'),
  'Jakarta-400': require('../../assets/fonts/PlusJakartaSans-400.ttf'),
  'Jakarta-500': require('../../assets/fonts/PlusJakartaSans-500.ttf'),
  'Jakarta-600': require('../../assets/fonts/PlusJakartaSans-600.ttf'),
  'Jakarta-700': require('../../assets/fonts/PlusJakartaSans-700.ttf'),
  'Jakarta-800': require('../../assets/fonts/PlusJakartaSans-800.ttf'),
};

export const radius = 20;

export const shadow = {
  shadowColor: '#1A56DB',
  shadowOpacity: 0.08,
  shadowRadius: 14,
  shadowOffset: { width: 0, height: 6 },
  elevation: 3,
} as const;

export const people = {
  woman_phone: require('../../assets/people/woman_phone.png'),
  business: require('../../assets/people/business.png'),
  plumber: require('../../assets/people/plumber.png'),
  builder: require('../../assets/people/builder.png'),
  beauty: require('../../assets/people/beauty.png'),
  chef: require('../../assets/people/chef.png'),
  doctor: require('../../assets/people/doctor.png'),
  delivery: require('../../assets/people/delivery.png'),
};

export const logo = require('../../assets/logo_ballal.png');
