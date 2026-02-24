/**
 * Style type definitions for Vue Native components.
 *
 * These interfaces provide TypeScript autocompletion and validation for
 * style objects passed to createStyleSheet() and component style props.
 */

// ---------------------------------------------------------------------------
// Shared types
// ---------------------------------------------------------------------------

export type FlexDirection = 'row' | 'row-reverse' | 'column' | 'column-reverse'
export type FlexWrap = 'wrap' | 'nowrap' | 'wrap-reverse'
export type JustifyContent = 'flex-start' | 'flex-end' | 'center' | 'space-between' | 'space-around' | 'space-evenly'
export type AlignItems = 'flex-start' | 'flex-end' | 'center' | 'stretch' | 'baseline'
export type AlignSelf = 'auto' | 'flex-start' | 'flex-end' | 'center' | 'stretch' | 'baseline'
export type AlignContent = 'flex-start' | 'flex-end' | 'center' | 'stretch' | 'space-between' | 'space-around'
export type Position = 'relative' | 'absolute'
export type Display = 'flex' | 'none'
export type Overflow = 'visible' | 'hidden' | 'scroll'
export type Direction = 'inherit' | 'ltr' | 'rtl'
export type BorderStyle = 'solid' | 'dotted' | 'dashed'
export type TextAlign = 'auto' | 'left' | 'right' | 'center' | 'justify'
export type TextDecorationLine = 'none' | 'underline' | 'line-through' | 'underline line-through'
export type TextDecorationStyle = 'solid' | 'double' | 'dotted' | 'dashed'
export type TextTransform = 'none' | 'capitalize' | 'uppercase' | 'lowercase'
export type FontStyle = 'normal' | 'italic'
export type FontWeight = 'normal' | 'bold' | '100' | '200' | '300' | '400' | '500' | '600' | '700' | '800' | '900'
export type ResizeMode = 'cover' | 'contain' | 'stretch' | 'center'
export type ImportantForAccessibility = 'auto' | 'yes' | 'no' | 'no-hide-descendants'

export interface ShadowOffset {
  width: number
  height: number
}

export interface TransformValue {
  translateX?: number
  translateY?: number
  scale?: number
  scaleX?: number
  scaleY?: number
  rotate?: string
  rotateX?: string
  rotateY?: string
  rotateZ?: string
}

// ---------------------------------------------------------------------------
// ViewStyle — base style interface for all view-like components
// ---------------------------------------------------------------------------

export interface ViewStyle {
  // Layout (Yoga / Flexbox)
  flex?: number
  flexDirection?: FlexDirection
  flexWrap?: FlexWrap
  flexGrow?: number
  flexShrink?: number
  flexBasis?: number | string
  justifyContent?: JustifyContent
  alignItems?: AlignItems
  alignSelf?: AlignSelf
  alignContent?: AlignContent
  position?: Position
  top?: number | string
  right?: number | string
  bottom?: number | string
  left?: number | string
  width?: number | string
  height?: number | string
  minWidth?: number | string
  minHeight?: number | string
  maxWidth?: number | string
  maxHeight?: number | string
  margin?: number | string
  marginTop?: number | string
  marginRight?: number | string
  marginBottom?: number | string
  marginLeft?: number | string
  marginHorizontal?: number | string
  marginVertical?: number | string
  padding?: number | string
  paddingTop?: number | string
  paddingRight?: number | string
  paddingBottom?: number | string
  paddingLeft?: number | string
  paddingHorizontal?: number | string
  paddingVertical?: number | string
  gap?: number
  rowGap?: number
  columnGap?: number
  direction?: Direction
  display?: Display
  overflow?: Overflow
  zIndex?: number
  aspectRatio?: number

  // Visual
  backgroundColor?: string
  opacity?: number

  // Borders
  borderWidth?: number
  borderTopWidth?: number
  borderRightWidth?: number
  borderBottomWidth?: number
  borderLeftWidth?: number
  borderColor?: string
  borderTopColor?: string
  borderRightColor?: string
  borderBottomColor?: string
  borderLeftColor?: string
  borderRadius?: number
  borderTopLeftRadius?: number
  borderTopRightRadius?: number
  borderBottomLeftRadius?: number
  borderBottomRightRadius?: number
  borderStyle?: BorderStyle

  // Shadow
  shadowColor?: string
  shadowOffset?: ShadowOffset
  shadowOpacity?: number
  shadowRadius?: number

  // Transform
  transform?: TransformValue[]

  // Accessibility
  accessibilityLabel?: string
  accessibilityRole?: string
  accessibilityHint?: string
  accessibilityState?: Record<string, any>
  accessibilityValue?: Record<string, any>
  accessible?: boolean
  importantForAccessibility?: ImportantForAccessibility
}

// ---------------------------------------------------------------------------
// TextStyle — extends ViewStyle with text-specific properties
// ---------------------------------------------------------------------------

export interface TextStyle extends ViewStyle {
  color?: string
  fontSize?: number
  fontWeight?: FontWeight
  fontFamily?: string
  fontStyle?: FontStyle
  lineHeight?: number
  letterSpacing?: number
  textAlign?: TextAlign
  textDecorationLine?: TextDecorationLine
  textDecorationStyle?: TextDecorationStyle
  textDecorationColor?: string
  textTransform?: TextTransform
  includeFontPadding?: boolean
}

// ---------------------------------------------------------------------------
// ImageStyle — extends ViewStyle with image-specific properties
// ---------------------------------------------------------------------------

export interface ImageStyle extends ViewStyle {
  resizeMode?: ResizeMode
  tintColor?: string
}
