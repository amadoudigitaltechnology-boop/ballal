import { Ionicons } from '@expo/vector-icons';
import { RecordingPresets, requestRecordingPermissionsAsync, setAudioModeAsync, useAudioPlayer, useAudioPlayerStatus, useAudioRecorder, useAudioRecorderState } from 'expo-audio';
import * as Crypto from 'expo-crypto';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Alert, Animated, FlatList, KeyboardAvoidingView, Pressable, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { ProPhoto } from '@/components/ProTile';
import { Pressy, styles, tap } from '@/components/ui';
import { clock, conversations, sendAudio, dayLabel, loadMessages, markRead, sendText, signedAttachment, toMessage, type ChatMessage } from '@/lib/api';
import { gnf, marketPhoto } from '@/lib/market';
import { useSession } from '@/lib/session';
import { friendlyError, supabase } from '@/lib/supabase';
import { C, F, brandGradient } from '@/lib/theme';

const QUICK = ['Bonjour', 'Êtes-vous disponible ?', 'Quel est votre tarif ?', 'Où êtes-vous situé ?'];
const QUICK_ITEM = ['Bonjour', 'Toujours disponible ?', 'Dernier prix ?', 'On se voit où ?'];

/** Discussion en temps réel : bulles animées, accusés de lecture, « écrit… », envoi instantané. */
export default function Chat() {
  const p = useLocalSearchParams<{ id: string; name?: string; avatar?: string; pro?: string; other?: string }>();
  const id = p.id;
  const insets = useSafeAreaInsets();
  const { session } = useSession();
  const me = session?.user.id ?? '';

  const [info, setInfo] = useState<{ name: string; avatar: string | null; pro: boolean; other: string; listing?: { id: string; title: string; photo: string | null; price: number | null } | null }>({
    name: p.name ?? '',
    avatar: p.avatar || null,
    pro: p.pro === '1',
    other: p.other ?? '',
  });
  const [msgs, setMsgs] = useState<ChatMessage[] | null>(null);
  const [fresh, setFresh] = useState<Set<string>>(() => new Set());
  const [otherRead, setOtherRead] = useState<string | null>(null);
  const [text, setText] = useState('');
  const [typing, setTyping] = useState(false);
  const [channel, setChannel] = useState<ReturnType<typeof supabase.channel> | null>(null);
  const [lastTypingSent, setLastTypingSent] = useState(0);

  /** Ajoute ou remplace un message (fusion du message « en cours d'envoi » avec la version serveur). */
  const upsert = useCallback((m: ChatMessage, animate: boolean) => {
    setMsgs((prev) => {
      const list = prev ?? [];
      const i = list.findIndex((x) => x.id === m.id || (m.clientId && x.clientId === m.clientId));
      if (i >= 0) {
        const copy = [...list];
        copy[i] = { ...m, pending: false, failed: false };
        return copy;
      }
      return [m, ...list];
    });
    if (animate) setFresh((s) => new Set(s).add(m.clientId ?? m.id));
  }, []);

  // Chargement initial + informations de la conversation
  useEffect(() => {
    let alive = true;
    loadMessages(id)
      .then((m) => alive && setMsgs(m))
      .catch(() => alive && setMsgs([]));
    conversations()
      .then((all) => {
        const c = all.find((x) => x.id === id);
        if (!alive || !c) return;
        setInfo({
          name: c.otherName,
          avatar: c.otherAvatar,
          pro: c.otherIsPro,
          other: c.otherUserId,
          listing: c.listingId ? { id: c.listingId, title: c.listingTitle ?? 'Article', photo: c.listingPhoto, price: c.listingPrice } : null,
        });
        setOtherRead(c.otherLastReadAt);
      })
      .catch(() => undefined);
    markRead(id).catch(() => undefined);
    return () => {
      alive = false;
    };
  }, [id]);

  // Temps réel : nouveaux messages, lecture par l'autre personne, « écrit… »
  useEffect(() => {
    let typingTimer: ReturnType<typeof setTimeout> | undefined;
    const ch = supabase
      .channel(`chat-${id}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `conversation_id=eq.${id}` }, (payload) => {
        const m = toMessage(payload.new as Record<string, unknown>);
        upsert(m, m.senderId !== me);
        if (m.senderId !== me) {
          setTyping(false);
          markRead(id).catch(() => undefined);
        }
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'conversation_members', filter: `conversation_id=eq.${id}` }, (payload) => {
        const row = payload.new as { user_id: string; last_read_at: string | null };
        if (row.user_id !== me) setOtherRead(row.last_read_at);
      })
      .on('broadcast', { event: 'typing' }, (payload) => {
        if ((payload.payload as { uid?: string })?.uid === me) return;
        setTyping(true);
        clearTimeout(typingTimer);
        typingTimer = setTimeout(() => setTyping(false), 3500);
      })
      .subscribe();
    setTimeout(() => setChannel(ch), 0);
    return () => {
      clearTimeout(typingTimer);
      supabase.removeChannel(ch);
    };
  }, [id, me, upsert]);

  const onType = (v: string) => {
    setText(v);
    const now = Date.now();
    if (channel && v.trim() && now - lastTypingSent > 2000) {
      setLastTypingSent(now);
      channel.send({ type: 'broadcast', event: 'typing', payload: { uid: me } });
    }
  };

  const send = async (raw?: string, retry?: ChatMessage) => {
    const body = (raw ?? text).trim();
    if (!body || !me) return;
    tap();
    const clientId = retry?.clientId ?? Crypto.randomUUID();
    const temp: ChatMessage = retry
      ? { ...retry, pending: true, failed: false }
      : { id: clientId, clientId, conversationId: id, senderId: me, type: 'text', body, attachmentPath: null, durationMs: null, createdAt: new Date().toISOString(), pending: true };
    if (!retry) setText('');
    setMsgs((prev) => (retry ? (prev ?? []).map((x) => (x.clientId === clientId ? temp : x)) : [temp, ...(prev ?? [])]));
    if (!retry) setFresh((s) => new Set(s).add(clientId));
    try {
      const saved = await sendText(id, me, clientId, body);
      if (saved) upsert(saved, false);
    } catch {
      setMsgs((prev) => (prev ?? []).map((x) => (x.clientId === clientId ? { ...x, pending: false, failed: true } : x)));
    }
  };

  const data = msgs ?? [];
  const canSend = text.trim().length > 0;

  // ───── Messages vocaux ─────
  const recorder = useAudioRecorder(RecordingPresets.HIGH_QUALITY);
  const recState = useAudioRecorderState(recorder, 250);
  const [recording, setRecording] = useState(false);

  const startRecording = async () => {
    try {
      const perm = await requestRecordingPermissionsAsync();
      if (!perm.granted) return Alert.alert('Micro', 'Autorisez le micro pour envoyer un message vocal.');
      await setAudioModeAsync({ allowsRecording: true, playsInSilentMode: true });
      await recorder.prepareToRecordAsync();
      recorder.record();
      tap();
      setRecording(true);
    } catch (e) {
      Alert.alert('Ballal', friendlyError(e));
    }
  };

  const cancelRecording = async () => {
    setRecording(false);
    try {
      await recorder.stop();
    } catch {}
    await setAudioModeAsync({ allowsRecording: false, playsInSilentMode: true }).catch(() => undefined);
  };

  const stopAndSend = async () => {
    const duration = recState.durationMillis;
    setRecording(false);
    try {
      await recorder.stop();
      await setAudioModeAsync({ allowsRecording: false, playsInSilentMode: true });
      const uri = recorder.uri;
      if (!uri || duration < 700 || !me) return;
      const clientId = Crypto.randomUUID();
      const temp: ChatMessage = { id: clientId, clientId, conversationId: id, senderId: me, type: 'audio', body: uri, attachmentPath: null, durationMs: duration, createdAt: new Date().toISOString(), pending: true };
      setMsgs((prev) => [temp, ...(prev ?? [])]);
      setFresh((sv) => new Set(sv).add(clientId));
      try {
        const saved = await sendAudio(id, me, clientId, uri, duration);
        if (saved) upsert(saved, false);
      } catch {
        setMsgs((prev) => (prev ?? []).map((x) => (x.clientId === clientId ? { ...x, pending: false, failed: true } : x)));
      }
    } catch (e) {
      Alert.alert('Ballal', friendlyError(e));
    }
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1, backgroundColor: '#EEF3FC' }} behavior="padding">
      {/* En-tête dégradé */}
      <LinearGradient colors={brandGradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={{ paddingTop: insets.top + 6, paddingBottom: 14, paddingHorizontal: 10, borderBottomLeftRadius: 26, borderBottomRightRadius: 26 }}>
        <View style={styles.row}>
          <Pressable onPress={() => router.back()} hitSlop={10} style={{ padding: 6 }}>
            <Ionicons name="chevron-back" size={26} color="#fff" />
          </Pressable>
          <Pressable
            style={[styles.row, { flex: 1 }]}
            disabled={!info.pro || !info.other}
            onPress={() => info.other && router.push(`/pro/${info.other}`)}>
            <View>
              <View style={{ borderWidth: 2, borderColor: 'rgba(255,255,255,0.85)', borderRadius: 26 }}>
                <ProPhoto path={info.avatar} name={info.name} size={44} radius={22} />
              </View>
              <View style={{ position: 'absolute', right: 0, bottom: 1, width: 12, height: 12, borderRadius: 6, backgroundColor: '#22C55E', borderWidth: 2, borderColor: C.primary }} />
            </View>
            <View style={{ marginLeft: 10, flex: 1 }}>
              <Text numberOfLines={1} style={{ color: '#fff', fontFamily: F.display, fontSize: 16.5 }}>
                {info.name || 'Discussion'}
              </Text>
              <Text style={{ color: typing ? '#FFD3AE' : 'rgba(255,255,255,0.8)', fontFamily: typing ? F.bold : F.medium, fontSize: 12.5 }}>
                {typing ? 'écrit…' : info.pro ? 'Professionnel · voir le profil' : info.listing ? 'Marketplace · à propos d’un article' : 'Client'}
              </Text>
            </View>
          </Pressable>
          {info.pro && info.other ? (
            <Pressy onPress={() => router.push(`/pro/${info.other}`)} style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.16)', alignItems: 'center', justifyContent: 'center' }}>
              <Ionicons name="person-outline" size={19} color="#fff" />
            </Pressy>
          ) : null}
        </View>
        {info.listing ? (
          <Pressable onPress={() => info.listing && router.push(`/market/${info.listing.id}`)} style={[styles.row, { marginTop: 12, marginHorizontal: 6, backgroundColor: 'rgba(255,255,255,0.14)', borderRadius: 16, padding: 8 }]}>
            {info.listing.photo ? (
              <Image source={marketPhoto(info.listing.photo)} style={{ width: 40, height: 40, borderRadius: 10 }} contentFit="cover" />
            ) : (
              <View style={{ width: 40, height: 40, borderRadius: 10, backgroundColor: 'rgba(255,255,255,0.2)', alignItems: 'center', justifyContent: 'center' }}>
                <Ionicons name="pricetag" size={18} color="#fff" />
              </View>
            )}
            <View style={{ flex: 1, marginLeft: 10 }}>
              <Text numberOfLines={1} style={{ color: '#fff', fontFamily: F.bold, fontSize: 13.5 }}>{info.listing.title}</Text>
              {info.listing.price != null ? <Text style={{ color: '#FFD3AE', fontFamily: F.heavy, fontSize: 12.5 }}>{gnf(info.listing.price)}</Text> : null}
            </View>
            <Ionicons name="chevron-forward" size={18} color="#fff" />
          </Pressable>
        ) : null}
      </LinearGradient>

      {msgs === null ? (
        <ActivityIndicator color={C.primary} style={{ flex: 1 }} />
      ) : data.length === 0 ? (
        <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 30 }}>
          <LinearGradient colors={['#FFE7D3', C.primarySoft]} style={{ width: 86, height: 86, borderRadius: 43, alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name="chatbubbles" size={38} color={C.primary} />
          </LinearGradient>
          <Text style={[styles.h3, { marginTop: 14 }]}>Dites bonjour à {info.name.split(' ')[0] || 'votre contact'}</Text>
          <Text style={[styles.muted, { textAlign: 'center', marginTop: 4 }]}>Vos échanges restent dans BALLAL.</Text>
        </View>
      ) : (
        <FlatList
          data={data}
          inverted
          keyExtractor={(m) => m.clientId ?? m.id}
          overScrollMode="never"
          keyboardShouldPersistTaps="handled"
          contentContainerStyle={{ paddingHorizontal: 12, paddingVertical: 12 }}
          ListHeaderComponent={typing ? <TypingBubble /> : undefined}
          renderItem={({ item, index }) => {
            const newer = data[index - 1];
            const older = data[index + 1];
            const mine = item.senderId === me;
            const tail = !newer || newer.senderId !== item.senderId;
            const newDay = !older || new Date(older.createdAt).toDateString() !== new Date(item.createdAt).toDateString();
            const read = mine && !!otherRead && otherRead >= item.createdAt;
            return (
              <View>
                {newDay ? (
                  <View style={{ alignSelf: 'center', backgroundColor: 'rgba(15,23,42,0.06)', borderRadius: 12, paddingHorizontal: 12, paddingVertical: 4, marginVertical: 10 }}>
                    <Text style={{ fontFamily: F.semibold, fontSize: 11.5, color: C.muted, textTransform: 'capitalize' }}>{dayLabel(item.createdAt)}</Text>
                  </View>
                ) : null}
                <Bubble m={item} mine={mine} tail={tail} read={read} animate={fresh.has(item.clientId ?? item.id)} onRetry={() => send(item.body ?? '', item)} />
              </View>
            );
          }}
        />
      )}

      {/* Réponses rapides quand la discussion est vide */}
      {msgs !== null && data.length === 0 ? (
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, paddingHorizontal: 14, paddingBottom: 8, justifyContent: 'center' }}>
          {(info.listing ? QUICK_ITEM : QUICK).map((q) => (
            <Pressy key={q} onPress={() => send(q)} style={{ backgroundColor: '#fff', borderRadius: 18, paddingHorizontal: 14, paddingVertical: 8, borderWidth: 1, borderColor: C.primarySoft }}>
              <Text style={{ fontFamily: F.semibold, color: C.primary, fontSize: 13 }}>{q}</Text>
            </Pressy>
          ))}
        </View>
      ) : null}

      {/* Barre de saisie */}
      <View style={[styles.row, { alignItems: 'flex-end', paddingHorizontal: 10, paddingTop: 8, paddingBottom: Math.max(insets.bottom, 10), backgroundColor: '#fff', borderTopLeftRadius: 24, borderTopRightRadius: 24, shadowColor: '#0B2A6F', shadowOpacity: 0.08, shadowRadius: 12, shadowOffset: { width: 0, height: -4 }, elevation: 12 }]}>
        <View style={{ flex: 1, minHeight: 46, maxHeight: 120, backgroundColor: C.field, borderRadius: 23, paddingHorizontal: 16, justifyContent: 'center' }}>
          <TextInput
            value={text}
            onChangeText={onType}
            placeholder="Écrire un message…"
            placeholderTextColor="#94A3B8"
            multiline
            maxLength={4000}
            style={{ fontFamily: F.body, fontSize: 15, color: C.text, paddingVertical: 10, maxHeight: 110 }}
          />
        </View>
        {canSend ? <SendButton active onPress={() => send()} /> : <MicButton onPress={startRecording} />}
      </View>
      {recording ? (
        <View style={[styles.row, { position: 'absolute', left: 0, right: 0, bottom: 0, paddingHorizontal: 14, paddingTop: 12, paddingBottom: Math.max(insets.bottom, 12), backgroundColor: '#fff', borderTopLeftRadius: 24, borderTopRightRadius: 24, elevation: 14 }]}>
          <Pressy onPress={cancelRecording} style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: '#FEE2E2', alignItems: 'center', justifyContent: 'center' }}>
            <Ionicons name="trash-outline" size={20} color={C.danger} />
          </Pressy>
          <View style={[styles.row, { flex: 1, marginHorizontal: 12 }]}>
            <RecDot />
            <Text style={{ fontFamily: F.bold, fontSize: 16, color: C.text, marginLeft: 8 }}>{fmtDuration(recState.durationMillis)}</Text>
            <Text style={[styles.muted, { marginLeft: 10, fontSize: 13 }]}>Enregistrement…</Text>
          </View>
          <SendButton active onPress={stopAndSend} />
        </View>
      ) : null}
    </KeyboardAvoidingView>
  );
}

function SendButton({ active, onPress }: { active: boolean; onPress: () => void }) {
  const v = useState(() => new Animated.Value(0))[0];
  useEffect(() => {
    Animated.spring(v, { toValue: active ? 1 : 0, useNativeDriver: true, speed: 18, bounciness: 10 }).start();
  }, [active, v]);
  const scale = v.interpolate({ inputRange: [0, 1], outputRange: [0.86, 1] });
  const rotate = v.interpolate({ inputRange: [0, 1], outputRange: ['-30deg', '0deg'] });
  return (
    <Pressable onPress={onPress} disabled={!active} style={{ marginLeft: 8 }}>
      <Animated.View style={{ transform: [{ scale }, { rotate }], opacity: v.interpolate({ inputRange: [0, 1], outputRange: [0.45, 1] }) }}>
        <LinearGradient colors={brandGradient} style={{ width: 46, height: 46, borderRadius: 23, alignItems: 'center', justifyContent: 'center' }}>
          <Ionicons name="send" size={19} color="#fff" style={{ marginLeft: 3 }} />
        </LinearGradient>
      </Animated.View>
    </Pressable>
  );
}

function Bubble({ m, mine, tail, read, animate, onRetry }: { m: ChatMessage; mine: boolean; tail: boolean; read: boolean; animate: boolean; onRetry: () => void }) {
  const v = useState(() => new Animated.Value(animate ? 0 : 1))[0];
  useEffect(() => {
    if (animate) Animated.spring(v, { toValue: 1, useNativeDriver: true, speed: 16, bounciness: 9 }).start();
  }, [animate, v]);
  const r = 20;
  const shape = {
    borderTopLeftRadius: r,
    borderTopRightRadius: r,
    borderBottomLeftRadius: !mine && tail ? 6 : r,
    borderBottomRightRadius: mine && tail ? 6 : r,
  };
  const meta = (
    <View style={[styles.row, { alignSelf: 'flex-end', marginTop: 3, gap: 3 }]}>
      <Text style={{ fontFamily: F.medium, fontSize: 10.5, color: mine ? 'rgba(255,255,255,0.75)' : C.muted }}>{clock(m.createdAt)}</Text>
      {mine ? (
        m.failed ? (
          <Ionicons name="alert-circle" size={14} color="#FFB4B4" />
        ) : m.pending ? (
          <Ionicons name="time-outline" size={13} color="rgba(255,255,255,0.75)" />
        ) : (
          <Ionicons name={read ? 'checkmark-done' : 'checkmark'} size={15} color={read ? '#9FE3FF' : 'rgba(255,255,255,0.8)'} />
        )
      ) : null}
    </View>
  );
  const content =
    m.type === 'image' && m.attachmentPath ? (
      <AttachmentImage path={m.attachmentPath} />
    ) : m.type === 'audio' ? (
      <AudioBubble path={m.attachmentPath} localUri={m.pending ? m.body : null} durationMs={m.durationMs} mine={mine} />
    ) : (
      <Text style={{ fontFamily: F.body, fontSize: 15, lineHeight: 21, color: mine ? '#fff' : C.text }}>{m.body}</Text>
    );

  return (
    <Animated.View
      style={{
        alignSelf: mine ? 'flex-end' : 'flex-start',
        maxWidth: '80%',
        marginTop: tail ? 8 : 2,
        opacity: v,
        transform: [
          { scale: v.interpolate({ inputRange: [0, 1], outputRange: [0.85, 1] }) },
          { translateY: v.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) },
        ],
      }}>
      <Pressable onPress={m.failed ? onRetry : undefined}>
        {mine ? (
          <LinearGradient colors={['#3B7BFF', C.primary]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[shape, { paddingHorizontal: 14, paddingVertical: 9 }]}>
            {content}
            {meta}
          </LinearGradient>
        ) : (
          <View style={[shape, { backgroundColor: '#fff', paddingHorizontal: 14, paddingVertical: 9, shadowColor: '#0B2A6F', shadowOpacity: 0.06, shadowRadius: 6, shadowOffset: { width: 0, height: 2 }, elevation: 1 }]}>
            {content}
            {meta}
          </View>
        )}
      </Pressable>
      {m.failed ? <Text style={{ alignSelf: 'flex-end', color: C.danger, fontFamily: F.semibold, fontSize: 11, marginTop: 2 }}>Non envoyé · toucher pour réessayer</Text> : null}
    </Animated.View>
  );
}

function AttachmentImage({ path }: { path: string }) {
  const [url, setUrl] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    signedAttachment(path).then((u) => alive && setUrl(u));
    return () => {
      alive = false;
    };
  }, [path]);
  return url ? (
    <Image source={url} style={{ width: 220, height: 220, borderRadius: 14 }} contentFit="cover" transition={250} />
  ) : (
    <View style={{ width: 220, height: 220, borderRadius: 14, backgroundColor: 'rgba(0,0,0,0.06)', alignItems: 'center', justifyContent: 'center' }}>
      <ActivityIndicator color={C.primary} />
    </View>
  );
}

/** Trois points qui sautillent pendant que l'autre personne écrit. */
function TypingBubble() {
  const dots = useState(() => [0, 1, 2].map(() => new Animated.Value(0)))[0];
  useEffect(() => {
    const anims = dots.map((d, i) =>
      Animated.loop(
        Animated.sequence([
          Animated.delay(i * 150),
          Animated.timing(d, { toValue: 1, duration: 300, useNativeDriver: true }),
          Animated.timing(d, { toValue: 0, duration: 300, useNativeDriver: true }),
          Animated.delay(300 - i * 150),
        ]),
      ),
    );
    anims.forEach((a) => a.start());
    return () => anims.forEach((a) => a.stop());
  }, [dots]);
  return (
    <View style={[styles.row, { alignSelf: 'flex-start', backgroundColor: '#fff', borderRadius: 20, borderBottomLeftRadius: 6, paddingHorizontal: 16, paddingVertical: 13, marginTop: 8, gap: 5 }]}>
      {dots.map((d, i) => (
        <Animated.View
          key={i}
          style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: C.primary, opacity: d.interpolate({ inputRange: [0, 1], outputRange: [0.35, 1] }), transform: [{ translateY: d.interpolate({ inputRange: [0, 1], outputRange: [0, -5] }) }] }}
        />
      ))}
    </View>
  );
}

function fmtDuration(ms: number | null | undefined): string {
  const t = Math.max(0, Math.round((ms ?? 0) / 1000));
  return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`;
}

function MicButton({ onPress }: { onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={{ marginLeft: 8 }}>
      <LinearGradient colors={['#FF9A3D', C.accent]} style={{ width: 46, height: 46, borderRadius: 23, alignItems: 'center', justifyContent: 'center' }}>
        <Ionicons name="mic" size={21} color="#fff" />
      </LinearGradient>
    </Pressable>
  );
}

function RecDot() {
  const v = useState(() => new Animated.Value(1))[0];
  useEffect(() => {
    const a = Animated.loop(Animated.sequence([
      Animated.timing(v, { toValue: 0.25, duration: 500, useNativeDriver: true }),
      Animated.timing(v, { toValue: 1, duration: 500, useNativeDriver: true }),
    ]));
    a.start();
    return () => a.stop();
  }, [v]);
  return <Animated.View style={{ width: 12, height: 12, borderRadius: 6, backgroundColor: C.danger, opacity: v }} />;
}

/** Lecteur de message vocal : lecture / pause, barre de progression, durée. */
function AudioBubble({ path, localUri, durationMs, mine }: { path: string | null; localUri: string | null; durationMs: number | null; mine: boolean }) {
  const [url, setUrl] = useState<string | null>(localUri);
  useEffect(() => {
    let alive = true;
    if (path) signedAttachment(path).then((u) => alive && u && setUrl(u));
    return () => {
      alive = false;
    };
  }, [path]);
  const player = useAudioPlayer(url ? { uri: url } : null);
  const st = useAudioPlayerStatus(player);
  const total = st.duration > 0 ? st.duration * 1000 : (durationMs ?? 0);
  const progress = total > 0 ? Math.min(1, (st.currentTime * 1000) / total) : 0;
  const toggle = () => {
    if (!url) return;
    if (st.playing) player.pause();
    else {
      if (st.didJustFinish || progress >= 0.99) player.seekTo(0);
      setAudioModeAsync({ allowsRecording: false, playsInSilentMode: true }).catch(() => undefined);
      player.play();
    }
  };
  const fg = mine ? '#fff' : C.primary;
  return (
    <View style={[styles.row, { width: 200 }]}>
      <Pressable onPress={toggle} hitSlop={8} style={{ width: 36, height: 36, borderRadius: 18, backgroundColor: mine ? 'rgba(255,255,255,0.22)' : C.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
        {url ? <Ionicons name={st.playing ? 'pause' : 'play'} size={18} color={fg} style={{ marginLeft: st.playing ? 0 : 2 }} /> : <ActivityIndicator size="small" color={fg} />}
      </Pressable>
      <View style={{ flex: 1, marginLeft: 10 }}>
        <View style={{ height: 4, borderRadius: 2, backgroundColor: mine ? 'rgba(255,255,255,0.3)' : '#DCE6FB' }}>
          <View style={{ width: `${progress * 100}%`, height: 4, borderRadius: 2, backgroundColor: fg }} />
        </View>
        <Text style={{ marginTop: 5, fontFamily: F.semibold, fontSize: 11.5, color: mine ? 'rgba(255,255,255,0.85)' : C.muted }}>
          {fmtDuration(st.playing || progress > 0 ? st.currentTime * 1000 : total)}
        </Text>
      </View>
    </View>
  );
}
