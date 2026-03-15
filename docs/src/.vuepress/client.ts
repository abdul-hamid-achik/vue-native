import { inject } from '@vercel/analytics'
import { defineClientConfig } from 'vuepress/client'

export default defineClientConfig({
  enhance() {
    if (typeof window !== 'undefined') {
      inject({ framework: 'vuepress' })
    }
  },
})
