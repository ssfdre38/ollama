import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { TanStackRouterVite } from "@tanstack/router-plugin/vite";
import tailwindcss from "@tailwindcss/vite";
import tsconfigPaths from "vite-tsconfig-paths";
import postcssPresetEnv from "postcss-preset-env";
import { resolve } from "path";

export default defineConfig(() => ({
  base: "/",

  plugins: [
    TanStackRouterVite({ target: "react" }),
    react(),
    tailwindcss(),
    tsconfigPaths(),
  ],

  resolve: {
    alias: {
      "@/gotypes": resolve(__dirname, "codegen/gotypes.gen.ts"),
      "@": resolve(__dirname, "src"),
      "micromark-extension-math": "micromark-extension-llm-math",
    },
  },

  css: {
    postcss: {
      plugins: [
        postcssPresetEnv({
          stage: 2, // Reduced from stage 1 - only reasonably stable features
          browsers: ["defaults", "not IE 11"], // Modern browsers, removed Safari 14 targeting
          features: {
            "nesting-rules": true,
            "custom-properties": false, // Let TailwindCSS handle this
          },
        }),
      ],
    },
  },

  build: {
    target: "es2017",
  },

  esbuild: {
    target: "es2017",
  },
}));
