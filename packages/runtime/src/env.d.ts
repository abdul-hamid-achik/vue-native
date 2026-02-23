/**
 * Type declarations for the JavaScriptCore environment.
 * These globals are polyfilled by JSPolyfills.swift on the native side,
 * or exist natively in JSC (like Promise, JSON, etc.).
 */

// queueMicrotask is available in ES2021+ and polyfilled via Promise.resolve().then() in JSC
declare function queueMicrotask(callback: VoidFunction): void

// Console is polyfilled by JSPolyfills.swift
declare interface Console {
  log(...data: any[]): void
  warn(...data: any[]): void
  error(...data: any[]): void
  debug(...data: any[]): void
  info(...data: any[]): void
}
declare var console: Console

// Timer functions polyfilled by JSPolyfills.swift / JSPolyfills.kt
declare function setTimeout(cb: (...args: any[]) => void, ms?: number): number
declare function clearTimeout(id: number | undefined): void
declare function setInterval(cb: (...args: any[]) => void, ms?: number): number
declare function clearInterval(id: number | undefined): void
declare function requestAnimationFrame(cb: (ts: number) => void): number
declare function cancelAnimationFrame(id: number): void

// __DEV__ is a compile-time constant replaced by the Vite plugin
declare const __DEV__: boolean

// process.env is used only for the __DEV__ fallback; not present in JSC
declare var process: { env: { NODE_ENV?: string } } | undefined
