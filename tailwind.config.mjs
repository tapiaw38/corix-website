/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}"],
  theme: {
    extend: {
      colors: {
        tn: {
          bg:       "#1a1b26",
          night:    "#16161e",
          storm:    "#24283b",
          overlay:  "#414868",
          comment:  "#565f89",
          muted:    "#737aa2",
          text:     "#a9b1d6",
          subtext:  "#9aa5ce",
          blue:     "#7aa2f7",
          cyan:     "#7dcfff",
          green:    "#9ece6a",
          yellow:   "#e0af68",
          orange:   "#ff9e64",
          red:      "#f7768e",
          magenta:  "#bb9af7",
        },
        coren: {
          accent:  "#7aa2f7",
          dim:     "#414868",
          bg:      "#1a1b26",
          surface: "#24283b",
        },
      },
      fontFamily: {
        sans: ['"JetBrains Mono"', "monospace"],
        mono: ['"JetBrains Mono"', "monospace"],
      },
      animation: {
        float: "float 6s ease-in-out infinite",
        "pulse-slow": "pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite",
      },
      keyframes: {
        float: {
          "0%, 100%": { transform: "translateY(0)" },
          "50%": { transform: "translateY(-20px)" },
        },
      },
    },
  },
  plugins: [],
};
