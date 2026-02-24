import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { ViewStyle } from '../types/styles'

export interface WebViewSource {
  uri?: string
  html?: string
}

/**
 * Embedded web view component backed by WKWebView.
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
    return () =>
      h('VWebView', {
        source: props.source,
        style: props.style,
        javaScriptEnabled: props.javaScriptEnabled,
        onLoad: (e: any) => emit('load', e),
        onError: (e: any) => emit('error', e),
        onMessage: (e: any) => emit('message', e),
      })
  },
})
