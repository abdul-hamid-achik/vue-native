/**
 * Golden app-shell fixture.
 *
 * This is not a Vue IIFE. It speaks the native bridge protocol directly so
 * host boot tests stay deterministic and do not depend on the bundled runtime.
 * Stable accessibility ids:
 *   app-shell-root   — the setRootView container
 *   app-shell-label  — the VText child, text "app-shell-ok"
 */
(function () {
  if (typeof __VN_flushOperations !== 'function') {
    throw new Error('app-shell fixture: __VN_flushOperations is not registered')
  }

  __VN_flushOperations(JSON.stringify([
    { op: 'create', args: [1, 'VView'] },
    { op: 'updateStyle', args: [1, { flex: 1, backgroundColor: '#102030' }] },
    { op: 'updateProp', args: [1, 'accessibilityLabel', 'app-shell-root'] },
    { op: 'create', args: [2, 'VText'] },
    { op: 'setElementText', args: [2, 'app-shell-ok'] },
    { op: 'updateProp', args: [2, 'accessibilityLabel', 'app-shell-label'] },
    { op: 'appendChild', args: [1, 2] },
    { op: 'setRootView', args: [1] },
  ]))
})()
