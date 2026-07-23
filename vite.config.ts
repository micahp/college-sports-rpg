import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    target: 'es2022',
    chunkSizeWarningLimit: 1500,
  },
  preview: {
    allowedHosts: ['localhost', '127.0.0.1', '.trycloudflare.com'],
  },
  test: {
    setupFiles: ['tests/setup.ts'],
  },
} as any);
