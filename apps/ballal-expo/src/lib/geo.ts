/** Drapeau d'un pays à partir de son code ISO (GN → drapeau de la Guinée). */
export function flag(code: string): string {
  if (!/^[A-Z]{2}$/i.test(code)) return '';
  return String.fromCodePoint(...[...code.toUpperCase()].map((c) => 127397 + c.charCodeAt(0)));
}

/** Grandes villes proposées en un toucher ; toute autre ville peut être saisie à la main. */
export const CITIES: Record<string, string[]> = {
  GN: ['Conakry', 'Kankan', 'Nzérékoré', 'Kindia', 'Labé', 'Kamsar', 'Boké', 'Mamou'],
  CD: ['Kinshasa', 'Lubumbashi', 'Mbuji-Mayi', 'Goma', 'Kisangani', 'Bukavu'],
  SN: ['Dakar', 'Thiès', 'Touba', 'Saint-Louis', 'Kaolack', 'Ziguinchor'],
  CI: ['Abidjan', 'Bouaké', 'Yamoussoukro', 'San-Pédro', 'Daloa', 'Korhogo'],
  AO: ['Luanda', 'Huambo', 'Lobito', 'Benguela', 'Lubango'],
  ML: ['Bamako', 'Sikasso', 'Kayes', 'Ségou', 'Mopti'],
  CM: ['Douala', 'Yaoundé', 'Bafoussam', 'Garoua', 'Bamenda'],
  BF: ['Ouagadougou', 'Bobo-Dioulasso', 'Koudougou', 'Banfora'],
  TG: ['Lomé', 'Sokodé', 'Kara', 'Kpalimé'],
  BJ: ['Cotonou', 'Porto-Novo', 'Parakou', 'Abomey-Calavi'],
  GA: ['Libreville', 'Port-Gentil', 'Franceville', 'Oyem'],
  CG: ['Brazzaville', 'Pointe-Noire', 'Dolisie'],
  NG: ['Lagos', 'Abuja', 'Kano', 'Ibadan', 'Port Harcourt'],
  GH: ['Accra', 'Kumasi', 'Tamale', 'Takoradi'],
  NE: ['Niamey', 'Zinder', 'Maradi', 'Agadez'],
  SL: ['Freetown', 'Bo', 'Kenema', 'Makeni'],
  LR: ['Monrovia', 'Gbarnga', 'Buchanan'],
  GM: ['Banjul', 'Serekunda', 'Brikama'],
  GW: ['Bissau', 'Bafatá', 'Gabú'],
  CV: ['Praia', 'Mindelo', 'Santa Maria'],
};
