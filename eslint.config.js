import tseslint from 'typescript-eslint'

export default tseslint.config(
  {
    ignores: ['**/dist/**', '**/node_modules/**', 'native/**'],
  },
  ...tseslint.configs.recommended,
  {
    rules: {
      // Enforce no `any` in new code — existing `any` can be migrated gradually
      '@typescript-eslint/no-explicit-any': 'warn',
      // Allow unused vars prefixed with _
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
      // Require explicit return types on exported functions
      '@typescript-eslint/explicit-module-boundary-types': 'off',
      // Allow non-null assertions in this codebase (bridge guarantees)
      '@typescript-eslint/no-non-null-assertion': 'off',
    },
  },
)
