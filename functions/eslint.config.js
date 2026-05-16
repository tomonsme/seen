"use strict";

module.exports = [
  {
    ignores: ["node_modules/**"],
  },
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: "commonjs",
      globals: {
        console: "readonly",
        exports: "writable",
        module: "readonly",
        process: "readonly",
        require: "readonly",
      },
    },
    rules: {
      "comma-dangle": ["error", "always-multiline"],
      "eol-last": ["error", "always"],
      "indent": ["error", 2],
      "max-len": ["error", {"code": 100, "ignoreStrings": true}],
      "no-unused-vars": ["error", {"argsIgnorePattern": "^_"}],
      "quotes": ["error", "double"],
      "semi": ["error", "always"],
    },
  },
];
