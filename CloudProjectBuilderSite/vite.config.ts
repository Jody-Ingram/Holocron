import { defineConfig } from "vite";
import vinext from "vinext";

export default defineConfig({
  server: {
    host: "0.0.0.0",
    allowedHosts: ["terminal.local"],
  },
  plugins: [vinext()],
});
