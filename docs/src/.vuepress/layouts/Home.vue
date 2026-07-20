<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import ParentLayout from '@vuepress/theme-default/layouts/Layout.vue'

// ---------------------------------------------------------------------
// Section refs (used to place one "▸" fold-marker per section in the
// decorative gutter, aligned with that section's tag header)
// ---------------------------------------------------------------------
const gutterEl = ref<HTMLElement | null>(null)
const contentEl = ref<HTMLElement | null>(null)
const heroSection = ref<HTMLElement | null>(null)
const wedgeSection = ref<HTMLElement | null>(null)
const templateSection = ref<HTMLElement | null>(null)
const nativeSection = ref<HTMLElement | null>(null)
const capabilitiesSection = ref<HTMLElement | null>(null)
const statusSection = ref<HTMLElement | null>(null)
const quickstartSection = ref<HTMLElement | null>(null)
const footerSection = ref<HTMLElement | null>(null)

interface GutterMark {
  id: string
  top: number
}
const gutterMarks = ref<GutterMark[]>([])

function computeGutter(): void {
  if (typeof window === 'undefined' || !gutterEl.value) return
  const baseTop = gutterEl.value.offsetTop
  const sections: [string, HTMLElement | null][] = [
    ['hero', heroSection.value],
    ['wedge', wedgeSection.value],
    ['template', templateSection.value],
    ['native', nativeSection.value],
    ['capabilities', capabilitiesSection.value],
    ['status', statusSection.value],
    ['quickstart', quickstartSection.value],
    ['footer', footerSection.value],
  ]
  gutterMarks.value = sections
    .filter((entry): entry is [string, HTMLElement] => entry[1] !== null)
    .map(([id, el]) => {
      // Anchor to the section's own tag header (`.vn-tag`, e.g. "// status")
      // so the marker sits level with it rather than the section's padded
      // box edge. Hero has no .vn-tag, so fall back to its title.
      const header = el.querySelector<HTMLElement>('.vn-tag, .vn-hero__title') ?? el
      return { id, top: header.offsetTop - baseTop }
    })
}

// ---------------------------------------------------------------------
// Hero leader-line SVG — anchors token spans to margin annotations
// ---------------------------------------------------------------------
const heroCodeWrap = ref<HTMLElement | null>(null)
const codePanelEl = ref<HTMLElement | null>(null)
const svgEl = ref<SVGSVGElement | null>(null)

const tokRefEl = ref<HTMLElement | null>(null)
const tokTextEl = ref<HTMLElement | null>(null)
const tokButtonEl = ref<HTMLElement | null>(null)
const annRefEl = ref<HTMLElement | null>(null)
const annTextEl = ref<HTMLElement | null>(null)
const annButtonEl = ref<HTMLElement | null>(null)

interface LeaderPath {
  id: string
  d: string
}
const leaderPaths = ref<LeaderPath[]>([])
const pathEls: (SVGPathElement | null)[] = []
function setPathRef(el: Element | null, i: number): void {
  pathEls[i] = (el as SVGPathElement) ?? null
}

const linesDrawn = ref(false)

function computeLeaderLines(): void {
  if (typeof window === 'undefined' || !heroCodeWrap.value || !svgEl.value || !codePanelEl.value) return
  if (window.innerWidth < 960) return

  const wrapRect = heroCodeWrap.value.getBoundingClientRect()
  const panelRect = codePanelEl.value.getBoundingClientRect()
  const pairs: [HTMLElement | null, HTMLElement | null, string][] = [
    [tokRefEl.value, annRefEl.value, 'ref'],
    [tokTextEl.value, annTextEl.value, 'text'],
    [tokButtonEl.value, annButtonEl.value, 'button'],
  ]

  const next: LeaderPath[] = []
  pairs.forEach(([tok, ann, id]) => {
    if (!tok || !ann) return
    const t = tok.getBoundingClientRect()
    const a = ann.getBoundingClientRect()
    // Anchor at the code panel's right edge (not the token itself) so the
    // curve never draws back across the code text — it only ever occupies
    // the gap between the panel and the annotation chips.
    const startX = panelRect.right - wrapRect.left - 4
    const startY = t.top + t.height / 2 - wrapRect.top
    const endX = a.left - wrapRect.left
    const endY = a.top + a.height / 2 - wrapRect.top
    const midX = startX + (endX - startX) * 0.55
    next.push({
      id,
      d: `M ${startX.toFixed(1)} ${startY.toFixed(1)} C ${midX.toFixed(1)} ${startY.toFixed(1)}, ${midX.toFixed(1)} ${endY.toFixed(1)}, ${endX.toFixed(1)} ${endY.toFixed(1)}`,
    })
  })

  svgEl.value.setAttribute('viewBox', `0 0 ${wrapRect.width.toFixed(1)} ${wrapRect.height.toFixed(1)}`)
  leaderPaths.value = next

  void nextTick(() => {
    pathEls.forEach((el, i) => {
      if (!el) return
      try {
        const len = el.getTotalLength()
        el.style.setProperty('--len', String(len))
        el.style.setProperty('--delay', `${i * 120}ms`)
      } catch {
        // zero-length / unmeasurable path — safe to ignore, falls back to CSS default
      }
    })
  })
}

// ---------------------------------------------------------------------
// Shared debounced resize/measure lifecycle
// ---------------------------------------------------------------------
let resizeObserver: ResizeObserver | undefined
let intersectionObserver: IntersectionObserver | undefined
let resizeTimer: ReturnType<typeof setTimeout> | undefined

function debounce(fn: () => void, wait: number): () => void {
  return () => {
    if (resizeTimer) clearTimeout(resizeTimer)
    resizeTimer = setTimeout(fn, wait)
  }
}

const recompute = debounce(() => {
  computeGutter()
  computeLeaderLines()
}, 150)

