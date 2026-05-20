import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        ink: "#162033",
        muted: "#65748a",
        line: "#dde5ef",
        brand: "#e8720c",
        brandDark: "#b95406",
        good: "#15945b",
        warn: "#b7791f",
        bad: "#c2413a"
      },
      boxShadow: {
        panel: "0 16px 48px rgba(22, 32, 51, 0.08)"
      }
    }
  },
  plugins: []
};

export default config;
