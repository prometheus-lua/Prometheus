local t = {}

t.Hello = "World"
t["World"] = "Hello"
t["Test Thing"] = "B"
print(t.World)
print(debug.info(function() end, "l"))