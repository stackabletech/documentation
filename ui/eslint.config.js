import js from '@eslint/js';
import globals from 'globals';

export default [
  js.configs.recommended,
  {
    ignores: ['build/**', 'node_modules/**']
  },
  {
    files: ['src/js/**/*.js', 'src/helpers/*.js'],
    ignores: ['src/js/vendor/*.bundle.js', 'src/js/vendor/*.module.js'],
    languageOptions: {
      sourceType: 'commonjs',
      globals: { ...globals.browser, ...globals.commonjs }
    }
  },
  {
    files: ['src/js/vendor/*.bundle.js', 'src/js/vendor/*.module.js'],
    languageOptions: {
      sourceType: 'module',
      globals: globals.browser
    }
  },
  {
    files: ['build.mjs', 'vite.config.js'],
    languageOptions: {
      globals: globals.node
    }
  }
];
