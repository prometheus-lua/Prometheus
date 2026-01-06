--============================================================
-- Repeat–Until Semantics Test Suite
-- Target: Vmify
-- Author: Zaenalos
-- Purpose: Validate correct scope, control flow, and condition
--============================================================

local TEST_ID = 0

local function test(name, fn)
  TEST_ID = TEST_ID + 1
  local ok, err = pcall(fn)
  if not ok then
    error(string.format(
      "[FAIL] #%d %s\n  → %s",
      TEST_ID, name, err
    ), 2)
  end
  print(string.format("[PASS] #%d %s", TEST_ID, name))
end

--============================================================
-- Test 1: Basic repeat-until with local in condition scope
--============================================================
test("Basic local visibility in until condition", function()
  local count = 0
  repeat
    local x = count
    count = count + 1
  until x == 5

  assert(count == 6, "count should be 6")
end)

--============================================================
-- Test 2: Locals do not leak outside repeat scope
--============================================================
test("Repeat locals do not escape scope", function()
  repeat
    local hidden = 123
  until true

  assert(_G.hidden == nil, "local leaked into global scope")
end)

--============================================================
-- Test 3: Immediate exit still executes body once
--============================================================
test("Immediate termination executes once", function()
  local iters = 0
  repeat
    iters = iters + 1
  until true

  assert(iters == 1, "repeat body must run exactly once")
end)

--============================================================
-- Test 4: Multiple locals and arithmetic correctness
--============================================================
test("Multiple locals and arithmetic", function()
  local i = 0
  local c
  repeat
    local a = i
    local b = a * 2
    c = a + b
    i = i + 1
  until c >= 15

  assert(i == 6, "i should be 6 when c reaches 15")
end)

--============================================================
-- Test 5: Nested repeat-until with independent scopes
--============================================================
test("Nested repeat loops", function()
  local outer = 0
  local total_inner = 0

  repeat
    local inner = 0
    repeat
      total_inner = total_inner + 1
      inner = inner + 1
    until inner == 3
    outer = outer + 1
  until outer == 3

  assert(outer == 3, "outer loop count mismatch")
  assert(total_inner == 9, "inner loop count mismatch")
end)

--============================================================
-- Test 6: Function call inside until condition
--============================================================
test("Function call in until condition", function()
  local function check(x)
    return x >= 3
  end

  local k = 0
  local current
  repeat
    current = k
    k = k + 1
  until check(current)

  assert(k == 4, "termination point incorrect")
end)

--============================================================
-- Test 7: Upvalue capture inside repeat
--============================================================
test("Upvalue capture from repeat body", function()
  local f
  repeat
    local x = 42
    f = function()
      return x
    end
  until true

  assert(f() == 42, "upvalue incorrectly captured")
end)

--============================================================
-- Test 8: Side effects inside until condition (corrected)
--============================================================
test("Side effects in until condition", function()
  local log = {}
  local i = 0

  repeat
    i = i + 1
  until (function()
    log[#log + 1] = i   -- explicit side effect
    return i >= 3
  end)()

  assert(#log == 3, "side effects count mismatch")
  assert(log[3] == 3, "final side effect value incorrect")
end)

--============================================================
-- Test 9: Break skips until condition
--============================================================
test("Break bypasses until evaluation", function()
  local evaluated = false

  repeat
    break
  until (function()
    evaluated = true
    return true
  end)()

  assert(evaluated == false, "`until` condition evaluated after break")
end)

--============================================================
-- Test 10: Slot reuse and shadowing correctness
--============================================================
test("Local shadowing and slot reuse", function()
  local sum = 0
  local i = 0

  repeat
    local v = i
    sum = sum + v
    do
      local v = v * 2
      sum = sum + v
    end
    i = i + 1
  until i == 3

  assert(sum == (0+0) + (1+2) + (2+4), "slot corruption detected")
end)

--============================================================
-- Test 11: Table mutation inside repeat
--============================================================
test("Table writes inside repeat", function()
  local t = {}
  local i = 1

  repeat
    t[i] = i * i
    i = i + 1
  until i > 5

  assert(#t == 5, "table size incorrect")
  assert(t[5] == 25, "table content incorrect")
end)

--============================================================
-- Test 12: Deterministic non-linear termination
--============================================================
test("Non-linear termination logic", function()
  local x = 1
  repeat
    x = (x * 3 + 1) % 17
  until x == 0

  assert(x == 0, "non-linear termination failed")
end)

--============================================================
print("\nAll repeat-until tests passed successfully.")