onMounted(() => {
  if (typeof window === 'undefined') return

  void nextTick(() => {
    computeGutter()
    computeLeaderLines()
  })

  window.addEventListener('resize', recompute)
  window.addEventListener('load', recompute)

  if ('ResizeObserver' in window && contentEl.value) {
    resizeObserver = new ResizeObserver(() => recompute())
    resizeObserver.observe(contentEl.value)
  }

  const prefersReducedMotion =
    'matchMedia' in window && window.matchMedia('(prefers-reduced-motion: reduce)').matches

  if (prefersReducedMotion) {
    linesDrawn.value = true
  } else if (heroCodeWrap.value && 'IntersectionObserver' in window) {
    intersectionObserver = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            linesDrawn.value = true
            intersectionObserver?.disconnect()
          }
        })
      },
      { threshold: 0.35 },
    )
    intersectionObserver.observe(heroCodeWrap.value)
  } else {
    linesDrawn.value = true
  }
})

onBeforeUnmount(() => {
  if (typeof window === 'undefined') return
  window.removeEventListener('resize', recompute)
  window.removeEventListener('load', recompute)
  resizeObserver?.disconnect()
  intersectionObserver?.disconnect()
  if (resizeTimer) clearTimeout(resizeTimer)
})

// ---------------------------------------------------------------------
// Smooth-scroll for the "Run it in five minutes ↓" secondary CTA
// ---------------------------------------------------------------------
function smoothScrollTo(id: string) {
  return (event: MouseEvent): void => {
    if (typeof window === 'undefined' || typeof document === 'undefined') return
    const target = document.getElementById(id)
    if (!target) return
    event.preventDefault()
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    target.scrollIntoView({ behavior: prefersReducedMotion ? 'auto' : 'smooth', block: 'start' })
  }
}

// ---------------------------------------------------------------------
// Copy-to-clipboard for the quick-start terminal panel (event-handler only)
// ---------------------------------------------------------------------
const copiedBlock = ref<string | null>(null)
function copyCommand(text: string, id: string): void {
  if (typeof navigator === 'undefined' || !navigator.clipboard) return
  navigator.clipboard
    .writeText(text)
    .then(() => {
      copiedBlock.value = id
      setTimeout(() => {
        if (copiedBlock.value === id) copiedBlock.value = null
      }, 1600)
    })
    .catch(() => {
      // clipboard permission denied — fail silently, button just won't confirm
    })
}

const quickStartBlocks = [
  {
    id: 'create',
    comment: '',
    command: 'bunx @thelacanians/vue-native-cli create my-app\ncd my-app\nbun install',
  },
  {
    id: 'dev',
    comment: '# terminal 1 — dev server',
    command: 'bunx @thelacanians/vue-native-cli dev --ios     # or --android',
  },
  {
    id: 'run',
    comment: '# terminal 2 — build & launch',
    command: 'bunx @thelacanians/vue-native-cli run ios       # or: run android',
  },
]

// ---------------------------------------------------------------------
// The interlinear correspondence table.
// iOS/Android VERIFIED against docs/src/components/*.md and
// docs/src/guide/components.md (the site's own authoritative comparison
// table). macOS VERIFIED against the native/macos/VueNativeMacOS factory
// sources (view factories for each component) — restored after previously
// being omitted for lack of doc backing.
// ---------------------------------------------------------------------
interface CorrespondenceRow {
  source: string
  targets: { platform: string; label: string; color: string }[]
}
const correspondence: CorrespondenceRow[] = [
  {
    source: 'VView',
    targets: [
      { platform: 'iOS', label: 'UIView', color: 'var(--vn-ios)' },
      { platform: 'Android', label: 'FlexboxLayout', color: 'var(--vn-android)' },
      { platform: 'macOS', label: 'NSView (FlippedView)', color: 'var(--vn-macos)' },
    ],
  },
  {
    source: 'VText',
    targets: [
      { platform: 'iOS', label: 'UILabel', color: 'var(--vn-ios)' },
      { platform: 'Android', label: 'TextView', color: 'var(--vn-android)' },
      { platform: 'macOS', label: 'NSTextField (label)', color: 'var(--vn-macos)' },
    ],
  },
  {
    source: 'VButton',
    targets: [
      { platform: 'iOS', label: 'UIControl-based view', color: 'var(--vn-ios)' },
      { platform: 'Android', label: 'Custom touch delegate', color: 'var(--vn-android)' },
      { platform: 'macOS', label: 'ClickableView (NSView)', color: 'var(--vn-macos)' },
    ],
  },
  {
    source: 'VInput',
    targets: [
      { platform: 'iOS', label: 'UITextField / UITextView', color: 'var(--vn-ios)' },
      { platform: 'Android', label: 'EditText', color: 'var(--vn-android)' },
      { platform: 'macOS', label: 'NSTextField', color: 'var(--vn-macos)' },
    ],
  },
  {
    source: 'VList',
    targets: [
      { platform: 'iOS', label: 'UITableView', color: 'var(--vn-ios)' },
      { platform: 'Android', label: 'RecyclerView', color: 'var(--vn-android)' },
      { platform: 'macOS', label: 'NSTableView', color: 'var(--vn-macos)' },
    ],
  },
  {
    source: 'VImage',
    targets: [
      { platform: 'iOS', label: 'UIImageView', color: 'var(--vn-ios)' },
      { platform: 'Android', label: 'ImageView (Coil)', color: 'var(--vn-android)' },
      { platform: 'macOS', label: 'NSImageView', color: 'var(--vn-macos)' },
    ],
  },
  {
    source: 'VScrollView',
    targets: [
      { platform: 'iOS', label: 'UIScrollView', color: 'var(--vn-ios)' },
      { platform: 'Android', label: 'ScrollView', color: 'var(--vn-android)' },
      { platform: 'macOS', label: 'NSScrollView', color: 'var(--vn-macos)' },
    ],
  },
]
</script>

