/**
 * TypeScript prop interfaces for Vue Native components.
 *
 * These interfaces describe the props accepted by each built-in component.
 * They can be used for documentation, type-checking render functions,
 * or building abstractions on top of the built-in components.
 */

import type { ViewStyle, TextStyle, ImageStyle, ResizeMode, StyleProp } from './styles'

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
  style?: StyleProp<ViewStyle>
  testID?: string
}

export interface VTextProps extends AccessibilityProps {
  style?: StyleProp<TextStyle>
  numberOfLines?: number
  selectable?: boolean
}

export interface VButtonProps extends AccessibilityProps {
  title?: string
  titleStyle?: TextStyle
  style?: StyleProp<ViewStyle>
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
  style?: StyleProp<TextStyle>
}

export interface VSwitchProps extends AccessibilityProps {
  modelValue?: boolean
  disabled?: boolean
  onTintColor?: string
  thumbTintColor?: string
  style?: StyleProp<ViewStyle>
}

export interface VImageProps extends AccessibilityProps {
  source: { uri: string }
  resizeMode?: ResizeMode
  style?: StyleProp<ImageStyle>
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
  style?: StyleProp<ViewStyle>
}

export interface VActivityIndicatorProps {
  animating?: boolean
  color?: string
  size?: 'small' | 'medium' | 'large'
  hidesWhenStopped?: boolean
  style?: StyleProp<ViewStyle>
}

export interface VSliderProps extends AccessibilityProps {
  modelValue?: number
  min?: number
  max?: number
  style?: StyleProp<ViewStyle>
}

export interface VListProps<T = unknown> {
  data: T[]
  keyExtractor?: (item: T, index: number) => string
  estimatedItemHeight?: number
  showsScrollIndicator?: boolean
  bounces?: boolean
  horizontal?: boolean
  style?: StyleProp<ViewStyle>
}

export interface VModalProps {
  visible?: boolean
  style?: StyleProp<ViewStyle>
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
  style?: StyleProp<ViewStyle>
  javaScriptEnabled?: boolean
}

export interface VProgressBarProps {
  progress?: number
  progressTintColor?: string
  trackTintColor?: string
  animated?: boolean
  style?: StyleProp<ViewStyle>
}

export interface VPickerProps {
  mode?: 'date' | 'time' | 'datetime'
  value?: number
  minimumDate?: number
  maximumDate?: number
  minuteInterval?: number
  style?: StyleProp<ViewStyle>
}

export interface VSegmentedControlProps {
  values: string[]
  selectedIndex?: number
  tintColor?: string
  enabled?: boolean
  style?: StyleProp<ViewStyle>
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
  style?: StyleProp<ViewStyle>
  testID?: string
}

export interface VSafeAreaProps {
  style?: StyleProp<ViewStyle>
}

export interface VRefreshControlProps {
  refreshing?: boolean
  onRefresh?: () => void
  tintColor?: string
  title?: string
  style?: StyleProp<ViewStyle>
}

export interface VPressableProps extends AccessibilityProps {
  style?: StyleProp<ViewStyle>
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
  style?: StyleProp<ViewStyle>
}

export interface VRadioProps extends AccessibilityProps {
  modelValue?: string
  options: Array<{ label: string, value: string }>
  disabled?: boolean
  tintColor?: string
  style?: StyleProp<ViewStyle>
}

export interface VDropdownProps extends AccessibilityProps {
  modelValue?: string
  options: Array<{ label: string, value: string }>
  placeholder?: string
  disabled?: boolean
  tintColor?: string
  style?: StyleProp<ViewStyle>
}

export interface VVideoProps extends AccessibilityProps {
  source: { uri: string }
  autoplay?: boolean
  loop?: boolean
  muted?: boolean
  paused?: boolean
  /** Reserved for native transport controls; currently has no effect. */
  controls?: boolean
  volume?: number
  resizeMode?: 'cover' | 'contain' | 'stretch' | 'center'
  /** Reserved for native poster rendering; currently has no effect. */
  poster?: string
  style?: StyleProp<ViewStyle>
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
  style?: StyleProp<ViewStyle>
}

export interface VFlatListProps<T = unknown, TRendered = unknown> {
  data: T[]
  renderItem?: (info: { item: T, index: number }) => TRendered
  keyExtractor?: (item: T, index: number) => string | number
  itemHeight: number
  windowSize?: number
  style?: StyleProp<ViewStyle>
  showsScrollIndicator?: boolean
  bounces?: boolean
  headerHeight?: number
  endReachedThreshold?: number
}

export interface VTabBarProps {
  tabs: Array<{
    label: string
    icon?: string
    badge?: number | string
  } & (
    | { id: string, name?: string }
    | { id?: string, name: string }
  )>
  activeTab?: string
  modelValue?: string
  position?: 'top' | 'bottom'
  activeColor?: string
  inactiveColor?: string
  backgroundColor?: string
}

export interface VToolbarProps {
  items: Array<{
    id: string
    label: string
    icon?: string
  }>
  displayMode?: 'iconOnly' | 'labelOnly' | 'iconAndLabel'
  showsBaselineSeparator?: boolean
  style?: StyleProp<ViewStyle>
}

export interface VSplitViewProps {
  direction?: 'horizontal' | 'vertical'
  dividerStyle?: 'thin' | 'thick' | 'paneSplitter'
  dividerColor?: string
  dividerPosition?: number
  style?: StyleProp<ViewStyle>
}

export interface VOutlineNode {
  id: string
  label: string
  children?: VOutlineNode[]
}

export interface VOutlineViewProps {
  data: VOutlineNode[]
  expandAll?: boolean
  selectionMode?: 'single' | 'multiple' | 'none'
  style?: StyleProp<ViewStyle>
}

export interface VDrawerProps {
  open?: boolean
  position?: 'left' | 'right'
  width?: number
  overlayColor?: string
  closeOnPress?: boolean
  closeOnPressOutside?: boolean
}

export interface VDrawerItemProps extends AccessibilityProps {
  icon?: string
  label: string
  active?: boolean
  badge?: number | string | null
  disabled?: boolean
}

export interface VDrawerSectionProps {
  title?: string
}
