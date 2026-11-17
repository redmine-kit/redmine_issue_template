// Builds src/index.ts into the plugin's module for Redmine Kit's new UI, ../assets/javascripts/kit/issue_template.js
// (redmine_kit_ui's docs/plugins-kit.md, "The module"): one ES module, Vite's library mode, with React, its JSX runtime
// and the app's components left as imports (the shell's import map gives the app's own). Not minified, without hashes,
// so that the committed file is readable, reviewable and the same on every build: `npm run build`, then commit both.
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [react()],
  publicDir: false,
  build: {
    lib: { entry: 'src/index.ts', formats: ['es'], fileName: () => 'issue_template.js' },
    outDir: '../assets/javascripts/kit',
    // the folder may hold other files (only the module is written)
    emptyOutDir: false,
    minify: false,
    sourcemap: false,
    rolldownOptions: {
      external: ['react', 'react/jsx-runtime', '@redmine-kit/ui'],
      output: {
        banner:
          "// Redmine Issue Template's module for Redmine Kit's new UI, built from frontend/src by `npm run build`\n" +
          '// (frontend/vite.config.js). Edit the source, not this file. React and @redmine-kit/ui come from the app.',
      },
    },
  },
});
