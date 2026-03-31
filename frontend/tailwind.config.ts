import type { Config } from 'tailwindcss'
import typography from '@tailwindcss/typography'

const config: Config = {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        void: '#f2e6d6',
        surface: {
          0: '#f7efe3',
          1: '#eddcc8',
          2: '#d8bea2',
          3: '#9a7859',
        },
        chrome: {
          DEFAULT: 'rgba(88, 63, 44, 0.84)',
          dock: 'rgba(106, 77, 55, 0.78)',
          overlay: 'rgba(60, 42, 28, 0.38)',
        },
        accent: {
          clay: '#8b5e3c',
          walnut: '#7a4f33',
          purple: '#6d4a37',
          amber: '#b07a47',
          green: '#7d6a42',
          red: '#8e4f3c',
        },
        text: {
          primary: '#342113',
          secondary: '#6f513b',
          muted: '#9a7a62',
          mono: '#5e3f2d',
        },
        status: {
          running: '#7a4f33',
          terminal: '#7d6a42',
          error: '#8e4f3c',
          pending: '#b08a67',
          dead: '#a06d3d',
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
  plugins: [typography],
}

export default config
