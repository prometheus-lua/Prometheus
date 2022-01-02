---
description: This Step wraps all locals into Proxy Objects
---

# ProxifyLocals

### Settings

None

### Example

{% code title="in.lua" %}
```lua
local x = "Hello, World!"
print(x)
```
{% endcode %}

{% code title="out.lua" %}
```lua
-- No Settings
local n = setmetatable
local D =
    n(
    {Wz = function()
        end},
    {__div = function(R, n)
            R.Wz = n
        end, __concat = function(R, n)
            return R.Wz
        end}
)
local R =
    n(
    {Js = "Hello, World!"},
    {__add = function(R, n)
            R.Js = n
        end, __index = function(R, n)
            return rawget(R, "Js")
        end}
)
print(R.Muirgen)
```
{% endcode %}
