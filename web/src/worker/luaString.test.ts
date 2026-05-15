import { describe, expect, it } from "vitest"

import { toLuaLongString } from "./luaString"

describe("toLuaLongString", () => {
  it("chooses a delimiter that does not collide with the string body", () => {
    expect(toLuaLongString("a ]] b")).toBe("[=[a ]] b]=]")
  })
})
