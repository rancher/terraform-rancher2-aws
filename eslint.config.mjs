export default [
  {
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
    },
    rules: {
      // Use core.* instead of console.* in GitHub workflow scripts
      "no-console": "error",
    },
  },
  {
    files: [".gemini/**/*.js"],
    rules: {
      // Local agent platform, orchestrator, skills, and hooks run in terminal and report via console
      "no-console": "off",
    },
  },
];
