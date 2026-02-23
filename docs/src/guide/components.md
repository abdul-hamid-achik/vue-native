# Components

Vue Native provides 20 built-in components that map directly to native views.

## Import

All components are globally registered — no import needed in templates.

## Layout

| Component | iOS | Android | Description |
|-----------|-----|---------|-------------|
| [`<VView>`](../components/VView.md) | UIView | FlexboxLayout | Container view. Supports all Flexbox props |
| [`<VScrollView>`](../components/VScrollView.md) | UIScrollView | ScrollView | Scrollable container |
| [`<VSafeArea>`](../components/VSafeArea.md) | UIView + safeAreaInsets | View + WindowInsetsCompat | Respects device safe areas |
| [`<VKeyboardAvoiding>`](../components/VKeyboardAvoiding.md) | Custom VC logic | AdjustResize / manual offset | Shifts content when keyboard appears |

## Text & Input

| Component | iOS | Android | Description |
|-----------|-----|---------|-------------|
| [`<VText>`](../components/VText.md) | UILabel | TextView | Text display |
| [`<VInput>`](../components/VInput.md) | UITextField | EditText | Text input with `v-model` |

## Interactive

| Component | iOS | Android | Description |
|-----------|-----|---------|-------------|
| [`<VButton>`](../components/VButton.md) | UIButton / UIControl | Custom TouchDelegate | Pressable view with `@press` |
| [`<VSwitch>`](../components/VSwitch.md) | UISwitch | Switch | Toggle with `v-model` |
| [`<VSlider>`](../components/VSlider.md) | UISlider | SeekBar | Range slider with `v-model` |
| [`<VSegmentedControl>`](../components/VSegmentedControl.md) | UISegmentedControl | TabLayout | Tab strip selector |

## Media

| Component | iOS | Android | Description |
|-----------|-----|---------|-------------|
| [`<VImage>`](../components/VImage.md) | UIImageView + URLSession | ImageView + Coil | Async image loading with caching |
| [`<VWebView>`](../components/VWebView.md) | WKWebView | WebView | Embedded web view |

## Lists

| Component | iOS | Android | Description |
|-----------|-----|---------|-------------|
| [`<VList>`](../components/VList.md) | UITableView | RecyclerView | Virtualized list for large datasets |

## Feedback

| Component | iOS | Android | Description |
|-----------|-----|---------|-------------|
| [`<VActivityIndicator>`](../components/VActivityIndicator.md) | UIActivityIndicatorView | ProgressBar (circular) | Loading spinner |
| [`<VProgressBar>`](../components/VProgressBar.md) | UIProgressView | ProgressBar (horizontal) | Progress bar |
| [`<VAlertDialog>`](../components/VAlertDialog.md) | UIAlertController | AlertDialog | Native alert |
| [`<VActionSheet>`](../components/VActionSheet.md) | UIAlertController (.actionSheet) | BottomSheetDialog | Bottom action sheet |
| [`<VModal>`](../components/VModal.md) | UIViewController presentation | Dialog | Full-screen overlay modal |

## System

| Component | iOS | Android | Description |
|-----------|-----|---------|-------------|
| [`<VStatusBar>`](../components/VStatusBar.md) | UIStatusBarStyle | WindowInsetsController | Control status bar style |
| [`<VPicker>`](../components/VPicker.md) | UIDatePicker | DatePickerDialog / NumberPicker | Date/time and value picker |
