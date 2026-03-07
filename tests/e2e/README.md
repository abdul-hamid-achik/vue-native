# Maestro E2E Testing Setup

Vue Native uses [Maestro](https://maestro.mobile.dev/) for cross-platform E2E testing.

## Installation

### 1. Install Maestro

**macOS:**
```bash
curl -Ls "https://get.maestro.mobile.dev" | bash
```

**Linux:**
```bash
curl -Ls "https://get.maestro.mobile.dev" | bash
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -useb https://get.maestro.mobile.dev | iex"
```

### 2. Verify Installation

```bash
maestro --version
```

### 3. Add to Project

```bash
bun add -d @maestro/cli
```

## Running Tests

### iOS Simulator

```bash
# Start iOS simulator
xcrun simctl boot "iPhone 15"

# Run E2E tests
bun run test:e2e:ios
```

### Android Emulator

```bash
# Start Android emulator
emulator -avd Pixel_7_API_34

# Run E2E tests
bun run test:e2e:android
```

## Test Structure

Tests are located in `.maestro/flows/`:

```
.maestro/
└── flows/
    ├── onboarding.yaml
    ├── login.yaml
    ├── navigation.yaml
    └── settings.yaml
```

## Writing Tests

### Basic Test

```yaml
# .maestro/flows/onboarding.yaml
appId: com.vuenative.example
---
- launchApp
- assertVisible: "Welcome to Vue Native"
- tapOn: "Get Started"
- assertVisible: "Home"
```

### Login Flow

```yaml
# .maestro/flows/login.yaml
appId: com.vuenative.example
env:
  EMAIL: test@example.com
  PASSWORD: password123
---
- launchApp
- tapOn: "Login"
- inputText: ${EMAIL}
- tapOn: "Password"
- inputText: ${PASSWORD}
- tapOn: "Sign In"
- assertVisible: "Welcome back"
```

### Navigation Test

```yaml
# .maestro/flows/navigation.yaml
appId: com.vuenative.example
---
- launchApp
- tapOn: "Settings"
- assertVisible: "Settings"
- back
- assertVisible: "Home"
- tapOn: "Profile"
- assertVisible: "Profile"
```

## Configuration

### maestro.yaml (Root)

```yaml
# maestro.yaml
flows:
  - .maestro/flows/*.yaml

env:
  DEVICE: ${DEVICE:-ios}
  TIMEOUT: 30000
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Bun
        uses: oven-sh/setup-bun@v1
      
      - name: Install dependencies
        run: bun install
      
      - name: Install Maestro
        run: curl -Ls "https://get.maestro.mobile.dev" | bash
      
      - name: Run E2E tests (iOS)
        run: |
          xcrun simctl boot "iPhone 15"
          bun run test:e2e:ios

  e2e-android:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Bun
        uses: oven-sh/setup-bun@v1
      
      - name: Install dependencies
        run: bun install
      
      - name: Install Maestro
        run: curl -Ls "https://get.maestro.mobile.dev" | bash
      
      - name: Run E2E tests (Android)
        run: |
          bun run test:e2e:android
```

## Commands

| Command | Description |
|---------|-------------|
| `maestro test <flow>` | Run a specific flow |
| `maestro upload <flow>` | Upload flow to Maestro cloud |
| `maestro analyze` | Analyze app structure |
| `maestro --version` | Check version |

## Best Practices

1. **Use Environment Variables**
   ```yaml
   env:
     EMAIL: test@example.com
   - inputText: ${EMAIL}
   ```

2. **Add Proper Waits**
   ```yaml
   - tapOn: "Submit"
   - waitForAnimationToEnd: 2000
   - assertVisible: "Success"
   ```

3. **Use Accessibility Labels**
   ```vue
   <VButton 
     title="Submit"
     :accessibilityLabel="'submit-button'"
   />
   ```

4. **Group Related Tests**
   ```
   flows/
   ├── auth/
   │   ├── login.yaml
   │   └── register.yaml
   └── features/
       ├── search.yaml
       └── filter.yaml
   ```

## Troubleshooting

### Test Fails to Find Element

**Solution:** Add accessibility labels
```vue
<VText accessibilityLabel="welcome-text">
  Welcome
</VText>
```

### Test Runs Too Fast

**Solution:** Add waits
```yaml
- tapOn: "Submit"
- waitForAnimationToEnd: 2000
```

### Different Screens on iOS/Android

**Solution:** Use platform-specific flows
```
flows/
├── common.yaml
├── ios/
│   └── specific.yaml
└── android/
    └── specific.yaml
```

## Alternative: Appium

If you prefer Appium:

```bash
bun add -d webdriverio @wdio/cli
```

See `tests/e2e/appium.test.ts` for Appium setup.

## Resources

- [Maestro Documentation](https://maestro.mobile.dev/)
- [Maestro Playground](https://maestro.mobile.dev/playground)
- [Example Flows](https://github.com/mobile-dev-inc/maestro/tree/main/sample)
