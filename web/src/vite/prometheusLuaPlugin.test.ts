import { describe, expect, it } from "vitest"

import { luaPathToModuleName } from "./prometheusLuaPlugin"

describe("luaPathToModuleName", () => {
  it.each([
    ["src/prometheus.lua", "prometheus"],
    ["src/presets.lua", "presets"],
    ["src/prometheus/pipeline.lua", "prometheus.pipeline"],
    ["src/prometheus/cff/expressions/string.lua", "prometheus.cff.expressions.string"],
  ])("maps %s to %s", (filePath, moduleName) => {
    expect(luaPathToModuleName(filePath)).toBe(moduleName)
  })
})
