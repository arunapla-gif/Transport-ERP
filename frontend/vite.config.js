import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    tailwindcss(),
    react()
  ],
  build: {
    rollupOptions: {
      input: {
        main: 'index.html',
        scanner: 'scanner.html'
      }
    }
  },
  server: {
    proxy: {
      '/socket.io': {
        target: 'http://localhost:5005',
        ws: true
      }
    }
  }
})
