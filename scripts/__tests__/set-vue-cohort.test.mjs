import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  VAPOR_COHORT_PACKAGES,
  VUE_COHORT_PACKAGES,
} from '../check-vue-cohort.mjs'
import { alignManifest } from '../set-vue-cohort.mjs'

test('alignManifest preserves unrelated overrides across a 3.6 to 3.5 downgrade', () => {
  const manifest = {
    name: 'vue-native-monorepo',
    vueNative: {
      vueCohort: {
        active: '3.6.0-rc.1',
        next: '3.6.0-rc.2',
      },
    },
    overrides: {
      'security-workaround': '1.2.3',
      ...Object.fromEntries(
        [...VUE_COHORT_PACKAGES, ...VAPOR_COHORT_PACKAGES]
          .map(packageName => [packageName, '3.6.0-rc.1']),
      ),
    },
    dependencies: {
      '@vue/runtime-vapor': '3.6.0-rc.1',
    },
    optionalDependencies: {
      '@vue/compiler-vapor': '3.6.0-rc.1',
    },
    peerDependencies: {
      '@vue/runtime-vapor': '>=3.6.0-rc.1 <3.7.0',
    },
    resolutions: {
      '@vue/compiler-vapor': '3.6.0-rc.1',
    },
  }

  alignManifest(manifest, { isRoot: true, version: '3.5.40' })

  assert.equal(manifest.vueNative.vueCohort.active, '3.5.40')
  assert.equal(manifest.vueNative.vueCohort.next, '3.6.0-rc.2')
  assert.equal(manifest.overrides['security-workaround'], '1.2.3')
  for (const packageName of VUE_COHORT_PACKAGES) {
    assert.equal(manifest.overrides[packageName], '3.5.40')
  }
  for (const packageName of VAPOR_COHORT_PACKAGES) {
    assert.equal(packageName in manifest.overrides, false)
    assert.equal(packageName in manifest.dependencies, false)
    assert.equal(packageName in manifest.optionalDependencies, false)
    assert.equal(packageName in manifest.peerDependencies, false)
    assert.equal(packageName in manifest.resolutions, false)
  }
})
