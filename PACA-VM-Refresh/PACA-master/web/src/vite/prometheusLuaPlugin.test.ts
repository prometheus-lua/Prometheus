import { describe, expect, it } from "vitest"

import { luaPathToModuleName } from "./prometheusLuaPlugin"

describe("luaPathToModuleName", () => {
  it.each([
    ["src/prometheus.lua", "prometheus"],
    ["src/presets.lua", "presets"],
    ["src/prometheus/pipeline.lua", "prometheus.pipeline"],
    ["src/prometheus/compiler/expressions/string.lua", "prometheus.compiler.expressions.string"],
  ])("maps %s to %s", (filePath, moduleName) => {
    expect(luaPathToModuleName(filePath)).toBe(moduleName)
  })
})
