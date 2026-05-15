import { defineConfig, devices } from "@playwright/test"

export default defineConfig({
  testDir: "./src/e2e",
  webServer: {
    command: "pnpm --filter web preview --host 127.0.0.1 --port 4173",
    url: "http://127.0.0.1:4173/Prometheus/",
    reuseExistingServer: !process.env.CI,
  },
  use: {
    baseURL: "http://127.0.0.1:4173/Prometheus/",
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
})
