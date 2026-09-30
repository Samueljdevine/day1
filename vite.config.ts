import { defineConfig } from 'vitest/config';
import { VitePWA } from 'vite-plugin-pwa';

// Where the app is served from. '/' locally; the GitHub Pages workflow sets
// BASE_PATH=/day1/ because project sites live under a subpath.
declare const process: { env: Record<string, string | undefined> };
const base = process.env.BASE_PATH ?? '/';

export default defineConfig({
  base,
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icon.svg', 'apple-touch-icon.png'],
      manifest: {
        name: 'Day 1',
        short_name: 'Day 1',
        description: 'Which block of the routine is on right now, how long is left, and what comes next.',
        start_url: base,
        scope: base,
        display: 'standalone',
        orientation: 'portrait',
        theme_color: '#0f1115',
        background_color: '#0f1115',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: 'icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,png,svg,ico,webmanifest}'],
        navigateFallback: `${base}index.html`,
        cleanupOutdatedCaches: true,
      },
    }),
  ],
  build: {
    target: 'es2020',
  },
  test: {
    environment: 'node',
    include: ['test/**/*.test.ts'],
  },
});
