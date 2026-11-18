// Builds src/index.ts into the plugin's module, ../assets/javascripts/kit/issue_template.js (redmine_kit_ui's docs/plugins-kit.md,
// "The module"), with @redmine-kit/plugin's preset: one ES module, Vite's library mode, with React, its JSX runtime and
// the app's packages (@redmine-kit/ui, @redmine-kit/plugin) left as imports (the shell's import map gives the app's own).
// Not minified, without hashes, so that the committed file is readable, reviewable and the same on every build:
// `npm run build`, then commit both.
import react from '@vitejs/plugin-react';
import { defineKitModule } from '@redmine-kit/plugin/vite';

export default defineKitModule({ name: 'issue_template', title: "Redmine Kit Issue Template", plugins: [react()] });
