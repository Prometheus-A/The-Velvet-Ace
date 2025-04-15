/** @type {import('tailwindcss').Config} */
export default {
    content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
    theme: {
      extend: {
        fontFamily: {
            inter: ['Inter', 'sans-serif'],
            orbitron: ['Orbitron', 'sans-serif'],
        },
      },
    },
    plugins: [],
  }