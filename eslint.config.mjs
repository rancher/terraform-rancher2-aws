import js from '@eslint/js';

export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        process: 'readonly',
        console: 'readonly',
        setTimeout: 'readonly',
        global: 'readonly',
        setInterval: 'readonly',
        clearInterval: 'readonly',
        clearTimeout: 'readonly',
      },
    },
    rules: {
      'no-empty': ['error', { allowEmptyCatch: false }],
      'no-unused-vars': 'error',
      eqeqeq: 'error',
      curly: 'error',
      'no-var': 'error',
      'prefer-const': 'error',
      'no-shadow': 'error',
      'no-undef': 'error',
      'no-const-assign': 'error',
      'no-dupe-keys': 'error',
      'no-unreachable': 'error',
      'no-duplicate-imports': 'error',
    },
  },
  // Strict rules for GHA execution scripts (excluding local scripts/tests)
  {
    files: ['.github/workflows/scripts/**/*.js'],
    rules: {
      'require-await': 'error',
      'no-restricted-syntax': [
        'error',
        {
          selector: 'CallExpression[callee.object.name="console"][callee.property.name="log"]',
          message:
            'Please use GHA UI-Native logging or structured JSON outputs instead of standard console.log inside workflow runners.',
        },
      ],
    },
  },
  // Non-restricted rules for local utility, hooks, and test files
  {
    files: ['.gemini/hooks/**/*.js', '.gemini/skills/**/*.js', 'agent-scripts/**/*.js', 'test/**/*.js', '**/*.test.js'],
    rules: {
      'require-await': 'off',
      'no-empty': ['error', { allowEmptyCatch: false }],
    },
  },
];