<template>
  <ParentLayout>
    <template #page>
      <main class="vn-home">
        <div ref="gutterEl" class="vn-gutter" aria-hidden="true">
          <span
            v-for="mark in gutterMarks"
            :key="mark.id"
            class="vn-gutter__mark"
            :style="{ top: `${mark.top}px` }"
          >▸</span>
        </div>

        <div ref="contentEl" class="vn-content">
          <!-- ============================================================ -->
          <!-- 1. HERO                                                      -->
          <!-- ============================================================ -->
          <section ref="heroSection" class="vn-section vn-hero">
            <h1 class="vn-hero__title">
              Real native apps. Written in the <span class="vn-hero__accent">Vue</span> you already know.
            </h1>
            <p class="vn-hero__subline">
              Your Vue 3 components render as actual UIKit, Android, and AppKit views — no WebView, no DOM, no new
              component model to learn.
            </p>
            <div class="vn-hero__ctas">
              <a class="vn-btn vn-btn--primary" href="/guide/">Get started</a>
              <a class="vn-btn vn-btn--ghost" href="#quick-start" @click="smoothScrollTo('quick-start')">
                Run it in five minutes ↓
              </a>
            </div>

            <div ref="heroCodeWrap" class="vn-hero-code-wrap">
              <div ref="codePanelEl" class="vn-codepanel">
                <div class="vn-codepanel__title">App.vue</div>
                <pre class="vn-code"><code>&lt;<span class="tok-kw">script</span> setup <span class="tok-kw">lang</span>=<span class="tok-str">"ts"</span>&gt;
<span class="tok-kw">import</span> { ref, createStyleSheet }
  <span class="tok-kw">from</span> <span class="tok-str">'@thelacanians/vue-native-runtime'</span>

<span class="tok-kw">const</span> count = <span ref="tokRefEl" class="tok-anchor tok-kw">ref</span>(<span class="tok-num">0</span>)

<span class="tok-kw">const</span> styles = <span class="tok-fn">createStyleSheet</span>({
  container: {
    flex: <span class="tok-num">1</span>,
    alignItems: <span class="tok-str">'center'</span>,
    justifyContent: <span class="tok-str">'center'</span>,
  },
  button: {
    backgroundColor: <span class="tok-str">'#007AFF'</span>,
    paddingHorizontal: <span class="tok-num">24</span>,
    paddingVertical: <span class="tok-num">12</span>,
    borderRadius: <span class="tok-num">8</span>,
  },
})
&lt;/<span class="tok-kw">script</span>&gt;

&lt;<span class="tok-kw">template</span>&gt;
  &lt;<span class="tok-tag">VView</span> :style=<span class="tok-str">"styles.container"</span>&gt;
    &lt;<span ref="tokTextEl" class="tok-anchor tok-tag">VText</span>&gt;Count: {{ count }}&lt;/<span class="tok-tag">VText</span>&gt;
    &lt;<span ref="tokButtonEl" class="tok-anchor tok-tag">VButton</span> :style=<span class="tok-str">"styles.button"</span> <span class="tok-tag">@press</span>=<span class="tok-str">"count++"</span>&gt;
      &lt;<span class="tok-tag">VText</span>&gt;Increment&lt;/<span class="tok-tag">VText</span>&gt;
    &lt;/<span class="tok-tag">VButton</span>&gt;
  &lt;/<span class="tok-tag">VView</span>&gt;
