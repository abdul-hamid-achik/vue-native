# Layout Engines

Vue Native exposes one Flexbox model to JavaScript, but each platform applies it
with a different native engine. The TypeScript `StyleEngine` contract is the
same everywhere — `flex`, `flexDirection`, `padding`, `margin`, `gap`, and so on
— but how those values reach the underlying layout system is platform-specific.

| Platform | Engine | Dependency | View base |
|----------|--------|------------|-----------|
| iOS | [Yoga](https://www.yogalayout.dev/) | `layoutBox` / `FlexLayout` SPM package | `UIView` |
| Android | [FlexboxLayout](https://github.com/google/flexbox-layout) 3.0.0 | Google FlexboxLayout | `View` / `FlexboxLayout` |
| macOS | `LayoutNode` (custom) | None — pure Swift, in-repo | `FlippedView` (`NSView`) |

## iOS: Yoga

iOS uses Facebook's Yoga through the `FlexLayout` Swift wrapper. Each view's
Yoga node is configured through the `view.flex` proxy:

```swift
view.flex.width(50%)          // postfix % operator, NOT FPercent(value:)
view.flex.padding(16)
view.flex.direction(.column)
view.flex.layout(mode: .fitContainer)   // trigger a layout pass
```

Notes:

- Percentage widths/heights use the postfix `%` operator (`50%`). The internal
  `FPercent(value:)` type is not public API.
- A layout pass is triggered explicitly with `view.flex.layout(mode:)`.

## Android: FlexboxLayout

Android uses Google's `FlexboxLayout` (3.0.0). The Kotlin `StyleEngine`
(`native/android/.../Styling/StyleEngine.kt`) is the single entry point that
maps style props onto `FlexboxLayout.LayoutParams`.

The main gotcha is percentage sizing:

- Percentage widths/heights use `FlexboxLayout.LayoutParams.widthPercent` /
  `heightPercent`.
- Do **not** fall back to `ViewGroup.LayoutParams.WRAP_CONTENT` for percentage
  dimensions — that silently breaks percentage sizing.

## macOS: LayoutNode (custom)

macOS has no Yoga dependency. Instead it ships a custom pure-Swift flexbox
engine, `LayoutNode`
(`native/macos/.../Layout/LayoutNode.swift`), that computes frames directly.

Layout properties are typed with the `LayoutValue` enum rather than raw
numbers:

```swift
node.width = .points(120)     // NOT node.width = 120
node.width = .percent(50)
node.height = .auto
node.minHeight = .undefined
```

`LayoutValue` cases: `.points(CGFloat)`, `.percent(CGFloat)`, `.auto`,
`.undefined`.

All macOS views use the `FlippedView` base class, which overrides
`isFlipped` to return `true`. This gives NSView a CSS-compatible top-left
origin (AppKit's default origin is bottom-left, which would otherwise invert
layout).

## Cross-platform implications

Because the engines differ, a few behaviors are platform-specific even though
the JS API is uniform:

- **Shadows.** iOS renders `shadowColor` / `shadowOffset` / `shadowOpacity` /
  `shadowRadius` via `CALayer`; Android ignores those and requires `elevation`.
  macOS applies visual styles through `NSView.layer`.
- **Transforms.** `skewX` / `skewY` are supported on iOS and macOS but ignored
  (logged) on Android, whose `View` has no skew transform. See
  [Styling](/guide/styling.md#transforms).
- **Percentage support.** Width/height percentages work on all three platforms,
  but `padding` / `margin` are numbers only (no percentages) across the board.

## See also

- [Architecture Overview](/architecture/) — the renderer and bridge pipeline.
- [Threading Architecture](/architecture/dual-thread.md) — where layout runs (the UI thread).
- [Styling](/guide/styling.md) — the full style property reference.
