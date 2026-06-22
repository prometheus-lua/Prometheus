-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- namegenerators/underscores.lua
--
-- Generates names like ___ ______ ______ 
-- generates insanely long variable names with longer scripts


local util = require("prometheus.util");
local chararray = util.chararray;

local Underscores = {
	"_",
	"__"
};

local function generateName(id, scope)
	while id > 0 do
		local d = id % #Underscores
		id = (id - d) / #Underscores
		name = name..Underscores[d+1]
	end
	return name
end

local function prepare(ast)
	util.shuffle(Underscores);
end

return {
	generateName = generateName, 
	prepare = prepare
};