&lt;/<span class="tok-kw">template</span>&gt;</code></pre>
              </div>

              <div class="vn-annotations" :class="{ 'is-drawn': linesDrawn }">
                <div ref="annRefEl" class="vn-chip vn-chip--ref">
                  Vue 3 reactivity — the real <code>vue</code> package, not a fork.
                </div>
                <div ref="annTextEl" class="vn-gloss">
                  <div class="vn-gloss__source">VText</div>
                  <div class="vn-gloss__row"><span class="vn-gloss__branch">├─</span> <span class="vn-gloss__platform" style="color: var(--vn-ios)">iOS</span> <span class="vn-gloss__label">UILabel</span></div>
                  <div class="vn-gloss__row"><span class="vn-gloss__branch">├─</span> <span class="vn-gloss__platform" style="color: var(--vn-android)">Android</span> <span class="vn-gloss__label">android.widget.TextView</span></div>
                  <div class="vn-gloss__row"><span class="vn-gloss__branch">└─</span> <span class="vn-gloss__platform" style="color: var(--vn-macos)">macOS</span> <span class="vn-gloss__label">NSTextField (label)</span></div>
                </div>
                <div ref="annButtonEl" class="vn-chip vn-chip--button">
                  A real native control — <code>@press</code> is platform touch, not a DOM click.
                </div>
              </div>

              <svg
                ref="svgEl"
                class="vn-leaderlines"
                :class="{ 'is-drawn': linesDrawn }"
                aria-hidden="true"
                preserveAspectRatio="none"
              >
                <path
                  v-for="(p, i) in leaderPaths"
                  :key="p.id"
                  :ref="(el) => setPathRef(el as Element | null, i)"
                  :d="p.d"
                  :class="`vn-leaderlines__path vn-leaderlines__path--${p.id}`"
                />
              </svg>

              <ul class="vn-caption-list">
                <li><code>ref(0)</code> — Vue 3 reactivity — the real <code>vue</code> package, not a fork.</li>
                <li>
                  <code>VText</code>
                  — iOS <code>UILabel</code>, Android <code>android.widget.TextView</code>, macOS
                  <code>NSTextField</code> (label).
                </li>
                <li><code>VButton</code> — A real native control — <code>@press</code> is platform touch, not a DOM click.</li>
              </ul>
            </div>

            <p class="vn-hero__caption">
              This is a real iOS and Android app. <code>count</code> is Vue reactivity. <code>VText</code> renders as
              a real UILabel.
            </p>
          </section>

          <!-- ============================================================ -->
          <!-- 2. WHY NOT JUST USE...                                       -->
          <!-- ============================================================ -->
          <section ref="wedgeSection" class="vn-section vn-wedge">
            <p class="vn-tag vn-tag--comment">&lt;!-- why not just use… --&gt;</p>
            <h2 class="vn-subhead">Why not just use what's already there?</h2>

            <div class="vn-wedge__columns">
              <div class="vn-wedge__col">
                <h3 class="vn-wedge__title">Capacitor / Ionic</h3>
                <p class="vn-wedge__body">Your Vue, but inside a WebView. You ship a browser.</p>
              </div>
              <div class="vn-wedge__col">
                <h3 class="vn-wedge__title">React Native / Flutter</h3>
                <p class="vn-wedge__body">Truly native — if you leave Vue for JSX or Dart.</p>
              </div>
              <div class="vn-wedge__col vn-wedge__col--ours">
                <h3 class="vn-wedge__title">Vue Native</h3>
                <p class="vn-wedge__body">Truly native, in the Vue you already write. Real platform views, nothing to relearn.</p>
              </div>
            </div>

            <p class="vn-wedge__footer">
              <span class="vn-dot vn-dot--amber" aria-hidden="true" /> Not a drop-in for every Vue app: no DOM or
              <code>window</code>, no vue-router (use <code>@thelacanians/vue-native-navigation</code>), and styling
              is a flexbox subset via typed style objects — not CSS files.
              <a href="/guide/limitations.html">Read the limitations →</a>
            </p>
          </section>

          <!-- ============================================================ -->
          <!-- 3. <template> — the correspondence                           -->
          <!-- ============================================================ -->
          <section ref="templateSection" class="vn-section vn-template">
            <p class="vn-tag vn-tag--kw">&lt;template&gt;</p>
            <h2 class="vn-subhead">Every component has three names.</h2>
            <p class="vn-standfirst">
              You write one. A Vue custom renderer speaks all three — driving UIKit, AppKit, and Android Views
              directly. Not a WebView. Not the DOM.
            </p>

            <div class="vn-glossary">
              <div v-for="row in correspondence" :key="row.source" class="vn-glossary__row">
                <div class="vn-glossary__source">{{ row.source }}</div>
                <div class="vn-glossary__targets">
                  <div
                    v-for="(t, i) in row.targets"
                    :key="t.platform"
                    class="vn-glossary__target"
                  >
                    <span class="vn-glossary__branch">{{ i === row.targets.length - 1 ? '└─' : '├─' }}</span>
                    <span class="vn-glossary__platform" :style="{ color: t.color }">{{ t.platform }}</span>
                    <span class="vn-glossary__label">{{ t.label }}</span>
                  </div>
                </div>
              </div>
            </div>
            <p class="vn-glossary__note">
              macOS-only components (VToolbar, VSplitView, VOutlineView) aren't shown here — see the
              <a href="/macos/">macOS guide</a>.
            </p>

            <div class="vn-chips-row">
              <span v-for="c in ['ref', 'computed', 'watch', 'v-model', 'v-for', 'v-if', '<script setup>']" :key="c" class="vn-chip-pill">{{ c }}</span>
            </div>
            <p class="vn-chips-row__caption">All of it runs unmodified.</p>

            <p class="vn-tag vn-tag--comment">// createRenderer → NativeBridge → per-platform native factories</p>
          </section>

          <!-- ============================================================ -->
          <!-- 4. <native platform="ios"> — the escape hatch                -->
          <!-- ============================================================ -->
          <section ref="nativeSection" class="vn-section vn-native">
            <p class="vn-tag vn-tag--native">&lt;native platform="ios"&gt;</p>
            <h2 class="vn-subhead">Need Swift or Kotlin? Write it in the same file.</h2>
            <p class="vn-standfirst">
              Drop a <code>&lt;native&gt;</code> block into your component with real Swift or Kotlin. Codegen writes
              the native module, its TypeScript types, and the registration.
            </p>

            <div class="vn-native__flow">
              <div class="vn-codepanel vn-codepanel--native">
                <div class="vn-codepanel__title">Haptics.vue</div>
                <pre class="vn-code vn-code--plain"><code>&lt;native platform="ios"&gt;
class HapticsModule: NativeModule {
  var moduleName: String { "Haptics" }

  func invoke(
    method: String,
    args: [Any],
    callback: @escaping (Any?, String?) -> Void
  ) {
    switch method {
    case "vibrate":
      let style = args[0] as? String
        ?? "medium"
      vibrate(style: style)
      callback(nil, nil)
    default:
      callback(nil, "Unknown method: \(method)")
    }
  }

  func vibrate(style: String) {
    let generator =
      UIImpactFeedbackGenerator(style: .medium)
    generator.prepare()
    generator.impactOccurred()
  }
}
&lt;/native&gt;</code></pre>
              </div>

              <div class="vn-native__arrow" aria-hidden="true">codegen <span class="vn-native__arrow-glyph"></span></div>

              <div class="vn-codepanel vn-codepanel--native vn-codepanel--generated">
                <div class="vn-codepanel__title">generated/useHaptics.ts</div>
                <pre class="vn-code vn-code--plain"><code>const { vibrate } = useHaptics()
