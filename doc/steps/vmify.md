---
description: >-
  This Step will Compile your script into a fully-coustom (not a half coustom
  like other lua obfuscators) Bytecode Format and emit a vm for executing it.
---

# Vmify

### Settings

None

### Example

{% code title="in.lua" %}
```lua
print("Hello, World!")
```
{% endcode %}

{% code title="out.lua" %}
```lua
-- No Settings
local K, B, w, Z, s, M, G, V, u, p, f, P, J, c, W, g, j, X, T, o, r, i, q, L, I, D, R, F, y, Y
u = function(K, B, ...)
    local Z = {...}
    local s = 0
    local M = 1
    for B = 0, B - 1, 1 do
        s = s + J(w[K + B], Z and Z[B + 1] or 0) * M
        M = M * 256
    end
    return s
end
T = string["find"]
P = bit32 and bit32["bxor"]
F = function(B)
    local w = {}
    B =
        r(
        r(
            B,
            ".",
            function(K)
                if K == "=" then
                    return ""
                end
                local B, w = "", T(g, K) - 1
                for K = 6, 1, -1 do
                    B = B .. (w % 2 ^ K - w % 2 ^ (K - 1) > 0 and "1" or "0")
                end
                return B
            end
        ),
        "%d%d%d?%d?%d?%d?%d?%d?",
        function(B)
            if #B ~= 8 then
                return ""
            end
            local w = 0
            for K = 1, 8, 1 do
                w = w + (M(B, K, K) == "1" and 2 ^ (8 - K) or 0)
            end
            return K(w)
        end
    )
    for K = 1, #B, 1 do
        w[K] = y(B, K)
    end
    return w
end
M = string["sub"]
Z = function()
    J = P or X
    w = F(w)
    i()
    return (Y(I[1], D()))()
end
r = string["gsub"]
s = table and table["unpack"] or unpack
c = 4
G = math["floor"]
y = string["byte"]
Y = function(K, B, w)
    return function(...)
        return s(f(K, {...}, B, w))
    end
end
f = function(Z, M, G, p)
    local f = {[0] = p}
    local P = {}
    local g = 0
    local j, X, T, r, i, q
    X = c + (Z - 1) * 4
    j = J(w[X], 4)
    while true do
        T = true
        while j == 204 do
            if g > 0 then
                r = P[g]
            else
                r = nil
            end
            P = P[0]
            g = P["l"] + 1
            P[g] = r
            Z = Z + 1
            X = c + (Z - 1) * 4
            j = J(w[X], 4)
            T = false
        end
        while j == 220 do
            P[g] = G[P[g]]
            Z = Z + 1
            X = c + (Z - 1) * 4
            j = J(w[X], 4)
            T = false
        end
        while j == 12 do
            P = {[0] = P[0]}
            g = 0
            Z = Z + 1
            X = c + (Z - 1) * 4
            j = J(w[X], 4)
            T = false
        end
        while j == 82 do
            g = g - 1
            P[g], P[g + 1] = {P[g](s(P[g + 1]))}, nil
            Z = Z + 1
            X = c + (Z - 1) * 4
            j = J(w[X], 4)
            T = false
        end
        while j == 5 do
            r = {}
            for K, B in ipairs(P) do
                r[K] = B
            end
            g = 1
            P = {[0] = P[0], [1] = r}
            Z = Z + 1
            X = c + (Z - 1) * 4
            j = J(w[X], 4)
            T = false
        end
        while j == 114 do
            return {}
        end
        while j == 105 do
            q = u(X + 1, 3, 102, 103, 175)
            g = g + 1
            P[g] = V[q]
            if not P[g] then
                r = B[q] + o
                i = w[r]
                if i == 153 then
                    i = u(r + 1, 4)
                    P[g] = ""
                    for B = 1, i, 1 do
                        P[g] = P[g] .. K(w[r + (B + 4)])
                    end
                elseif i == 22 then
                    P[g] = W(r + 1)
                elseif i == 82 then
                    P[g] = u(r + 1, 4)
                elseif i == 125 then
                    P[g] = -u(r + 1, 4)
                end
                V[q] = P[g]
            end
            Z = Z + 1
            X = c + (Z - 1) * 4
            j = J(w[X], 4)
            T = false
        end
        while j == 122 do
            P["l"] = g
            g = 0
            P = {[0] = P}
            Z = Z + 1
            X = c + (Z - 1) * 4
            j = J(w[X], 4)
            T = false
        end
        if T then
            Z = Z + 1
            X = c + (Z - 1) * 4
            j = J(w[X], 4)
        end
    end
end
X = function(K, B, w, ...)
    local Z = 0
    for w = 0, 31, 1 do
        local s = K / 2 + B / 2
        if s ~= G(s) then
            Z = Z + 2 ^ w
        end
        K = G(K / 2)
        B = G(B / 2)
    end
    if w then
        return X(Z, w, ...)
    end
    return Z
end
K = string["char"]
p = table["remove"]
i = function()
    R = u(1, 3)
    I = {}
    for K = 0, R - 1, 1 do
        I[K + 1] = u(c + K * 3, 3)
    end
    c = c + R * 3
    q = u(c, 3)
    for K = 0, q - 1, 1 do
        B[K + 1] = u(c + (3 + K * 4), 4)
    end
    c = c + (q * 4 + 6)
    L = u(c - 3, 3)
    o = c + L * 4
end
B = {}
I = {}
W = function(K)
    local B = {}
    for Z = 0, 7, 1 do
        B[Z + 1] = w[K + Z]
    end
    local Z = 1
    local s = B[2] % 16
    for K = 3, 8, 1 do
        s = s * 256 + B[K]
    end
    if B[1] > 127 then
        Z = -1
    end
    local M = B[1] % 128 * 16 + G(B[2] / 16)
    if M == 0 then
        return 0
    end
    s = (j(s, -52) + 1) * Z
    return j(s, M - 1023)
end
g = 'UnE,Sux\tVWQ"!T5h\b:jR\nq\v2oMOHcpvCD\'XL4d6JgYmbI1etZw3Pf9ak/K8;B\ays'
D = getfenv
w =
    'U\bUUU\bUUUDUUUUUUUUgUUUUQUUnUn\'\'jH\vpJb\a\'\tRf\'yKsH3H\v:JbZ\t1K\'"V\bQmQq\'EOVDXc2ypa"J\vw6\b\nUUUnZc6depW4TUUUUjxqIHxBIVuptc6w4V\b=='
j = math["ldexp"]
V = {}
return Z()

```
{% endcode %}
