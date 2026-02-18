import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: 'class', // Enable class-based dark mode
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#6A4FB6',
          50: '#F5F3FB',
          100: '#EBE7F6',
          200: '#D7CFE8',
          300: '#C3B7DA',
          400: '#AF9FCC',
          500: '#6A4FB6',
          600: '#553F92',
          700: '#402F6E',
          800: '#2B1F49',
          900: '#161025',
        },
        highlight: {
          DEFAULT: '#FFEEC0',
          50: '#FFFDF8',
          100: '#FFF9EC',
          200: '#FFF3D6',
          300: '#FFEEC0',
          400: '#FFE9AA',
          500: '#FFE394',
          600: '#FFDE7E',
        },
        surface: '#FFFFFF',
        background: '#F8F9FA',
      },
    },
  },
  plugins: [],
}

export default config