await vibrate('medium')</code></pre>
              </div>
            </div>

            <p class="vn-native__smallprint">
              Kotlin via <code>&lt;native platform="android"&gt;</code>.
              <a href="/guide/native-blocks.html">Native blocks guide →</a>
            </p>
          </section>

          <!-- ============================================================ -->
          <!-- 5. capabilities                                              -->
          <!-- ============================================================ -->
          <section ref="capabilitiesSection" class="vn-section vn-capabilities">
            <p class="vn-tag vn-tag--tagword">capabilities</p>
            <h2 class="vn-subhead">Real enough to build with.</h2>

            <ul class="vn-token-list">
              <li>
                <a href="/components/">30+ built-in components</a> — VView, VText, VButton, VInput, VList,
                VScrollView, VImage, VModal, VPicker, VTabBar, VNavigationBar…
              </li>
              <li>
                <a href="/composables/">40+ composables</a> — useCamera, useGeolocation, useBiometry, useHaptics,
                useAsyncStorage, useHttp, useWebSocket, useNotifications…
              </li>
              <li><a href="/navigation/">Native stack, tab &amp; drawer navigation</a></li>
              <li>
                <a href="https://github.com/abdul-hamid-achik/vue-native/tree/main/examples">17 runnable example apps</a>
                — auth, chat, camera, media player, macOS showcase…
              </li>
            </ul>
          </section>

          <!-- ============================================================ -->
          <!-- 6. // status                                                 -->
          <!-- ============================================================ -->
          <section ref="statusSection" class="vn-section vn-status">
            <p class="vn-tag vn-tag--comment">// status</p>
            <h2 class="vn-subhead">The honest version.</h2>

            <ul class="vn-status__matrix">
              <li><span class="vn-dot vn-dot--green" aria-hidden="true" /> iOS — production path</li>
              <li><span class="vn-dot vn-dot--green" aria-hidden="true" /> Android — production path</li>
              <li>
                <span class="vn-dot vn-dot--amber" aria-hidden="true" /> macOS — runtime available, manual setup;
                <code>create</code> doesn't scaffold the app shell yet
              </li>
            </ul>

            <p class="vn-status__note">
              Pre-1.0 and hardening fast — memory-leak and race-condition fixes shipped across the
              iOS/Android bridge in recent releases. Flexbox subset, no browser globals. The dev watcher targets one
              platform at a time. Bun-first toolchain (Bun 1.3+; Node 20.19+ on the npm path). Small, focused, built
              in the open.
            </p>
          </section>

          <!-- ============================================================ -->
          <!-- 7. $ quick-start                                             -->
          <!-- ============================================================ -->
          <section id="quick-start" ref="quickstartSection" class="vn-section vn-quickstart">
            <p class="vn-tag vn-tag--prompt">$ quick-start</p>
            <h2 class="vn-subhead">Running in about five minutes.</h2>

            <div class="vn-terminal">
              <div v-for="block in quickStartBlocks" :key="block.id" class="vn-terminal__block">
                <p v-if="block.comment" class="vn-terminal__comment">{{ block.comment }}</p>
                <div class="vn-terminal__row">
                  <pre class="vn-terminal__code"><code>{{ block.command }}</code></pre>
                  <button
                    type="button"
                    class="vn-copy-btn"
                    :aria-label="`Copy command: ${block.command}`"
                    @click="copyCommand(block.command, block.id)"
                  >
                    {{ copiedBlock === block.id ? 'Copied' : 'Copy' }}
                  </button>
                </div>
              </div>
            </div>

            <p class="vn-quickstart__note">Hot reload of .vue files on device and emulator. One watcher per platform.</p>
            <p class="vn-quickstart__links">
              <a href="/guide/installation.html">Full install guide →</a>
              ·
              <a href="/guide/your-first-app.html">Your first app →</a>
            </p>
          </section>

          <!-- ============================================================ -->
          <!-- 8. </style> — footer                                         -->
          <!-- ============================================================ -->
          <footer ref="footerSection" class="vn-section vn-footer">
            <p class="vn-tag vn-tag--kw">&lt;/style&gt;</p>
            <nav class="vn-footer__links" aria-label="Footer">
              <a href="https://github.com/abdul-hamid-achik/vue-native">GitHub</a>
              <a href="https://github.com/abdul-hamid-achik/vue-native/tree/main/examples">Examples</a>
              <a href="/guide/">Guide</a>
              <a href="/components/">Components</a>
              <span>MIT Licensed</span>
            </nav>
            <p class="vn-footer__signoff">// Vue-first. Genuinely native. Honest about the rest.</p>
          </footer>
        </div>
      </main>
    </template>
  </ParentLayout>
</template>

<style lang="scss" scoped>
// ---------------------------------------------------------------------
// Layout shell: page gutter + centered content column
// ---------------------------------------------------------------------
.vn-home {
  display: flex;
  align-items: flex-start;
  min-height: calc(100vh - var(--navbar-height));
  padding-top: var(--navbar-height);
  background: var(--vn-paper);
  color: var(--vn-ink);
  font-family: var(--font-family);
}

.vn-gutter {
  position: sticky;
  top: var(--navbar-height);
  flex: 0 0 3.5rem;
  width: 3.5rem;
  height: calc(100vh - var(--navbar-height));
  overflow: hidden;
  // Faint boundary where the gutter column meets the content, so the left
  // edge still reads as intentional even between markers.
  border-right: 1px solid color-mix(in srgb, var(--vn-comment) 25%, transparent);
  user-select: none;

  @media (max-width: 959px) {
    flex-basis: 3px;
    width: 3px;
    border-right: none;
    background: linear-gradient(
      to bottom,
      var(--vn-keyword),
      var(--vn-string) 35%,
      var(--vn-fn) 65%,
      var(--vn-native)
    );
  }

  @media (max-width: 718px) {
    display: none;
  }
}

.vn-gutter__mark {
  position: absolute;
  right: 0.85rem;
  font-family: var(--vn-font-mono);
  font-size: 0.78rem;
  line-height: 1;
  // ~40% dimmer than a plain --vn-comment gutter glyph — quiet texture,
  // not content.
  color: color-mix(in srgb, var(--vn-comment) 60%, transparent);

  @media (max-width: 959px) {
    display: none;
  }
}

.vn-content {
  flex: 1 1 auto;
  min-width: 0;
  padding: 2.5rem 1.5rem 6rem;

  @media (max-width: 719px) {
    padding: 2rem 1.25rem 4rem;
  }
}

.vn-section {
  max-width: var(--homepage-width);
  margin: 0 auto;
  padding-block: 4.5rem;
  border-top: 1px solid var(--vp-c-divider);

  @media (max-width: 719px) {
    padding-block: 3rem;
  }
}

.vn-hero {
  border-top: none;
  padding-top: 1.5rem;
}

// ---------------------------------------------------------------------
// Shared type primitives
// ---------------------------------------------------------------------
.vn-tag {
  font-family: var(--vn-font-mono);
  font-size: 0.85rem;
  font-feature-settings: 'liga' 0;
  margin: 0 0 1rem;
}

.vn-tag--comment {
  color: var(--vn-comment);
  font-style: italic;
}

.vn-tag--kw {
  color: var(--vn-keyword);
  font-weight: 700;
}

.vn-tag--native {
  color: var(--vn-native);
  font-weight: 700;
}

.vn-tag--tagword {
  color: var(--vn-string);
  font-weight: 700;
}

