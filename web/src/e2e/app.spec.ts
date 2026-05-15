import { expect, test } from "@playwright/test"

test("loads under the GitHub Pages base and obfuscates input", async ({ page }) => {
  await page.goto("/")
  await expect(page.getByRole("heading", { name: "Prometheus Playground" })).toBeVisible()

  const input = page.getByLabel("Lua input").locator(".cm-content")
  await input.click()
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A")
  await page.keyboard.type('print("Hello from Playwright")')

  await page.getByRole("button", { name: "Obfuscate" }).click()
  await expect(page.getByText("Obfuscation complete")).toBeVisible({ timeout: 30000 })
  await expect(page.getByLabel("Obfuscated output")).toContainText("print")

  await page.getByRole("button", { name: "Copy output" }).click()
  const downloadPromise = page.waitForEvent("download")
  await page.getByRole("button", { name: "Download output" }).click()
  const download = await downloadPromise
  expect(download.suggestedFilename()).toBe("prometheus.obfuscated.lua")
})

test("runs input script and shows logs", async ({ page }) => {
  await page.goto("/")
  await expect(page.getByRole("heading", { name: "Prometheus Playground" })).toBeVisible()

  const input = page.getByLabel("Lua input").locator(".cm-content")
  await input.click()
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A")
  await page.keyboard.type('print("Run works")')

  await page.getByLabel("Lua input").getByRole("button", { name: "Run" }).click()
  await expect(page.getByText("Script execution complete")).toBeVisible({ timeout: 30000 })
  await expect(page.getByText("Run works")).toBeVisible()
})

test("share link roundtrip keeps the same obfuscated output", async ({ browser, page, context }) => {
  await context.grantPermissions(["clipboard-read", "clipboard-write"])
  await page.goto("/")
  await expect(page.getByRole("heading", { name: "Prometheus Playground" })).toBeVisible()

  const input = page.getByLabel("Lua input").locator(".cm-content")
  await input.click()
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A")
  await page.keyboard.type('local value = 7\nprint(value * 6)')

  await page.getByRole("button", { name: "Obfuscate" }).click()
  await expect(page.getByText("Obfuscation complete")).toBeVisible({ timeout: 30000 })

  const outputEditor = page.getByLabel("Obfuscated output").locator(".cm-content")
  const originalOutput = await outputEditor.innerText()
  expect(originalOutput.trim().length).toBeGreaterThan(0)

  await page.getByRole("button", { name: "Share link" }).click()
  await expect(page.getByText("Share link copied")).toBeVisible()
  const sharedUrl = await page.evaluate(() => navigator.clipboard.readText())
  expect(sharedUrl).toContain("share=")

  const sharedPage = await browser.newPage()
  await sharedPage.goto(sharedUrl)
  await expect(sharedPage.getByText("Shared link loaded")).toBeVisible({ timeout: 30000 })
  const sharedOutput = await sharedPage.getByLabel("Obfuscated output").locator(".cm-content").innerText()
  expect(sharedOutput).toBe(originalOutput)
})

test("share link can be created after obfuscation fails", async ({ browser, page, context }) => {
  await context.grantPermissions(["clipboard-read", "clipboard-write"])
  await page.goto("/")
  await expect(page.getByRole("heading", { name: "Prometheus Playground" })).toBeVisible()

  const input = page.getByLabel("Lua input").locator(".cm-content")
  await input.click()
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A")
  await page.keyboard.type("local =")

  await page.getByRole("button", { name: "Obfuscate" }).click()
  await expect(page.getByText("Obfuscation failed")).toBeVisible({ timeout: 30000 })

  await page.getByRole("button", { name: "Share link" }).click()
  await expect(page.getByText("Share link copied")).toBeVisible()
  const sharedUrl = await page.evaluate(() => navigator.clipboard.readText())
  expect(sharedUrl).toContain("share=")

  const sharedPage = await browser.newPage()
  await sharedPage.goto(sharedUrl)
  await expect(sharedPage.getByText("Obfuscation failed")).toBeVisible({ timeout: 30000 })
  await expect(sharedPage.getByLabel("Lua input")).toContainText("local =")
})
