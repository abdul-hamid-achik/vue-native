import tseslint from 'typescript-eslint'
import pluginVue from 'eslint-plugin-vue'
import vueParser from 'vue-eslint-parser'
import stylistic from '@stylistic/eslint-plugin'
import globals from 'globals'

export default tseslint.config(
  // Global ignores
  {
    ignores: [
      '**/dist/',
      '**/node_modules/',
      '.turbo/',
      'native/',
      'docs/',
      '**/*.d.ts',
      '**/DerivedData/',
      '.build/',
      '**/*.json',
    ],
  },

  // Base TS config (non-type-checked for speed)
  ...tseslint.configs.recommended,

  // Stylistic formatting rules (replaces Prettier)
  stylistic.configs.customize({
    indent: 2,
    quotes: 'single',
    semi: false,
    commaDangle: 'always-multiline',
    braceStyle: '1tbs',
  }),

  // Main TS/JS rules
  {
    files: ['**/*.{ts,js,mjs}'],
    rules: {
      '@typescript-eslint/consistent-type-imports': ['error', {
        prefer: 'type-imports',
        fixStyle: 'inline-type-imports',
      }],
      '@typescript-eslint/no-explicit-any': 'warn',
      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
      }],
      '@typescript-eslint/no-empty-object-type': 'off',
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
  },

  // Vue files in examples/
  ...pluginVue.configs['flat/recommended'].map(config => ({
    ...config,
    files: ['examples/**/*.vue'],
  })),
  {
    files: ['examples/**/*.vue'],
    languageOptions: {
      parser: vueParser,
      parserOptions: {
        parser: tseslint.parser,
        sourceType: 'module',
      },
    },
    rules: {
      'vue/multi-word-component-names': 'off',
      'vue/no-v-html': 'off',
      'vue/max-attributes-per-line': 'off',
      'vue/singleline-html-element-content-newline': 'off',
      'vue/html-self-closing': ['error', {
        html: { void: 'always', normal: 'always', component: 'always' },
      }],
      '@typescript-eslint/consistent-type-imports': ['error', {
        prefer: 'type-imports',
        fixStyle: 'inline-type-imports',
      }],
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unused-vars': ['error', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
      }],
      'no-console': 'off',
    },
  },

  // Relaxed rules for examples/ and tests
  {
    files: ['examples/**/*.{ts,js}', '**/*.test.ts', '**/*.spec.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off',
      'no-console': 'off',
    },
  },

  // Config files (CJS/ESM scripts at root)
  {
    files: ['*.config.{js,ts,mjs}'],
    rules: {
      '@typescript-eslint/no-require-imports': 'off',
    },
  },

  // Node globals for CLI and build tools
  {
    files: ['packages/cli/**/*.ts', 'packages/vite-plugin/**/*.ts'],
    languageOptions: {
      globals: globals.node,
    },
  },

  // CLI legitimately needs console.log for user-facing output
  {
    files: ['packages/cli/**/*.ts'],
    rules: {
      'no-console': 'off',
    },
  },
)