.vn-tag--prompt {
  color: var(--vn-string);
  font-weight: 700;
}

.vn-subhead {
  font-family: var(--vn-font-display);
  font-weight: 600;
  font-size: 1.6rem;
  line-height: 1.25;
  margin: 0 0 1rem;
  color: var(--vn-ink);
}

.vn-standfirst {
  font-size: 1.0625rem;
  line-height: 1.7;
  color: var(--vp-c-text-mute);
  max-width: 44rem;
  margin: 0 0 2rem;
}

// ---------------------------------------------------------------------
// 1. HERO
// ---------------------------------------------------------------------
.vn-hero__title {
  font-family: var(--vn-font-mono);
  font-weight: 700;
  font-size: clamp(2.1rem, 5vw, 3.4rem);
  letter-spacing: -0.02em;
  line-height: 1.1;
  margin: 0 0 1.25rem;
  color: var(--vn-ink);
}

.vn-hero__accent {
  color: var(--vn-keyword);
}

.vn-hero__subline {
  font-size: 1.0625rem;
  line-height: 1.7;
  color: var(--vp-c-text-mute);
  max-width: 40rem;
  margin: 0 0 2rem;
}

.vn-hero__ctas {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 1.25rem;
  margin-bottom: 3rem;
}

.vn-btn {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-family: var(--vn-font-mono);
  font-weight: 500;
  font-size: 0.95rem;
  text-decoration: none;
  transition: opacity var(--vp-t-color, 0.2s ease);
}

.vn-btn--primary {
  background: var(--vn-ink);
  color: var(--vn-paper);
}

.vn-btn--primary:hover {
  opacity: 0.85;
}

:root[data-theme='dark'] .vn-btn--primary,
[data-theme='dark'] .vn-btn--primary {
  // Dark --vn-paper equals the page bg, so the light-pill-on-dark-text
  // treatment above would render as bare text. Use --vn-ink instead: in
  // dark mode it's the light token (#e5e7f0), giving a light pill with
  // dark text — mirroring light mode's dark pill.
  background: var(--vn-ink);
  color: var(--vn-paper);
}

:root[data-theme='dark'] .vn-btn--primary:hover,
[data-theme='dark'] .vn-btn--primary:hover {
  opacity: 0.85;
}

.vn-btn--ghost {
  color: var(--vn-keyword);
  padding-inline: 0.25rem;
}

.vn-btn--ghost:hover {
  text-decoration: underline;
}

.vn-hero-code-wrap {
  position: relative;
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr);
  gap: 2.5rem;
  align-items: start;

  @media (max-width: 959px) {
    grid-template-columns: minmax(0, 1fr);
  }
}

.vn-codepanel {
  position: relative;
  z-index: 1;
  min-width: 0;
  background: var(--vn-panel);
  border: 1px solid var(--vp-c-divider);
  border-radius: 10px;
  overflow: hidden;
}

.vn-codepanel__title {
  font-family: var(--vn-font-mono);
  font-size: 0.78rem;
  color: var(--vn-comment);
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--vp-c-divider);
}

.vn-code {
  margin: 0;
  max-width: 100%;
  padding: 1rem 1.25rem;
  overflow-x: auto;
  font-family: var(--vn-font-mono);
  font-size: 0.9rem;
  line-height: 1.6;
  color: var(--vn-ink);
}

.vn-code code {
  font-family: inherit;
}

.tok-kw {
  color: var(--vn-keyword);
}

.tok-str {
  color: var(--vn-string);
}

.tok-tag {
  color: var(--vn-string);
}

.tok-fn {
  color: var(--vn-fn);
}

.tok-num {
  color: var(--vn-native);
}

.tok-anchor {
  border-bottom: 2px solid currentColor;
  padding-bottom: 1px;
}

@media (prefers-reduced-motion: no-preference) {
  .vn-annotations.is-drawn .tok-anchor {
    animation: vn-pulse 700ms ease;
  }
}

@keyframes vn-pulse {
  0% {
    filter: brightness(1);
  }
  35% {
    filter: brightness(1.6);
  }
  100% {
    filter: brightness(1);
  }
}

.vn-annotations {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  // Distribute the three annotations down the full height of the code
  // panel (align-self: stretch, since the grid row's height is set by the
  // taller App.vue panel) instead of clustering at the top and leaving a
  // void below — roughly aligns each chip with its token's vertical
  // position (ref near the top, VText gloss mid-panel, @press near the
  // bottom).
  justify-content: space-between;
  align-self: stretch;
  gap: 1.5rem;
  padding-top: 0.5rem;

  @media (max-width: 959px) {
    display: none;
  }
}

.vn-chip {
  font-family: var(--vn-font-mono);
  font-size: 0.85rem;
  line-height: 1.5;
  background: var(--vn-panel);
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  padding: 0.75rem 1rem;
}

.vn-chip--ref {
  border-left: 2px solid var(--vn-keyword);
}

.vn-chip--button {
  border-left: 2px solid var(--vn-string);
}

.vn-gloss {
  font-family: var(--vn-font-mono);
  font-size: 0.8rem;
  line-height: 1.65;
  background: var(--vn-panel);
  border: 1px solid var(--vp-c-divider);
  border-left: 2px solid var(--vn-string);
  border-radius: 8px;
  padding: 0.75rem 1rem;
}

.vn-gloss__source {
  color: var(--vn-string);
  font-weight: 700;
  margin-bottom: 0.25rem;
}

.vn-gloss__row {
  color: var(--vn-comment);
  white-space: nowrap;
}

.vn-gloss__platform {
  font-weight: 500;
  margin-inline: 0.35em;
}

.vn-gloss__label {
  color: var(--vn-ink);
}

.vn-leaderlines {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  // Above the code panel (z-index: 1) and annotations (z-index: 1). Paths
  // are anchored at the code panel's right edge (see computeLeaderLines),
  // not at the token spans, so the connector only ever occupies the gap
  // between the panel and the annotation chips — it never draws back over
  // the code text.
  z-index: 2;

  @media (max-width: 959px) {
    display: none;
  }
}

