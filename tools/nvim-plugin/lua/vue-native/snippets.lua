-- vue-native/snippets.lua — LuaSnip-compatible snippets for Vue Native
-- Covers all 30+ components, 28+ composables, navigation, and scaffolds

local M = {}

function M.setup()
  local ok, luasnip = pcall(require, "luasnip")
  if not ok then
    return
  end

  local s = luasnip.snippet
  local t = luasnip.text_node
  local i = luasnip.insert_node
  local c = luasnip.choice_node

  local snippets = {}

  -- ═══════════════════════════════════════════════════════════
  -- Scaffolds
  -- ═══════════════════════════════════════════════════════════

  table.insert(snippets, s("vn-app", {
    t({ '<script setup lang="ts">', "" }),
    t({ "import { ref } from 'vue'", "" }),
    t({ "import { createStyleSheet } from '@thelacanians/vue-native-runtime'", "", "" }),
    i(0),
    t({ "", "", "const styles = createStyleSheet({", "" }),
    t({ "  container: {", "" }),
    t({ "    flex: 1,", "" }),
    t({ "    justifyContent: 'center',", "" }),
    t({ "    alignItems: 'center',", "" }),
    t({ "    backgroundColor: '#ffffff',", "" }),
    t({ "  },", "" }),
    t({ "})", "" }),
    t({ "</script>", "", "" }),
    t({ "<template>", "" }),
    t({ "  <VSafeArea :style=\"{ flex: 1, backgroundColor: '#ffffff' }\">", "" }),
    t({ "    <VView :style=\"styles.container\">", "" }),
    t({ "      <VText>Hello, Vue Native!</VText>", "" }),
    t({ "    </VView>", "" }),
    t({ "  </VSafeArea>", "" }),
    t({ "</template>" }),
  }))

  table.insert(snippets, s("vn-screen", {
    t({ '<script setup lang="ts">', "" }),
    t({ "import { createStyleSheet } from '@thelacanians/vue-native-runtime'", "" }),
    t({ "import { useRoute } from '@thelacanians/vue-native-navigation'", "", "" }),
    t({ "const route = useRoute()", "", "" }),
    i(0),
    t({ "", "", "const styles = createStyleSheet({", "" }),
    t({ "  container: {", "" }),
    t({ "    flex: 1,", "" }),
    t({ "    padding: 16,", "" }),
    t({ "    backgroundColor: '#ffffff',", "" }),
    t({ "  },", "" }),
    t({ "  title: {", "" }),
    t({ "    fontSize: 24,", "" }),
    t({ "    fontWeight: 'bold',", "" }),
    t({ "    color: '#1a1a1a',", "" }),
    t({ "    marginBottom: 16,", "" }),
    t({ "  },", "" }),
    t({ "})", "" }),
    t({ "</script>", "", "" }),
    t({ "<template>", "" }),
    t({ '  <VView :style="styles.container">', "" }),
    t({ '    <VText :style="styles.title">' }),
    i(1, "Screen Title"),
    t({ "</VText>", "" }),
    t({ "  </VView>", "" }),
    t({ "</template>" }),
  }))

  table.insert(snippets, s("vn-main", {
    t({ "import { createApp } from 'vue'", "" }),
    t({ "import { createRouter } from '@thelacanians/vue-native-navigation'", "" }),
    t({ "import App from './App.vue'", "" }),
    t("import "),
    i(1, "Home"),
    t(" from './pages/"),
    i(2, "Home"),
    t({ ".vue'", "", "" }),
    t({ "const router = createRouter([", "" }),
    t("  { name: '"),
    i(3, "Home"),
    t("', component: "),
    i(4, "Home"),
    t({ " },", "" }),
    t({ "])", "", "" }),
    t({ "const app = createApp(App)", "" }),
    t({ "app.use(router)", "" }),
    t({ "app.start()" }),
  }))

  table.insert(snippets, s("vn-config", {
    t({ "import { defineConfig } from '@thelacanians/vue-native-cli'", "", "" }),
    t({ "export default defineConfig({", "" }),
    t("  name: '"),
    i(1, "MyApp"),
    t({ "',", "" }),
    t("  bundleId: '"),
    i(2, "com.example.myapp"),
    t({ "',", "" }),
    t("  version: '"),
    i(3, "1.0.0"),
    t({ "',", "" }),
    t({ "  ios: {", "" }),
    t("    deploymentTarget: '"),
    i(4, "16.0"),
    t({ "',", "" }),
    t({ "  },", "" }),
    t({ "  android: {", "" }),
    t("    minSdk: "),
    i(5, "21"),
    t({ ",", "" }),
    t("    targetSdk: "),
    i(6, "34"),
    t({ ",", "" }),
    t({ "  },", "" }),
    t({ "})" }),
  }))

  -- ═══════════════════════════════════════════════════════════
  -- Components
  -- ═══════════════════════════════════════════════════════════

  table.insert(snippets, s("vn-view", {
    t('<VView :style="'),
    i(1, "styles.container"),
    t({ '">',  "" }),
    t("  "),
    i(0),
    t({ "", "</VView>" }),
  }))

  table.insert(snippets, s("vn-text", {
    t('<VText :style="'),
    i(1, "styles.text"),
    t('">'),
    i(0, "Hello"),
    t("</VText>"),
  }))

  table.insert(snippets, s("vn-button", {
    t('<VButton :style="'),
    i(1, "styles.button"),
    t('" :onPress="'),
    i(2, "handlePress"),
    t({ '">',  "" }),
    t('  <VText :style="'),
    i(3, "styles.buttonText"),
    t('">'),
    i(0, "Press Me"),
    t({ "</VText>", "" }),
    t("</VButton>"),
  }))

  table.insert(snippets, s("vn-input", {
    t({ "<VInput", "" }),
    t('  v-model="'),
    i(1, "text"),
    t({ '"', "" }),
    t('  placeholder="'),
    i(2, "Enter text..."),
    t({ '"', "" }),
    t('  :style="'),
    i(3, "styles.input"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-image", {
    t({ "<VImage", "" }),
    t("  :source=\"{ uri: '"),
    i(1, "https://example.com/image.png"),
    t({ "' }\"", "" }),
    t("  :style=\"{ width: "),
    i(2, "200"),
    t(", height: "),
    i(3, "200"),
    t({ ' }"', "" }),
    t('  resizeMode="'),
    c(4, {
      t("cover"),
      t("contain"),
      t("stretch"),
      t("center"),
    }),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-scrollview", {
    t('<VScrollView :style="{ flex: 1 }"'),
    i(1, " horizontal"),
    t({ ">",  "" }),
    t("  "),
    i(0),
    t({ "", "</VScrollView>" }),
  }))

  table.insert(snippets, s("vn-list", {
    t({ "<VList", "" }),
    t('  :data="'),
    i(1, "items"),
    t({ '"', "" }),
    t('  :renderItem="(item) => h(VView, { style: styles.item }, ['),
    t({ "", "    h(VText, {}, () => item." }),
    i(2, "title"),
    t({ ")", "" }),
    t({ '  ])"', "" }),
    t('  :keyExtractor="(item) => item.'),
    i(3, "id"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-list-template", {
    t({ "<VList", "" }),
    t('  :data="'),
    i(1, "items"),
    t({ '"', "" }),
    t('  :renderItem="renderItem"'),
    t({ "", '  :keyExtractor="(item) => item.' }),
    i(2, "id"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-safearea", {
    t("<VSafeArea :style=\"{ flex: 1, backgroundColor: '"),
    i(1, "#ffffff"),
    t({ "' }\">", "" }),
    t("  "),
    i(0),
    t({ "", "</VSafeArea>" }),
  }))

  table.insert(snippets, s("vn-switch", {
    t({ "<VSwitch", "" }),
    t('  v-model="'),
    i(1, "isEnabled"),
    t({ '"', "" }),
    t('  trackColor="'),
    i(2, "#4f46e5"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-slider", {
    t({ "<VSlider", "" }),
    t('  v-model="'),
    i(1, "value"),
    t({ '"', "" }),
    t("  :minimumValue=\""),
    i(2, "0"),
    t({ '"', "" }),
    t("  :maximumValue=\""),
    i(3, "100"),
    t({ '"', "" }),
    t('  minimumTrackTintColor="'),
    i(4, "#4f46e5"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-activity", {
    t("<VActivityIndicator"),
    i(1, ' size="large"'),
    i(2, ' color="#4f46e5"'),
    t(" />"),
  }))

  table.insert(snippets, s("vn-modal", {
    t('<VModal :visible="'),
    i(1, "showModal"),
    t('" :onRequestClose="() => '),
    i(2, "showModal"),
    t({ ' = false">', "" }),
    t('  <VView :style="'),
    i(3, "styles.modalContent"),
    t({ '">', "" }),
    t("    "),
    i(0),
    t({ "", "  </VView>", "" }),
    t("</VModal>"),
  }))

  table.insert(snippets, s("vn-alert", {
    t({ "<VAlertDialog", "" }),
    t('  :visible="'),
    i(1, "showAlert"),
    t({ '"', "" }),
    t('  title="'),
    i(2, "Alert"),
    t({ '"', "" }),
    t('  message="'),
    i(3, "Are you sure?"),
    t({ '"', "" }),
    t({ '  :buttons="[', "" }),
    t("    { text: 'Cancel', style: 'cancel', onPress: () => "),
    i(4, "showAlert"),
    t({ " = false },", "" }),
    t("    { text: 'OK', onPress: () => { "),
    i(0),
    t("; "),
    i(5, "showAlert"),
    t({ " = false } },", "" }),
    t({ '  ]"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-actionsheet", {
    t({ "<VActionSheet", "" }),
    t('  :visible="'),
    i(1, "showSheet"),
    t({ '"', "" }),
    t('  title="'),
    i(2, "Choose an action"),
    t({ '"', "" }),
    t({ '  :actions="[', "" }),
    t("    { text: '"),
    i(3, "Option 1"),
    t("', onPress: () => { "),
    i(0),
    t({ " } },", "" }),
    t("    { text: 'Cancel', style: 'cancel', onPress: () => "),
    i(4, "showSheet"),
    t({ " = false },", "" }),
    t({ '  ]"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-statusbar", {
    t('<VStatusBar barStyle="'),
    c(1, {
      t("dark-content"),
      t("light-content"),
    }),
    t('" />'),
  }))

  table.insert(snippets, s("vn-webview", {
    t({ "<VWebView", "" }),
    t("  :source=\"{ uri: '"),
    i(1, "https://example.com"),
    t({ "' }\"", "" }),
    t({ '  :style="{ flex: 1 }"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-progress", {
    t('<VProgressBar :progress="'),
    i(1, "0.5"),
    t('" trackColor="'),
    i(2, "#e0e0e0"),
    t('" progressColor="'),
    i(3, "#4f46e5"),
    t('" />'),
  }))

  table.insert(snippets, s("vn-picker", {
    t({ "<VPicker", "" }),
    t('  v-model="'),
    i(1, "selected"),
    t({ '"', "" }),
    t("  :items=\""),
    i(2, "['Option 1', 'Option 2', 'Option 3']"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-segmented", {
    t({ "<VSegmentedControl", "" }),
    t('  v-model="'),
    i(1, "selectedIndex"),
    t({ '"', "" }),
    t("  :values=\""),
    i(2, "['First', 'Second', 'Third']"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-keyboard", {
    t('<VKeyboardAvoiding :style="{ flex: 1 }" behavior="'),
    c(1, {
      t("padding"),
      t("height"),
    }),
    t({ '">', "" }),
    t("  "),
    i(0),
    t({ "", "</VKeyboardAvoiding>" }),
  }))

  table.insert(snippets, s("vn-refresh", {
    t('<VRefreshControl :refreshing="'),
    i(1, "isRefreshing"),
    t('" :onRefresh="'),
    i(2, "handleRefresh"),
    t('" />'),
  }))

  table.insert(snippets, s("vn-pressable", {
    t('<VPressable :onPress="'),
    i(1, "handlePress"),
    t('" :style="'),
    i(2, "styles.pressable"),
    t({ '">', "" }),
    t("  "),
    i(0),
    t({ "", "</VPressable>" }),
  }))

  table.insert(snippets, s("vn-checkbox", {
    t('<VCheckbox v-model="'),
    i(1, "isChecked"),
    t('" label="'),
    i(2, "Accept terms"),
    t('" />'),
  }))

  table.insert(snippets, s("vn-radio", {
    t({ "<VRadio", "" }),
    t('  v-model="'),
    i(1, "selected"),
    t({ '"', "" }),
    t({ "  :options=\"[", "" }),
    t("    { label: '"),
    i(2, "Option A"),
    t("', value: '"),
    i(3, "a"),
    t({ "' },", "" }),
    t("    { label: '"),
    i(4, "Option B"),
    t("', value: '"),
    i(5, "b"),
    t({ "' },", "" }),
    t({ '  ]"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-dropdown", {
    t({ "<VDropdown", "" }),
    t('  v-model="'),
    i(1, "selected"),
    t({ '"', "" }),
    t({ "  :options=\"[", "" }),
    t("    { label: '"),
    i(2, "Option 1"),
    t("', value: '"),
    i(3, "opt1"),
    t({ "' },", "" }),
    t("    { label: '"),
    i(4, "Option 2"),
    t("', value: '"),
    i(5, "opt2"),
    t({ "' },", "" }),
    t({ '  ]"', "" }),
    t('  placeholder="'),
    i(6, "Select an option"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-sectionlist", {
    t({ "<VSectionList", "" }),
    t('  :sections="'),
    i(1, "sections"),
    t({ '"', "" }),
    t('  :renderItem="'),
    i(2, "renderItem"),
    t({ '"', "" }),
    t('  :renderSectionHeader="'),
    i(3, "renderSectionHeader"),
    t({ '"', "" }),
    t('  :keyExtractor="(item) => item.'),
    i(4, "id"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-video", {
    t({ "<VVideo", "" }),
    t("  :source=\"{ uri: '"),
    i(1, "https://example.com/video.mp4"),
    t({ "' }\"", "" }),
    t("  :style=\"{ width: '100%', height: "),
    i(2, "200"),
    t({ ' }"', "" }),
    t({ '  :controls="true"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-errorboundary", {
    t('<VErrorBoundary :fallback="'),
    i(1, "ErrorFallback"),
    t({ '">', "" }),
    t("  "),
    i(0),
    t({ "", "</VErrorBoundary>" }),
  }))

  -- ═══════════════════════════════════════════════════════════
  -- Navigation
  -- ═══════════════════════════════════════════════════════════

  table.insert(snippets, s("vn-routerview", {
    t("<RouterView />"),
  }))

  table.insert(snippets, s("vn-navbar", {
    t({ "<VNavigationBar", "" }),
    t('  title="'),
    i(1, "Title"),
    t({ '"', "" }),
    t({ '  :showBack="router.canGoBack.value"', "" }),
    t({ '  @back="router.pop()"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-tabbar", {
    t({ "<VTabBar", "" }),
    t({ '  :tabs="[', "" }),
    t("    { name: '"),
    i(1, "home"),
    t("', label: '"),
    i(2, "Home"),
    t("', icon: '"),
    i(3, "H"),
    t({ "' },", "" }),
    t("    { name: '"),
    i(4, "settings"),
    t("', label: '"),
    i(5, "Settings"),
    t("', icon: '"),
    i(6, "S"),
    t({ "' },", "" }),
    t({ '  ]"', "" }),
    t('  v-model="'),
    i(7, "activeTab"),
    t({ '"', "" }),
    t("/>"),
  }))

  table.insert(snippets, s("vn-router", {
    t({ "const router = createRouter([", "" }),
    t("  { name: '"),
    i(1, "Home"),
    t("', component: "),
    i(2, "Home"),
    t({ " },", "" }),
    t("  { name: '"),
    i(3, "Detail"),
    t("', component: "),
    i(4, "Detail"),
    t({ " },", "" }),
    t("])"),
  }))

  table.insert(snippets, s("vn-router-options", {
    t({ "const router = createRouter({", "" }),
    t({ "  routes: [", "" }),
    t("    { name: '"),
    i(1, "Home"),
    t("', component: "),
    i(2, "Home"),
    t({ " },", "" }),
    t("    { name: '"),
    i(3, "Detail"),
    t("', component: "),
    i(4, "Detail"),
    t({ " },", "" }),
    t({ "  ],", "" }),
    t({ "  linking: {", "" }),
    t("    prefixes: ['"),
    i(5, "myapp://"),
    t({ "'],", "" }),
    t({ "    config: {", "" }),
    t({ "      screens: {", "" }),
    t("        "),
    i(6, "Home"),
    t({ ": '',", "" }),
    t("        "),
    i(7, "Detail"),
    t(": '"),
    i(8, "detail/:id"),
    t({ "',", "" }),
    t({ "      },", "" }),
    t({ "    },", "" }),
    t({ "  },", "" }),
    t("})"),
  }))

  table.insert(snippets, s("vn-tabs", {
    t({ "const { TabNavigator, activeTab } = createTabNavigator()", "", "" }),
    t({ "// In template:", "" }),
    t({ "// <TabNavigator", "" }),
    t({ '//   :screens="[', "" }),
    t({ "//     { name: 'home', label: 'Home', icon: 'H', component: HomeView },", "" }),
    t({ "//     { name: 'settings', label: 'Settings', icon: 'S', component: SettingsView },", "" }),
    t({ '//   ]"', "" }),
    t({ "// />" }),
  }))

  table.insert(snippets, s("vn-drawer", {
    t({ "const { DrawerNavigator, useDrawer } = createDrawerNavigator()", "", "" }),
    t({ "// In template:", "" }),
    t({ "// <DrawerNavigator", "" }),
    t({ '//   :screens="[', "" }),
    t({ "//     { name: 'home', label: 'Home', icon: 'H', component: HomeView },", "" }),
    t({ "//     { name: 'about', label: 'About', icon: 'A', component: AboutView },", "" }),
    t({ '//   ]"', "" }),
    t({ "// />" }),
  }))

  table.insert(snippets, s("vn-userouter", {
    t({ "const router = useRouter()", "" }),
    t("// router.push('"),
    i(1, "ScreenName"),
    t("', { "),
    i(2, "id: '123'"),
    t({ " })", "" }),
    t({ "// router.pop()", "" }),
    t("// router.replace('"),
    i(3, "ScreenName"),
    t({ "')", "" }),
    t("// router.canGoBack.value"),
  }))

  table.insert(snippets, s("vn-useroute", {
    t({ "const route = useRoute()", "" }),
    t({ "// route.value.name", "" }),
    t("// route.value.params"),
  }))

  table.insert(snippets, s("vn-onfocus", {
    t({ "onScreenFocus(() => {", "" }),
    t("  "),
    i(0),
    t({ "", "})" }),
  }))

  table.insert(snippets, s("vn-onblur", {
    t({ "onScreenBlur(() => {", "" }),
    t("  "),
    i(0),
    t({ "", "})" }),
  }))

  -- ═══════════════════════════════════════════════════════════
  -- Composables
  -- ═══════════════════════════════════════════════════════════

  table.insert(snippets, s("vn-haptics", {
    t({ "const { impact, notification, selection } = useHaptics()", "" }),
    t("// impact('"),
    c(1, { t("light"), t("medium"), t("heavy") }),
    t({ "')", "" }),
    t("// notification('"),
    c(2, { t("success"), t("warning"), t("error") }),
    t({ "')", "" }),
    t("// selection()"),
  }))

  table.insert(snippets, s("vn-storage", {
    t({ "const { getItem, setItem, removeItem } = useAsyncStorage()", "", "" }),
    t("// const value = await getItem('"),
    i(1, "key"),
    t({ "')", "" }),
    t("// await setItem('"),
    i(2, "key"),
    t("', '"),
    i(3, "value"),
    t({ "')", "" }),
    t("// await removeItem('"),
    i(4, "key"),
    t("')"),
  }))

  table.insert(snippets, s("vn-clipboard", {
    t({ "const { getString, setString } = useClipboard()", "" }),
    t("// await setString('"),
    i(1, "text to copy"),
    t({ "')", "" }),
    t("// const text = await getString()"),
  }))

  table.insert(snippets, s("vn-deviceinfo", {
    t("const { platform, model, osVersion, screenWidth, screenHeight } = useDeviceInfo()"),
  }))

  table.insert(snippets, s("vn-usekeyboard", {
    t("const { isVisible, height, dismiss } = useKeyboard()"),
  }))

  table.insert(snippets, s("vn-animation", {
    t("const { value: "),
    i(1, "animValue"),
    t(", timing, spring } = useAnimation("),
    i(2, "0"),
    t({ ")", "", "" }),
    t("// timing({ toValue: "),
    i(3, "1"),
    t(", duration: "),
    i(4, "300"),
    t({ " })", "" }),
    t("// spring({ toValue: "),
    i(5, "1"),
    t(" })"),
  }))

  table.insert(snippets, s("vn-network", {
    t("const { isConnected, connectionType } = useNetwork()"),
  }))

  table.insert(snippets, s("vn-appstate", {
    t({ "const { state } = useAppState()", "" }),
    t("// state.value: 'active' | 'inactive' | 'background'"),
  }))

  table.insert(snippets, s("vn-linking", {
    t({ "const { openURL, canOpenURL, getInitialURL } = useLinking()", "" }),
    t("// await openURL('"),
    i(1, "https://example.com"),
    t("')"),
  }))

  table.insert(snippets, s("vn-share", {
    t({ "const { share } = useShare()", "" }),
    t("// await share({ title: '"),
    i(1, "Title"),
    t("', message: '"),
    i(2, "Check this out!"),
    t("', url: '"),
    i(3, "https://example.com"),
    t("' })"),
  }))

  table.insert(snippets, s("vn-permissions", {
    t({ "const { check, request } = usePermissions()", "" }),
    t("// const status = await check('"),
    c(1, {
      t("camera"),
      t("photos"),
      t("location"),
      t("notifications"),
      t("microphone"),
    }),
    t({ "')", "" }),
    t("// const result = await request('"),
    c(2, {
      t("camera"),
      t("photos"),
      t("location"),
      t("notifications"),
      t("microphone"),
    }),
    t("')"),
  }))

  table.insert(snippets, s("vn-geolocation", {
    t({ "const { getCurrentPosition } = useGeolocation()", "" }),
    t("// const { latitude, longitude } = await getCurrentPosition()"),
  }))

  table.insert(snippets, s("vn-camera", {
    t({ "const { takePhoto, pickImage } = useCamera()", "" }),
    t("// const photo = await takePhoto({ quality: "),
    i(1, "0.8"),
    t({ " })", "" }),
    t("// const image = await pickImage()"),
  }))

  table.insert(snippets, s("vn-notifications", {
    t({ "const { schedule, requestPermission } = useNotifications()", "" }),
    t({ "// await requestPermission()", "" }),
    t("// await schedule({ title: '"),
    i(1, "Title"),
    t("', body: '"),
    i(2, "Message"),
    t("', trigger: { seconds: "),
    i(3, "5"),
    t(" } })"),
  }))

  table.insert(snippets, s("vn-biometry", {
    t({ "const { authenticate, biometryType } = useBiometry()", "" }),
    t("// const result = await authenticate('"),
    i(1, "Confirm your identity"),
    t("')"),
  }))

  table.insert(snippets, s("vn-http", {
    t({ "const { request, get, post } = useHttp()", "", "" }),
    t("// const { data } = await get('"),
    i(1, "https://api.example.com/data"),
    t({ "')", "" }),
    t("// const { data } = await post('"),
    i(2, "https://api.example.com/submit"),
    t("', { body: "),
    i(3, "payload"),
    t(" })"),
  }))

  table.insert(snippets, s("vn-colorscheme", {
    t({ "const colorScheme = useColorScheme()", "" }),
    t("// colorScheme.value: 'light' | 'dark'"),
  }))

  table.insert(snippets, s("vn-backhandler", {
    t({ "useBackHandler(() => {", "" }),
    t("  "),
    i(0),
    t({ "", "  return true // handled", "" }),
    t("})"),
  }))

  table.insert(snippets, s("vn-securestorage", {
    t({ "const { getItem, setItem, removeItem } = useSecureStorage()", "" }),
    t("// await setItem('"),
    i(1, "token"),
    t("', '"),
    i(2, "value"),
    t({ "')", "" }),
    t("// const value = await getItem('"),
    i(3, "token"),
    t("')"),
  }))

  table.insert(snippets, s("vn-websocket", {
    t("const { status, send, close, data } = useWebSocket('"),
    i(1, "wss://example.com/ws"),
    t("')"),
  }))

  table.insert(snippets, s("vn-platform", {
    t("const { platform, isIOS, isAndroid } = usePlatform()"),
  }))

  table.insert(snippets, s("vn-dimensions", {
    t("const { width, height, scale } = useDimensions()"),
  }))

  table.insert(snippets, s("vn-filesystem", {
    t({ "const { readFile, writeFile, deleteFile, exists } = useFileSystem()", "" }),
    t("// await writeFile('"),
    i(1, "path"),
    t("', '"),
    i(2, "content"),
    t({ "')", "" }),
    t("// const content = await readFile('"),
    i(3, "path"),
    t("')"),
  }))

  table.insert(snippets, s("vn-accelerometer", {
    t("const { x, y, z, start, stop } = useAccelerometer()"),
  }))

  table.insert(snippets, s("vn-gyroscope", {
    t("const { x, y, z, start, stop } = useGyroscope()"),
  }))

  table.insert(snippets, s("vn-audio", {
    t({ "const { play, pause, stop, isPlaying } = useAudio()", "" }),
    t("// await play({ uri: '"),
    i(1, "https://example.com/audio.mp3"),
    t("' })"),
  }))

  table.insert(snippets, s("vn-database", {
    t("const { execute, query, transaction } = useDatabase('"),
    i(1, "mydb.sqlite"),
    t({ "')", "" }),
    t("// await execute('CREATE TABLE IF NOT EXISTS "),
    i(2, "items"),
    t({ " (id INTEGER PRIMARY KEY, name TEXT)')", "" }),
    t("// const rows = await query('SELECT * FROM "),
    i(3, "items"),
    t("')"),
  }))

  table.insert(snippets, s("vn-i18n", {
    t("const { locale, t } = useI18n()"),
  }))

  -- ═══════════════════════════════════════════════════════════
  -- Layout Helpers
  -- ═══════════════════════════════════════════════════════════

  table.insert(snippets, s("vn-styles", {
    t({ "const styles = createStyleSheet({", "" }),
    t({ "  container: {", "" }),
    t({ "    flex: 1,", "" }),
    t("    "),
    i(0),
    t({ "", "  },", "" }),
    t("})"),
  }))

  table.insert(snippets, s("vn-row", {
    t("<VView :style=\"{ flexDirection: 'row', alignItems: '"),
    c(1, {
      t("center"),
      t("flex-start"),
      t("flex-end"),
      t("stretch"),
    }),
    t("', gap: "),
    i(2, "8"),
    t({ ' }">',  "" }),
    t("  "),
    i(0),
    t({ "", "</VView>" }),
  }))

  table.insert(snippets, s("vn-column", {
    t("<VView :style=\"{ flex: 1, alignItems: '"),
    c(1, {
      t("center"),
      t("flex-start"),
      t("flex-end"),
      t("stretch"),
    }),
    t("', gap: "),
    i(2, "8"),
    t({ ' }">',  "" }),
    t("  "),
    i(0),
    t({ "", "</VView>" }),
  }))

  table.insert(snippets, s("vn-center", {
    t({ "<VView :style=\"{ flex: 1, justifyContent: 'center', alignItems: 'center' }\">", "" }),
    t("  "),
    i(0),
    t({ "", "</VView>" }),
  }))

  table.insert(snippets, s("vn-vshow", {
    t('v-show="'),
    i(1, "isVisible"),
    t('"'),
  }))

  -- Register all snippets for vue filetype
  luasnip.add_snippets("vue", snippets)

  -- Also register script-block snippets for typescript (for main.ts files)
  local ts_snippets = {}
  local ts_prefixes = {
    "vn-main", "vn-config", "vn-router", "vn-router-options", "vn-tabs",
    "vn-drawer", "vn-userouter", "vn-useroute", "vn-styles",
    "vn-haptics", "vn-storage", "vn-clipboard", "vn-deviceinfo",
    "vn-usekeyboard", "vn-animation", "vn-network", "vn-appstate",
    "vn-linking", "vn-share", "vn-permissions", "vn-geolocation",
    "vn-camera", "vn-notifications", "vn-biometry", "vn-http",
    "vn-colorscheme", "vn-backhandler", "vn-securestorage", "vn-websocket",
    "vn-platform", "vn-dimensions", "vn-filesystem", "vn-accelerometer",
    "vn-gyroscope", "vn-audio", "vn-database", "vn-i18n",
    "vn-onfocus", "vn-onblur",
  }
  local ts_prefix_set = {}
  for _, prefix in ipairs(ts_prefixes) do
    ts_prefix_set[prefix] = true
  end
  for _, snip in ipairs(snippets) do
    if ts_prefix_set[snip.trigger] then
      table.insert(ts_snippets, snip)
    end
  end
  luasnip.add_snippets("typescript", ts_snippets)
end

return M
