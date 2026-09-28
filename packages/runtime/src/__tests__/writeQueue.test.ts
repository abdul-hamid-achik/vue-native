/**
 * writeQueue serializes storage writes per key. It had no test coverage at
 * all, and a regression here interleaves writes to the same key — which for
 * useSecureStorage/useAsyncStorage means a stale token or value can win the
 * race. The protected-variant keys (`protected:<key>`) share this queue, so
 * the ordering guarantee covers biometry-gated writes too.
 */
import { describe, expect, it } from 'vitest'
import { createWriteQueue } from '../composables/writeQueue'

/** A promise plus the handles to settle it from the test. */
function deferred() {
  let resolve!: () => void
  let reject!: (error: unknown) => void
  const promise = new Promise<void>((res, rej) => {
    resolve = res
    reject = rej
  })
  return { promise, resolve, reject }
}

const tick = () => new Promise(resolve => setTimeout(resolve, 0))

describe('createWriteQueue', () => {
  it('serializes writes to the same key in submission order', async () => {
    const queue = createWriteQueue()
    const order: string[] = []

    const slow = deferred()
    const first = queue('token', async () => {
      await slow.promise
      order.push('first')
    })
    const second = queue('token', async () => {
      order.push('second')
    })

    // The second write must not start while the first is still in flight,
    // even though the first is the slower one.
    await tick()
    await tick()
    expect(order).toEqual([])

    slow.resolve()
    await Promise.all([first, second])
    expect(order).toEqual(['first', 'second'])
  })

  it('does not serialize writes to different keys', async () => {
    const queue = createWriteQueue()
    const order: string[] = []

    const slow = deferred()
    const first = queue('a', async () => {
      await slow.promise
      order.push('a')
    })
    const second = queue('b', async () => {
      order.push('b')
    })

    await tick()
    // Different keys run concurrently, so b finishes while a is still waiting.
    expect(order).toEqual(['b'])

    slow.resolve()
    await Promise.all([first, second])
    expect(order).toEqual(['b', 'a'])
  })

  it('keeps the chain alive after a rejected write', async () => {
    const queue = createWriteQueue()
    const order: string[] = []

    const failing = queue('token', async () => {
      order.push('failing')
      throw new Error('keychain unavailable')
    })
    const next = queue('token', async () => {
      order.push('next')
    })

    await expect(failing).rejects.toThrow('keychain unavailable')
    await next
    // The rejection must not poison the queue for the key.
    expect(order).toEqual(['failing', 'next'])
  })

  it('does not hold a finished key back from a later write', async () => {
    const queue = createWriteQueue()
    await queue('token', async () => {})

    // If the completed chain were still registered, this write would be
    // queued behind an already-settled promise; either way it must complete.
    let ran = false
    await queue('token', async () => {
      ran = true
    })
    expect(ran).toBe(true)
  })

  it('keeps queues per backend independent for identical keys', async () => {
    const secure = createWriteQueue()
    const plain = createWriteQueue()
    const order: string[] = []

    const slow = deferred()
    const first = secure('token', async () => {
      await slow.promise
      order.push('secure')
    })
    const second = plain('token', async () => {
      order.push('plain')
    })

    await tick()
    expect(order).toEqual(['plain'])

    slow.resolve()
    await Promise.all([first, second])
    expect(order).toEqual(['plain', 'secure'])
  })
})
