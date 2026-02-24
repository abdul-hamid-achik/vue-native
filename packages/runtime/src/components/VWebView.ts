import { computed, defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

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
    style: { type: Object as PropType<ViewStyle>, default: () => ({}) },
    javaScriptEnabled: { type: Boolean, default: true },
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
        source: sanitizedSource.value,
        style: props.style,
        javaScriptEnabled: props.javaScriptEnabled,
        onLoad: (e: any) => emit('load', e),
        onError: (e: any) => emit('error', e),
        onMessage: (e: any) => emit('message', e),
      })
  },
})
