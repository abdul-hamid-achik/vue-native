import { defineUserConfig } from 'vuepress'
import { defaultTheme } from '@vuepress/theme-default'
import { viteBundler } from '@vuepress/bundler-vite'

export default defineUserConfig({
  lang: 'en-US',
  title: 'Vue Native',
  description: 'Build native iOS and Android apps with Vue 3.',

  bundler: viteBundler(),

  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
  ],

  theme: defaultTheme({
    logo: '/logo.svg',
    repo: 'https://github.com/abdul-hamid-achik/vue-native',
    docsDir: 'docs/src',

    navbar: [
      { text: 'Guide', link: '/guide/' },
      { text: 'Components', link: '/components/' },
      { text: 'Composables', link: '/composables/' },
      { text: 'Navigation', link: '/navigation/' },
      {
        text: 'Platforms',
        children: [
          { text: 'iOS', link: '/ios/' },
          { text: 'Android', link: '/android/' },
        ],
      },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          children: [
            '/guide/README.md',
            '/guide/installation.md',
            '/guide/your-first-app.md',
            '/guide/project-structure.md',
          ],
        },
        {
          text: 'Core Concepts',
          children: [
            '/guide/components.md',
            '/guide/styling.md',
            '/guide/navigation.md',
            '/guide/native-modules.md',
            '/guide/hot-reload.md',
          ],
        },
        {
          text: 'Advanced',
          children: [
            '/guide/error-handling.md',
            '/guide/accessibility.md',
            '/guide/typescript.md',
            '/guide/performance.md',
            '/guide/shared-transitions.md',
          ],
        },
        {
          text: 'Integration Guides',
          children: [
            '/guide/deep-linking.md',
            '/guide/state-persistence.md',
            '/guide/push-notifications.md',
            '/guide/error-reporting.md',
          ],
        },
        {
          text: 'Tooling',
          children: [
            '/guide/managed-workflow.md',
            '/guide/vscode.md',
            '/guide/neovim.md',
          ],
        },
        {
          text: 'Building & Releasing',
          children: [
            '/guide/build.md',
            '/guide/deployment.md',
          ],
        },
        {
          text: 'Reference',
          children: [
            '/guide/troubleshooting.md',
          ],
        },
      ],
      '/components/': [
        {
          text: 'Layout',
          children: [
            '/components/VView.md',
            '/components/VScrollView.md',
            '/components/VSafeArea.md',
            '/components/VKeyboardAvoiding.md',
          ],
        },
        {
          text: 'Text & Input',
          children: [
            '/components/VText.md',
            '/components/VInput.md',
          ],
        },
        {
          text: 'Interactive',
          children: [
            '/components/VButton.md',
            '/components/VPressable.md',
            '/components/VSwitch.md',
            '/components/VSlider.md',
            '/components/VSegmentedControl.md',
            '/components/VCheckbox.md',
            '/components/VRadio.md',
            '/components/VDropdown.md',
            '/components/VRefreshControl.md',
          ],
        },
        {
          text: 'Media',
          children: [
            '/components/VImage.md',
            '/components/VWebView.md',
            '/components/VVideo.md',
          ],
        },
        {
          text: 'Lists',
          children: [
            '/components/VList.md',
            '/components/VSectionList.md',
          ],
        },
        {
          text: 'Feedback',
          children: [
            '/components/VActivityIndicator.md',
            '/components/VProgressBar.md',
            '/components/VAlertDialog.md',
            '/components/VActionSheet.md',
            '/components/VModal.md',
            '/components/VErrorBoundary.md',
          ],
        },
        {
          text: 'System',
          children: [
            '/components/VStatusBar.md',
            '/components/VPicker.md',
          ],
        },
      ],
      '/composables/': [
        {
          text: 'Device & System',
          children: [
            '/composables/useNetwork.md',
            '/composables/useAppState.md',
            '/composables/useColorScheme.md',
            '/composables/useDeviceInfo.md',
            '/composables/useDimensions.md',
            '/composables/usePlatform.md',
          ],
        },
        {
          text: 'Storage & Files',
          children: [
            '/composables/useAsyncStorage.md',
            '/composables/useSecureStorage.md',
            '/composables/useFileSystem.md',
          ],
        },
        {
          text: 'Sensors & Hardware',
          children: [
            '/composables/useGeolocation.md',
            '/composables/useBiometry.md',
            '/composables/useHaptics.md',
            '/composables/useSensors.md',
            '/composables/useBluetooth.md',
          ],
        },
        {
          text: 'Media',
          children: [
            '/composables/useCamera.md',
            '/composables/useAudio.md',
            '/composables/useCalendar.md',
            '/composables/useContacts.md',
          ],
        },
        {
          text: 'Networking',
          children: [
            '/composables/useHttp.md',
            '/composables/useWebSocket.md',
          ],
        },
        {
          text: 'Permissions',
          children: [
            '/composables/usePermissions.md',
          ],
        },
        {
          text: 'Navigation',
          children: [
            '/composables/useBackHandler.md',
            '/composables/useSharedElementTransition.md',
          ],
        },
        {
          text: 'UI',
          children: [
            '/composables/useKeyboard.md',
            '/composables/useClipboard.md',
            '/composables/useShare.md',
            '/composables/useLinking.md',
            '/composables/useAnimation.md',
            '/composables/useNotifications.md',
            '/composables/useI18n.md',
            '/composables/usePerformance.md',
          ],
        },
        {
          text: 'Authentication',
          children: [
            '/composables/useAppleSignIn.md',
            '/composables/useGoogleSignIn.md',
          ],
        },
        {
          text: 'Monetization & Updates',
          children: [
            '/composables/useIAP.md',
            '/composables/useOTAUpdate.md',
            '/composables/useBackgroundTask.md',
          ],
        },
      ],
      '/navigation/': [
        '/navigation/README.md',
        '/navigation/stack.md',
        '/navigation/params.md',
        '/navigation/guards.md',
        '/navigation/screen-lifecycle.md',
        '/navigation/tabs.md',
        '/navigation/drawer.md',
      ],
      '/ios/': [
        '/ios/README.md',
        '/ios/setup.md',
        '/ios/VueNativeViewController.md',
      ],
      '/android/': [
        '/android/README.md',
        '/android/setup.md',
        '/android/VueNativeActivity.md',
      ],
    },
  }),
})
