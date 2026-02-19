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
          DEFAULT: '#4F46E5',
          50: '#EEF2FF',
          100: '#E0E7FF',
          200: '#C7D2FE',
          300: '#A5B4FC',
          400: '#818CF8',
          500: '#6366F1',
          600: '#4F46E5',
          700: '#4338CA',
          800: '#3730A3',
          900: '#312E81',
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