.vn-leaderlines__path {
  fill: none;
  stroke-width: 1.25px;
  stroke-dashoffset: 0;
}

.vn-leaderlines__path--ref {
  stroke: var(--vn-keyword);
}

.vn-leaderlines__path--text {
  stroke: var(--vn-string);
}

.vn-leaderlines__path--button {
  stroke: var(--vn-string);
}

@media (prefers-reduced-motion: no-preference) {
  .vn-leaderlines__path {
    stroke-dasharray: var(--len, 0);
    stroke-dashoffset: var(--len, 0);
    transition: stroke-dashoffset 700ms ease var(--delay, 0ms);
  }

  .vn-leaderlines.is-drawn .vn-leaderlines__path {
    stroke-dashoffset: 0;
  }
}

.vn-caption-list {
  display: none;
  list-style: none;
  margin: 1.5rem 0 0;
  padding: 0;
  font-family: var(--vn-font-mono);
  font-size: 0.85rem;
  line-height: 1.6;
  color: var(--vp-c-text-mute);

  li {
    padding: 0.6rem 0;
    border-top: 1px solid var(--vp-c-divider);
  }

  li:first-child {
    border-top: none;
  }

  @media (max-width: 959px) {
    display: block;
  }
}

.vn-hero__caption {
  margin-top: 1.75rem;
  font-family: var(--vn-font-mono);
  font-weight: 500;
  font-size: 0.9rem;
  color: var(--vp-c-text-mute);
}

// ---------------------------------------------------------------------
// 2. WEDGE
// ---------------------------------------------------------------------
.vn-wedge__columns {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;

  @media (max-width: 719px) {
    grid-template-columns: 1fr;
  }
}

.vn-wedge__col {
  padding: 1.25rem;
  border: 1px solid var(--vp-c-divider);
  border-radius: 10px;
}

.vn-wedge__col--ours {
  border-left: 3px solid var(--vn-string);
}

.vn-wedge__title {
  font-family: var(--vn-font-mono);
  font-size: 1rem;
  font-weight: 700;
  margin: 0 0 0.5rem;
}

.vn-wedge__body {
  font-size: 0.95rem;
  line-height: 1.6;
  color: var(--vp-c-text-mute);
  margin: 0;
}

.vn-wedge__footer {
  font-size: 0.9rem;
  color: var(--vp-c-text-mute);
  line-height: 1.7;
}

.vn-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 0.4rem;
}

.vn-dot--green {
  background: var(--vn-string);
}

.vn-dot--amber {
  background: var(--vn-native);
}

// ---------------------------------------------------------------------
// 3. TEMPLATE (interlinear glossary)
// ---------------------------------------------------------------------
.vn-glossary {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1rem;
}

.vn-glossary__row {
  display: grid;
  grid-template-columns: 10rem minmax(0, 1fr);
  gap: 1rem;
  padding-block: 0.5rem;
  border-bottom: 1px solid var(--vp-c-divider);

  @media (max-width: 719px) {
    grid-template-columns: minmax(0, 1fr);
    gap: 0.35rem;
  }
}

.vn-glossary__source {
  font-family: var(--vn-font-mono);
  font-weight: 700;
  color: var(--vn-string);
  font-feature-settings: 'liga' 0;
}

.vn-glossary__targets {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.vn-glossary__target {
  font-family: var(--vn-font-mono);
  font-size: 0.88rem;
  color: var(--vn-comment);
  font-feature-settings: 'liga' 0;
}

.vn-glossary__platform {
  font-weight: 500;
  margin-inline: 0.4em;
}

.vn-glossary__label {
  color: var(--vn-ink);
}

.vn-glossary__note {
  font-size: 0.85rem;
  color: var(--vn-comment);
  margin-bottom: 2rem;
}

.vn-chips-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
  margin-bottom: 0.75rem;
}

.vn-chip-pill {
  font-family: var(--vn-font-mono);
  font-feature-settings: 'liga' 0;
  font-size: 0.82rem;
  background: var(--vn-panel);
  border: 1px solid var(--vp-c-divider);
  border-radius: 999px;
  padding: 0.35rem 0.85rem;
}

.vn-chips-row__caption {
  font-size: 0.85rem;
  color: var(--vp-c-text-mute);
  margin: 0 0 2rem;
}

// ---------------------------------------------------------------------
// 4. NATIVE
// ---------------------------------------------------------------------
.vn-codepanel--native {
  border-color: color-mix(in srgb, var(--vn-native) 45%, var(--vp-c-divider));
}

// Swift/Kotlin sample runs long lines — shrink the code size in this panel
// specifically so realistic native-module snippets fit without mid-token
// clipping at desktop widths.
.vn-codepanel--native .vn-code {
  font-size: 0.8rem;
}

.vn-code--plain {
  color: var(--vn-comment);
}

.vn-native__flow {
  display: grid;
  // Native (Swift) source needs more room than the short generated-TS
  // output; auto lets the arrow keep its intrinsic width.
  grid-template-columns: minmax(0, 1.7fr) auto minmax(0, 0.9fr);
  // start (not center): the Swift panel is much taller than the generated
  // panel, so centering left the short panel floating mid-height.
  align-items: start;
  gap: 1.5rem;

  // Stack the flow through the 720–899px band too — that width was too
  // narrow for the 1.7fr/0.9fr split to read cleanly side-by-side.
  @media (max-width: 899px) {
    grid-template-columns: minmax(0, 1fr);
  }
}

.vn-native__arrow {
  font-family: var(--vn-font-mono);
  font-weight: 700;
  font-size: 0.85rem;
  color: var(--vn-native);
  white-space: nowrap;
  // Nudge the arrow down out of the title-bar row so it points into the
  // Swift panel's top third instead of sitting flush with both panels' tops.
  padding-top: 2.5rem;

  @media (max-width: 899px) {
    padding-top: 0;
    text-align: center;
  }
}

.vn-native__arrow-glyph::before {
  content: '→';
}

