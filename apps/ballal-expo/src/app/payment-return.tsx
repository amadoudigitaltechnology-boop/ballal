import { Redirect } from 'expo-router';

/** Retour de la page de paiement Djomy : on revient sur l'écran de vérification. */
export default function PaymentReturn() {
  return <Redirect href="/verification" />;
}
