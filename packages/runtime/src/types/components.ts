/**
 * TypeScript prop interfaces for Vue Native components.
 *
 * These interfaces describe the props accepted by each built-in component.
 * They can be used for documentation, type-checking render functions,
 * or building abstractions on top of the built-in components.
 */

import type { ViewStyle, TextStyle, ImageStyle, ResizeMode } from './styles'

// ---------------------------------------------------------------------------
// Shared prop types
// ---------------------------------------------------------------------------

export interface AccessibilityProps {
  accessibilityLabel?: string
  accessibilityRole?: string
  accessibilityHint?: string
  accessibilityState?: Record<string, unknown>
}

// ---------------------------------------------------------------------------
// Component prop interfaces
// ---------------------------------------------------------------------------

export interface VViewProps extends AccessibilityProps {
  style?: ViewStyle
  testID?: string
}

export interface VTextProps extends AccessibilityProps {
  style?: TextStyle
  numberOfLines?: number
  selectable?: boolean
}

export interface VButtonProps extends AccessibilityProps {
  style?: ViewStyle
  disabled?: boolean
  activeOpacity?: number
  onPress?: () => void
  onLongPress?: () => void
}

export interface VInputProps extends AccessibilityProps {
  modelValue?: string
  placeholder?: string
  secureTextEntry?: boolean
  keyboardType?: 'default' | 'numeric' | 'email-address' | 'phone-pad' | 'number-pad' | 'decimal-pad' | 'url'
  returnKeyType?: 'done' | 'go' | 'next' | 'search' | 'send'
  autoCapitalize?: 'none' | 'sentences' | 'words' | 'characters'
  autoCorrect?: boolean
  maxLength?: number
  multiline?: boolean
  style?: TextStyle
}

export interface VSwitchProps extends AccessibilityProps {
  modelValue?: boolean
  disabled?: boolean
  onTintColor?: string
  thumbTintColor?: string
  style?: ViewStyle
}

export interface VImageProps extends AccessibilityProps {
  source: { uri: string }
  resizeMode?: ResizeMode
  style?: ImageStyle
  testID?: string
}

export interface VScrollViewProps extends AccessibilityProps {
  horizontal?: boolean
  showsVerticalScrollIndicator?: boolean
  showsHorizontalScrollIndicator?: boolean
  scrollEnabled?: boolean
  bounces?: boolean
  pagingEnabled?: boolean
  contentContainerStyle?: ViewStyle
  refreshing?: boolean
  style?: ViewStyle
}

export interface VActivityIndicatorProps {
  animating?: boolean
  color?: string
  size?: 'small' | 'medium' | 'large'
  hidesWhenStopped?: boolean
  style?: ViewStyle
}

export interface VSliderProps extends AccessibilityProps {
  modelValue?: number
  min?: number
  max?: number
  style?: ViewStyle
}

export interface VListProps<T = unknown> {
  data: T[]
  keyExtractor?: (item: T, index: number) => string
  estimatedItemHeight?: number
  showsScrollIndicator?: boolean
  bounces?: boolean
  horizontal?: boolean
  style?: ViewStyle
}

export interface VModalProps {
  visible?: boolean
  style?: ViewStyle
}

export interface VAlertDialogProps {
  visible?: boolean
  title?: string
  message?: string
  buttons?: Array<{
    label: string
    style?: 'default' | 'cancel' | 'destructive'
  }>
  /** Shorthand: confirm button label. Used when `buttons` is empty. */
  confirmText?: string
  /** Shorthand: cancel button label. Used when `buttons` is empty. */
  cancelText?: string
}

export interface VStatusBarProps {
  barStyle?: 'default' | 'light-content' | 'dark-content'
  hidden?: boolean
  animated?: boolean
}

export interface VWebViewProps {
  source: { uri?: string, html?: string }
  style?: ViewStyle
  javaScriptEnabled?: boolean
}

export interface VProgressBarProps {
  progress?: number
  progressTintColor?: string
  trackTintColor?: string
  animated?: boolean
  style?: ViewStyle
}

export interface VPickerProps {
  mode?: 'date' | 'time' | 'datetime'
  value?: number
  minimumDate?: number
  maximumDate?: number
  minuteInterval?: number
  style?: ViewStyle
}

export interface VSegmentedControlProps {
  values: string[]
  selectedIndex?: number
  tintColor?: string
  enabled?: boolean
  style?: ViewStyle
}

export interface VActionSheetProps {
  visible?: boolean
  title?: string
  message?: string
  actions?: Array<{
    label: string
    style?: 'default' | 'cancel' | 'destructive'
  }>
}

export interface VKeyboardAvoidingProps {
  style?: ViewStyle
  testID?: string
}

export interface VSafeAreaProps {
  style?: ViewStyle
}

export interface VRefreshControlProps {
  refreshing?: boolean
  onRefresh?: () => void
  tintColor?: string
  title?: string
  style?: ViewStyle
}

export interface VPressableProps extends AccessibilityProps {
  style?: ViewStyle
  disabled?: boolean
  activeOpacity?: number
  onPress?: () => void
  onPressIn?: () => void
  onPressOut?: () => void
  onLongPress?: () => void
}

export interface VCheckboxProps extends AccessibilityProps {
  modelValue?: boolean
  disabled?: boolean
  label?: string
  checkColor?: string
  tintColor?: string
  style?: ViewStyle
}

export interface VRadioProps extends AccessibilityProps {
  modelValue?: string
  options: Array<{ label: string, value: string }>
  disabled?: boolean
  tintColor?: string
  style?: ViewStyle
}

export interface VDropdownProps extends AccessibilityProps {
  modelValue?: string
  options: Array<{ label: string, value: string }>
  placeholder?: string
  disabled?: boolean
  tintColor?: string
  style?: ViewStyle
}

export interface VVideoProps extends AccessibilityProps {
  source: { uri: string }
  autoplay?: boolean
  loop?: boolean
  muted?: boolean
  paused?: boolean
  controls?: boolean
  volume?: number
  resizeMode?: 'cover' | 'contain' | 'stretch' | 'center'
  poster?: string
  style?: ViewStyle
  testID?: string
}

export interface VSectionListSection<T = unknown> {
  title: string
  data: T[]
}

export interface VSectionListProps<T = unknown> {
  sections: VSectionListSection<T>[]
  keyExtractor?: (item: T, index: number) => string
  estimatedItemHeight?: number
  stickySectionHeaders?: boolean
  showsScrollIndicator?: boolean
  bounces?: boolean
  style?: ViewStyle
}

export interface VFlatListProps<T = unknown, TRendered = unknown> {
  data: T[]
  renderItem?: (info: { item: T, index: number }) => TRendered
  keyExtractor?: (item: T, index: number) => string | number
  itemHeight: number
  windowSize?: number
  style?: ViewStyle
  showsScrollIndicator?: boolean
  bounces?: boolean
  headerHeight?: number
  endReachedThreshold?: number
}

export interface VTabBarProps {
  tabs: Array<{
    id: string
    label: string
    icon?: string
    badge?: number | string
  }>
  activeTab: string
  position?: 'top' | 'bottom'
}

export interface VDrawerProps {
  open?: boolean
  position?: 'left' | 'right'
  width?: number
  closeOnPress?: boolean
}

export interface VDrawerItemProps extends AccessibilityProps {
  icon?: string
  label: string
  badge?: number | string | null
  disabled?: boolean
}

export interface VDrawerSectionProps {
  title?: string
}
