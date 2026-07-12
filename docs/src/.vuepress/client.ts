import { inject } from '@vercel/analytics'
import { defineClientConfig } from 'vuepress/client'
import Home from './layouts/Home.vue'

export default defineClientConfig({
  enhance() {
    if (typeof window !== 'undefined') {
      inject({ framework: 'vuepress' })
    }
  },
  layouts: { Home },
})
