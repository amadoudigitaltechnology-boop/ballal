import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useState, type ReactNode } from 'react';
import {
  ActivityIndicator,
  Animated,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type StyleProp,
  type TextInputProps,
  type ViewStyle,
} from 'react-native';

import { C, F, brandGradient, logo, radius, shadow } from '@/lib/theme';

export function Logo({ height = 32 }: { height?: number }) {
  return <Image source={logo} style={{ height, width: height * 3.55 }} contentFit="contain" accessibilityLabel="BALLAL" />;
}

/** Apparition douce : fondu + léger glissement vers le haut, décalé selon l'index. */
export function FadeIn({ children, index = 0, style }: { children: ReactNode; index?: number; style?: StyleProp<ViewStyle> }) {
  const v = useState(() => new Animated.Value(0))[0];
  useEffect(() => {
    Animated.timing(v, { toValue: 1, duration: 380, delay: Math.min(index, 8) * 55, useNativeDriver: true }).start();
  }, [v, index]);
  return (
    <Animated.View
      style={[style, { opacity: v, transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [16, 0] }) }] }]}>
      {children}
    </Animated.View>
  );
}

/** Zone tactile qui s'enfonce légèrement au toucher. */
export function Pressy({
  children,
  onPress,
  style,
  disabled,
}: {
  children: ReactNode;
  onPress?: () => void;
  style?: StyleProp<ViewStyle>;
  disabled?: boolean;
}) {
  const s = useState(() => new Animated.Value(1))[0];
  const to = (v: number) => Animated.spring(s, { toValue: v, useNativeDriver: true, speed: 40, bounciness: 6 }).start();
  return (
    <Pressable disabled={disabled} onPress={onPress} onPressIn={() => to(0.96)} onPressOut={() => to(1)}>
      <Animated.View style={[style, { transform: [{ scale: s }] }]}>{children}</Animated.View>
    </Pressable>
  );
}

export function Card({ children, onPress, style }: { children: ReactNode; onPress?: () => void; style?: StyleProp<ViewStyle> }) {
  return (
    <Pressy onPress={onPress} disabled={!onPress} style={[styles.card, style]}>
      {children}
    </Pressy>
  );
}

export function Button({
  label,
  onPress,
  loading,
  variant = 'primary',
  icon,
  style,
}: {
  label: string;
  onPress: () => void;
  loading?: boolean;
  variant?: 'primary' | 'outline' | 'accent' | 'danger';
  icon?: keyof typeof Ionicons.glyphMap;
  style?: StyleProp<ViewStyle>;
}) {
  const content = (color: string) =>
    loading ? (
      <ActivityIndicator color={color} />
    ) : (
      <View style={styles.row}>
        <Text style={[styles.btnText, { color }]}>{label}</Text>
        {icon ? <Ionicons name={icon} size={19} color={color} style={{ marginLeft: 8 }} /> : null}
      </View>
    );
  if (variant === 'outline' || variant === 'danger') {
    const color = variant === 'danger' ? C.danger : C.text;
    return (
      <Pressy onPress={onPress} disabled={loading} style={[styles.btn, styles.outline, variant === 'danger' && { borderColor: C.danger }, style]}>
        {content(color)}
      </Pressy>
    );
  }
  const colors = variant === 'accent' ? (['#FF9A3D', C.accent, '#FF5A00'] as const) : brandGradient;
  return (
    <Pressy onPress={onPress} disabled={loading} style={style}>
      <LinearGradient colors={colors} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={[styles.btn, styles.btnShadow]}>
        {content('#fff')}
      </LinearGradient>
    </Pressy>
  );
}

export function Input({
  icon,
  secure,
  style,
  ...props
}: TextInputProps & { icon?: keyof typeof Ionicons.glyphMap; secure?: boolean }) {
  const [hidden, setHidden] = useState(true);
  const [focus, setFocus] = useState(false);
  return (
    <View style={[styles.input, focus && { borderColor: C.primary }, style as StyleProp<ViewStyle>]}>
      {icon ? <Ionicons name={icon} size={20} color={C.muted} style={{ marginRight: 10 }} /> : null}
      <TextInput
        {...props}
        secureTextEntry={secure && hidden}
        onFocus={(e) => {
          setFocus(true);
          props.onFocus?.(e);
        }}
        onBlur={(e) => {
          setFocus(false);
          props.onBlur?.(e);
        }}
        placeholderTextColor="#94A3B8"
        style={styles.inputText}
      />
      {secure ? (
        <Pressable onPress={() => setHidden(!hidden)} hitSlop={10}>
          <Ionicons name={hidden ? 'eye-outline' : 'eye-off-outline'} size={20} color={C.muted} />
        </Pressable>
      ) : null}
    </View>
  );
}

export function SectionHeader({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  return (
    <View style={[styles.row, { paddingHorizontal: 16, marginTop: 22, marginBottom: 10 }]}>
      <LinearGradient colors={brandGradient} style={{ width: 4, height: 18, borderRadius: 4, marginRight: 8 }} />
      <Text style={[styles.h3, { flex: 1 }]}>{title}</Text>
      {action ? (
        <Pressable onPress={onAction} hitSlop={8}>
          <Text style={{ color: C.primary, fontFamily: F.bold }}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function Stars({ rating, count }: { rating: number; count: number }) {
  return (
    <View style={styles.row}>
      <Ionicons name="star" size={14} color={C.star} />
      <Text style={{ fontFamily: F.bold, marginLeft: 4, color: C.text }}>{count > 0 ? rating.toFixed(1) : '—'}</Text>
      <Text style={{ color: C.muted, marginLeft: 4, fontFamily: F.body }}>({count} avis)</Text>
    </View>
  );
}

export function Empty({ icon, title, text }: { icon: keyof typeof Ionicons.glyphMap; title: string; text?: string }) {
  return (
    <View style={{ alignItems: 'center', padding: 32 }}>
      <View style={{ backgroundColor: C.primarySoft, padding: 18, borderRadius: 40 }}>
        <Ionicons name={icon} size={34} color={C.primary} />
      </View>
      <Text style={[styles.h3, { marginTop: 14, textAlign: 'center' }]}>{title}</Text>
      {text ? <Text style={{ color: C.muted, textAlign: 'center', marginTop: 6, fontFamily: F.body }}>{text}</Text> : null}
    </View>
  );
}

export const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center' },
  card: { backgroundColor: C.white, borderRadius: radius, padding: 14, ...shadow },
  btn: { height: 54, borderRadius: 27, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 20 },
  btnShadow: { shadowColor: C.primary, shadowOpacity: 0.3, shadowRadius: 12, shadowOffset: { width: 0, height: 6 }, elevation: 4 },
  outline: { borderWidth: 1.2, borderColor: C.border, backgroundColor: C.white },
  btnText: { fontFamily: F.bold, fontSize: 16 },
  input: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: C.field,
    borderRadius: 16,
    borderWidth: 1.5,
    borderColor: 'transparent',
    paddingHorizontal: 16,
    height: 56,
  },
  inputText: { flex: 1, fontFamily: F.body, fontSize: 15, color: C.text },
  h1: { fontFamily: F.displayHeavy, fontSize: 28, color: C.primaryDark, letterSpacing: -0.5 },
  h2: { fontFamily: F.display, fontSize: 22, color: C.text, letterSpacing: -0.3 },
  h3: { fontFamily: F.display, fontSize: 17, color: C.text, letterSpacing: -0.2 },
  body: { fontFamily: F.body, fontSize: 15, color: C.text },
  muted: { fontFamily: F.body, fontSize: 14, color: C.muted },
});
