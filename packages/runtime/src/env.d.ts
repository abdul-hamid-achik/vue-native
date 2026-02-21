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

// process.env is used only for the __DEV__ fallback; not present in JSC
declare var process: { env: { NODE_ENV?: string } } | undefined
