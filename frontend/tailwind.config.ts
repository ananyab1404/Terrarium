import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        void: '#03050a',
        surface: {
          0: '#0a0e16',
          1: '#0f1420',
          2: '#151b28',
          3: '#1c2436',
        },
        chrome: {
          DEFAULT: 'rgba(15, 20, 32, 0.82)',
          dock: 'rgba(10, 14, 22, 0.75)',
          overlay: 'rgba(3, 5, 10, 0.45)',
        },
        accent: {
          blue: '#4d9fff',
          cyan: '#00d4e0',
          purple: '#8b5cf6',
          amber: '#f59e0b',
          green: '#22c55e',
          red: '#ef4444',
        },
        text: {
          primary: '#e2e8f0',
          secondary: '#94a3b8',
          muted: '#475569',
          mono: '#7dd3fc',
        },
        status: {
          running: '#00d4e0',
          terminal: '#22c55e',
          error: '#ef4444',
          pending: '#94a3b8',
          dead: '#f59e0b',
        },
      },
      fontFamily: {
        display: ['"Exo 2"', 'sans-serif'],
        body: ['"IBM Plex Sans"', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'monospace'],
      },
      boxShadow: {
        glass: '0 18px 35px rgba(0, 0, 0, 0.35)',
      },
    },
  },
  plugins: [require('@tailwindcss/typography')],
}

export default config
