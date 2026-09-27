import { computed, defineComponent, h, type PropType } from '@vue/runtime-core'
import type { StyleProp, ViewStyle } from '../types/styles'

export interface WebViewSource {
  uri?: string
  html?: string
}

/**
 * Embedded web view component backed by WKWebView.
 *
 * URI sources are validated to block dangerous schemes such as `javascript:`
 * and `data:text/html` which could lead to XSS.
 *
 * @example
 * <VWebView :source="{ uri: 'https://example.com' }" style="flex: 1" @load="onLoad" />
 */
export const VWebView = defineComponent({
  name: 'VWebView',
  props: {
    source: { type: Object as () => WebViewSource, required: true },
    style: { type: [Object, Array] as PropType<StyleProp<ViewStyle>>, default: () => ({}) },
    javaScriptEnabled: { type: Boolean, default: true },
    /**
     * Extra origins permitted to navigate this webview and to post messages into
     * the app, in addition to the origin of `source` (or the opaque origin of
     * inline `html`).
     *
     * All three native factories enforce this on every navigation, subframe and
     * `postMessage`, and refuse `file:`, `javascript:` and `data:` sources. The
     * default — only the source's own origin — is already safe, so this is an
     * escape hatch for content that legitimately moves between origins.
     */
    allowedOrigins: { type: Array as () => string[], default: () => [] },
  },
  emits: ['load', 'error', 'message'],
  setup(props, { emit }) {
    const sanitizedSource = computed((): WebViewSource => {
      const source = props.source
      if (!source?.uri) return source

      // Block dangerous URI schemes
      const lower = source.uri.toLowerCase().trim()
      if (lower.startsWith('javascript:') || lower.startsWith('data:text/html')) {
        console.warn('[VueNative] VWebView: Blocked potentially unsafe URI scheme')
        return { ...source, uri: undefined }
      }
      return source
    })

    return () =>
      h('VWebView', {
        // Native WKWebView factories begin navigation as soon as `source` is
        // applied. Keep this first so the initial navigation observes the
        // requested JavaScript policy as well as subsequent navigations.
        javaScriptEnabled: props.javaScriptEnabled,
        source: sanitizedSource.value,
        allowedOrigins: props.allowedOrigins,
        style: props.style,
        onLoad: (event: unknown) => emit('load', event),
        onError: (event: unknown) => emit('error', event),
        onMessage: (event: unknown) => emit('message', event),
      })
  },
})
