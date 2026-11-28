import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { router, type Href } from 'expo-router';
import { useRef, useState, type ComponentRef } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ProTile } from '@/components/ProTile';
import { FadeIn, Pressy, styles } from '@/components/ui';
import { searchPros, type ProCard } from '@/lib/api';
import { bestAnswers, COMPANY, FAQ, looksLikeProSearch, type Faq } from '@/lib/knowledge';
import { useSession } from '@/lib/session';
import { C, F, brandGradient } from '@/lib/theme';

type Msg =
  | { id: string; from: 'me'; text: string }
  | { id: string; from: 'bot'; text: string; links?: { label: string; href: string }[]; pros?: ProCard[]; chips?: string[] };

const SUGGESTIONS = ['Je cherche un plombier', 'Comment avoir le badge vérifié ?', 'Comment sponsoriser mon profil ?', 'Qui a créé Ballal ?', 'C’est quoi Amadou Technology ?', 'Contacter le support'];

let seq = 0;
const nid = () => `m${++seq}`;

/** Assistant Ballal : répond aux questions sur l'application, Amadou Technology et son fondateur, et trouve des pros. */
export default function Assistant() {
  const insets = useSafeAreaInsets();
  const { profile } = useSession();
  const first = (profile?.fullName ?? '').split(' ')[0];
  const [text, setText] = useState('');
  const [typing, setTyping] = useState(false);
  const [msgs, setMsgs] = useState<Msg[]>(() => [
    {
      id: nid(),
      from: 'bot',
      text: `Bonjour${first ? ` ${first}` : ''} ! Je suis l’assistant Ballal. Posez-moi une question sur l’application, ou dites-moi quel professionnel vous cherchez.`,
      chips: SUGGESTIONS,
    },
  ]);
  const list = useRef<ComponentRef<typeof ScrollView>>(null);

  const reply = async (q: string): Promise<Msg> => {
    const answers = bestAnswers(q);
    const trade = looksLikeProSearch(q);
    if (trade && !answers.some((a) => a.id === 'founder' || a.id === 'company')) {
      try {
        const pros = (await searchPros({ query: trade })).slice(0, 3);
        if (pros.length)
          return {
            id: nid(),
            from: 'bot',
            text: `Voici des professionnels pour « ${trade} ». Les profils vérifiés et sponsorisés sont en premier.`,
            pros,
            links: [{ label: `Voir tous les résultats`, href: `/search?q=${encodeURIComponent(trade)}` }],
          };
        return {
          id: nid(),
          from: 'bot',
          text: `Je n’ai pas encore trouvé de professionnel pour « ${trade} » dans votre pays. Essayez un autre mot, ou parcourez les catégories.`,
          links: [{ label: 'Ouvrir la recherche', href: '/search' }],
        };
      } catch {
        /* réseau : on répond avec la FAQ */
      }
    }
    if (answers.length) return toMsg(answers);
    if (/^(bonjour|bonsoir|salut|hello|slt|cc|coucou)\b/i.test(q.trim()))
      return { id: nid(), from: 'bot', text: 'Bonjour ! Comment puis-je vous aider ?', chips: SUGGESTIONS.slice(0, 4) };
    if (/merci/i.test(q)) return { id: nid(), from: 'bot', text: 'Avec plaisir ! Autre chose ?' };
    return {
      id: nid(),
      from: 'bot',
      text: `Je n’ai pas la réponse exacte. Notre équipe peut vous aider directement sur WhatsApp (${COMPANY.phone}).`,
      links: [{ label: 'Écrire au support', href: '/support' }],
      chips: SUGGESTIONS.slice(1, 5),
    };
  };

  const ask = async (q: string) => {
    const v = q.trim();
    if (!v || typing) return;
    setText('');
    setMsgs((m) => [...m, { id: nid(), from: 'me', text: v }]);
    setTyping(true);
    const [r] = await Promise.all([reply(v), new Promise((res) => setTimeout(res, 550))]);
    setTyping(false);
    setMsgs((m) => [...m, r]);
    setTimeout(() => list.current?.scrollToEnd({ animated: true }), 80);
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: '#EEF3FC' }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <LinearGradient colors={brandGradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 14, paddingHorizontal: 12 }}>
        <View style={styles.row}>
          <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color="#fff" />
          </Pressable>
          <View style={{ width: 42, height: 42, borderRadius: 21, backgroundColor: 'rgba(255,255,255,0.18)', alignItems: 'center', justifyContent: 'center', marginLeft: 4 }}>
            <Ionicons name="sparkles" size={20} color="#fff" />
          </View>
          <View style={{ marginLeft: 10 }}>
            <Text style={{ fontFamily: F.heavy, color: '#fff', fontSize: 17 }}>Assistant Ballal</Text>
            <Text style={{ fontFamily: F.medium, color: 'rgba(255,255,255,0.8)', fontSize: 12.5 }}>Répond en quelques secondes</Text>
          </View>
        </View>
      </LinearGradient>

      <ScrollView ref={list} contentContainerStyle={{ padding: 14, gap: 10 }} onContentSizeChange={() => list.current?.scrollToEnd({ animated: true })}>
        {msgs.map((m) => (
          <FadeIn key={m.id} style={{ alignItems: m.from === 'me' ? 'flex-end' : 'flex-start', gap: 8 }}>
            <View
              style={{
                maxWidth: '86%',
                backgroundColor: m.from === 'me' ? C.primary : '#fff',
                paddingHorizontal: 14,
                paddingVertical: 10,
                borderRadius: 20,
                borderBottomRightRadius: m.from === 'me' ? 6 : 20,
                borderBottomLeftRadius: m.from === 'me' ? 20 : 6,
              }}>
              <Text style={{ fontFamily: F.medium, fontSize: 14.5, lineHeight: 21, color: m.from === 'me' ? '#fff' : C.text }}>{m.text}</Text>
            </View>
            {m.from === 'bot' && m.pros?.length ? (
              <View style={{ width: '100%', gap: 8 }}>
                {m.pros.map((p, i) => (
                  <ProTile key={p.id} pro={p} index={i} compact />
                ))}
              </View>
            ) : null}
            {m.from === 'bot' && m.links?.length ? (
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                {m.links.map((l) => (
                  <Pressy key={l.href} onPress={() => router.push(l.href as Href)} style={[styles.row, { backgroundColor: C.primarySoft, paddingHorizontal: 12, paddingVertical: 8, borderRadius: 999 }]}>
                    <Text style={{ fontFamily: F.bold, color: C.primary, fontSize: 13 }}>{l.label}</Text>
                    <Ionicons name="arrow-forward" size={14} color={C.primary} style={{ marginLeft: 4 }} />
                  </Pressy>
                ))}
              </View>
            ) : null}
            {m.from === 'bot' && m.chips?.length ? (
              <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
                {m.chips.map((c) => (
                  <Pressy key={c} onPress={() => ask(c)} style={{ backgroundColor: '#fff', borderWidth: 1, borderColor: C.border, paddingHorizontal: 12, paddingVertical: 8, borderRadius: 999 }}>
                    <Text style={{ fontFamily: F.semibold, color: C.text, fontSize: 13 }}>{c}</Text>
                  </Pressy>
                ))}
              </View>
            ) : null}
          </FadeIn>
        ))}
        {typing ? (
          <FadeIn style={{ alignSelf: 'flex-start', backgroundColor: '#fff', paddingHorizontal: 16, paddingVertical: 12, borderRadius: 20, borderBottomLeftRadius: 6 }}>
            <Text style={{ fontFamily: F.bold, color: C.muted, letterSpacing: 3 }}>•••</Text>
          </FadeIn>
        ) : null}
      </ScrollView>

      <View style={[styles.row, { padding: 10, paddingBottom: insets.bottom + 10, backgroundColor: '#fff', gap: 8 }]}>
        <TextInput
          value={text}
          onChangeText={setText}
          placeholder="Posez votre question…"
          placeholderTextColor={C.muted}
          onSubmitEditing={() => ask(text)}
          returnKeyType="send"
          maxLength={300}
          style={{ flex: 1, backgroundColor: C.field, borderRadius: 24, paddingHorizontal: 16, height: 48, fontFamily: F.medium, fontSize: 15, color: C.text }}
        />
        <Pressy onPress={() => ask(text)} style={{ width: 48, height: 48, borderRadius: 24, backgroundColor: text.trim() ? C.primary : C.border, alignItems: 'center', justifyContent: 'center' }}>
          <Ionicons name="arrow-up" size={22} color="#fff" />
        </Pressy>
      </View>
    </KeyboardAvoidingView>
  );
}

function toMsg(answers: Faq[]): Msg {
  const [a, b] = answers;
  const links = answers.map((x) => x.link).filter((l): l is { label: string; href: string } => !!l);
  return {
    id: nid(),
    from: 'bot',
    text: a.a,
    links: links.slice(0, 2),
    chips: b ? [b.q] : FAQ.filter((f) => f.id !== a.id).slice(0, 2).map((f) => f.q),
  };
}