@media (max-width: 899px) {
  // Flow stacks vertically below this breakpoint — point the connector
  // down instead of right.
  .vn-native__arrow-glyph::before {
    content: '↓';
  }
}

.vn-codepanel--generated {
  // Push the generated panel down so its own title bar lines up with the
  // Swift panel's first code line (roughly one title-bar's height), rather
  // than both panels' title bars sitting flush at the top.
  margin-top: 2.25rem;

  @media (max-width: 899px) {
    margin-top: 0;
  }
}

.vn-native__smallprint {
  margin-top: 1.5rem;
  font-size: 0.9rem;
  color: var(--vp-c-text-mute);
}

// ---------------------------------------------------------------------
// 5. CAPABILITIES
// ---------------------------------------------------------------------
.vn-token-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  font-family: var(--vn-font-mono);
  font-feature-settings: 'liga' 0;
  font-size: 0.95rem;
  line-height: 1.6;
}

.vn-token-list a {
  color: var(--vn-keyword);
  font-weight: 700;
}

// ---------------------------------------------------------------------
// 6. STATUS
// ---------------------------------------------------------------------
.vn-status__matrix {
  list-style: none;
  margin: 0 0 1.5rem;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  font-family: var(--vn-font-mono);
  font-size: 0.95rem;
}

.vn-status__note {
  font-size: 0.9rem;
  line-height: 1.7;
  color: var(--vp-c-text-mute);
  max-width: 46rem;
}

// ---------------------------------------------------------------------
// 7. QUICKSTART
// ---------------------------------------------------------------------
.vn-terminal {
  background: var(--vn-ink);
  border-radius: 10px;
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

:root[data-theme='dark'] .vn-terminal,
[data-theme='dark'] .vn-terminal {
  // Dedicated deeper surface so the terminal keeps its own identity instead
  // of matching the code panels (--vn-panel, #1d1e28) or the page bg
  // (--vn-paper, #15161d). Deliberately darker than both.
  background: #0e0f16;
  border: 1px solid var(--vp-c-divider);
}

.vn-terminal__comment {
  font-family: var(--vn-font-mono);
  font-size: 0.78rem;
  // Terminal surface is always dark (ink in light mode, panel in dark
  // mode) — use the dedicated terminal-safe token, not --vn-comment
  // (tuned for muted text on the light panel/paper surfaces instead).
  color: var(--vn-terminal-comment);
  margin: 0 0 0.35rem;
}

.vn-terminal__row {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
}

.vn-terminal__code {
  flex: 1 1 auto;
  min-width: 0;
  max-width: 100%;
  margin: 0;
  overflow-x: auto;
  font-family: var(--vn-font-mono);
  font-size: 0.88rem;
  line-height: 1.6;
  // Terminal surface is always dark — use the dedicated terminal-safe
  // green, not --vn-string (which was darkened for contrast on the light
  // panel/paper surfaces and would under-contrast here: 3.41:1 vs this
  // dark bg).
  color: var(--vn-terminal-string);
  white-space: pre;
}

.vn-copy-btn {
  flex: 0 0 auto;
  min-height: 44px;
  padding: 0.6rem 0.9rem;
  font-family: var(--vn-font-mono);
  font-size: 0.78rem;
  color: var(--vn-paper);
  background: transparent;
  border: 1px solid var(--vn-comment);
  border-radius: 6px;
  cursor: pointer;
}

.vn-copy-btn:hover {
  border-color: var(--vn-paper);
}

// The terminal surface is always dark (ink in light mode, panel in dark
// mode — see the .vn-terminal override above). --vn-paper flips to a dark
// value in dark mode, so the button text/hover-border must pin to
// --vn-ink instead there (which flips to a light value in dark mode) or
// the "Copy"/"Copied" label becomes near-invisible (~1.1:1 contrast).
:root[data-theme='dark'] .vn-copy-btn,
[data-theme='dark'] .vn-copy-btn {
  color: var(--vn-ink);
}

:root[data-theme='dark'] .vn-copy-btn:hover,
[data-theme='dark'] .vn-copy-btn:hover {
  border-color: var(--vn-ink);
}

// Commands were truncating before the distinguishing verb (e.g. "bunx
// @thelacanians/vue-native-cli d…") at the narrowest phone widths — the
// shared 34-char "bunx @thelacanians/vue-native-cli " prefix alone ate
// almost the entire code column while it sat inline next to the fixed-width
// Copy button. Shrink the type, tighten padding, AND stack the row so the
// code line gets the full terminal width instead of squeezing beside the
// button — that's what actually gets the verb (create/dev/run) on screen.
@media (max-width: 430px) {
  .vn-terminal {
    padding: 1rem;
  }

  .vn-terminal__code {
    font-size: 0.78rem;
  }

  .vn-terminal__row {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .vn-copy-btn {
    align-self: flex-end;
  }
}

.vn-quickstart__note {
  margin-top: 1.25rem;
  font-size: 0.9rem;
  color: var(--vp-c-text-mute);
}

.vn-quickstart__links {
  font-family: var(--vn-font-mono);
  font-size: 0.88rem;
}

.vn-quickstart__links a {
  color: var(--vn-keyword);
}

// ---------------------------------------------------------------------
// 8. FOOTER
// ---------------------------------------------------------------------
.vn-footer__links {
  display: flex;
  flex-wrap: wrap;
  gap: 1.5rem;
  font-family: var(--vn-font-mono);
  font-size: 0.88rem;
  margin-bottom: 1rem;
}

.vn-footer__links a {
  color: var(--vn-fn);
}

.vn-footer__links span {
  color: var(--vn-comment);
}

.vn-footer__signoff {
  font-family: var(--vn-font-mono);
  font-style: italic;
  font-size: 0.85rem;
  color: var(--vn-comment);
}

// ---------------------------------------------------------------------
// Accessibility: focus rings + minimum tap targets for interactive scope
// ---------------------------------------------------------------------
.vn-home a:focus-visible,
.vn-home button:focus-visible {
  outline: 2px solid var(--vn-keyword);
  outline-offset: 2px;
  border-radius: 4px;
}
</style>
