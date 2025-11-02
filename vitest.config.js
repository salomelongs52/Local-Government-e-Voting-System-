import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    singleThread: true,
    globals: true,
    include: ["tests/**/*.test.ts"],
    typecheck: {
      checker: 'tsc',
    },
  },
});
