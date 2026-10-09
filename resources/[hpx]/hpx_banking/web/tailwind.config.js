/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'brand': {
          DEFAULT: '#00EAA6',
          dim: '#008f76',
          glow: 'rgba(0, 234, 166, 0.25)',
        },
        'dark': {
          DEFAULT: '#010204',
          panel: 'rgba(12, 20, 30, 0.6)',
          glass: 'rgba(16, 28, 42, 0.4)',
        }
      },
      fontFamily: {
        luxury: ['"Outfit"', 'sans-serif'],
        display: ['"Outfit"', 'sans-serif'],
        sans: ['"Inter"', 'sans-serif'],
      }
    },
  },
  plugins: [],
}
