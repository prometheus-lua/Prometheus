return (function(
	lIIlI111II1,
	l1IlI111II1,
	IIIlI111II1,
	lll1I111II1,
	fEnv,
	Ill1I111II1,
	I1IlI111II1,
	l1l1I111II1,
	ll1lI111II1,
	l11lI111II1,
	I11lI111II1,
	llIlI111II1,
	lI1lI111II1,
	IlIlI111II1,
	Il1lI111II1,
	II1lI111II1
)
	II1lI111II1, I11lI111II1, llIlI111II1, Il1lI111II1, ll1lI111II1, l1l1I111II1, IlIlI111II1, lI1lI111II1, l11lI111II1 =
		function()
			lI1lI111II1 = 1 + lI1lI111II1
			llIlI111II1[lI1lI111II1] = 1
			return lI1lI111II1
		end, function(I1l1I111II1)
			for l1l1I111II1 = 1, #I1l1I111II1, 1 do
				llIlI111II1[I1l1I111II1[l1l1I111II1]] = llIlI111II1[I1l1I111II1[l1l1I111II1]] + 1
			end
			if lll1I111II1 then
				local l1l1I111II1 = lll1I111II1(true)
				local Ill1I111II1 = lIIlI111II1(l1l1I111II1)
				Ill1I111II1.__index, Ill1I111II1.__gc, Ill1I111II1.__len = I1l1I111II1, l11lI111II1, function()
					return 1137571
				end
				return l1l1I111II1
			else
				return IIIlI111II1({}, {
					__gc = l11lI111II1,
					__index = I1l1I111II1,
					__len = function()
						return 1137571
					end,
				})
			end
		end, {}, function(I1l1I111II1)
			llIlI111II1[I1l1I111II1] = llIlI111II1[I1l1I111II1] - 1
			if llIlI111II1[I1l1I111II1] == 0 then
				llIlI111II1[I1l1I111II1], IlIlI111II1[I1l1I111II1] = nil, nil
			end
		end, function(I1l1I111II1, Ill1I111II1)
			local lll1I111II1 = I11lI111II1(Ill1I111II1)
			local IIIlI111II1 = function(...)
				return l1l1I111II1(I1l1I111II1, { ... }, Ill1I111II1, lll1I111II1)
			end
			return IIIlI111II1
		end, function(func, lll1I111II1, IIIlI111II1, lIIlI111II1)
			local IlIlI111II1, funcName, arg
			while func do
				funcName, arg, IlIlI111II1 = "print", "Hello World", lll1I111II1
				func = fEnv[funcName]
				funcName = func(arg)
				func, funcName = fEnv.ihjjCiSJyMxI, {}
			end
			func = #lIIlI111II1
			return Ill1I111II1(funcName)
		end, {}, 0, function(I1l1I111II1)
			local l1l1I111II1, Ill1I111II1 = 1, I1l1I111II1[1]
			while Ill1I111II1 do
				llIlI111II1[Ill1I111II1], l1l1I111II1 = llIlI111II1[Ill1I111II1] - 1, 1 + l1l1I111II1
				if llIlI111II1[Ill1I111II1] == 0 then
					llIlI111II1[Ill1I111II1], IlIlI111II1[Ill1I111II1] = nil, nil
				end
				Ill1I111II1 = I1l1I111II1[l1l1I111II1]
			end
		end
	return (ll1lI111II1(12286839, {}))(Ill1I111II1(l1IlI111II1))
end)(getmetatable, { ... }, setmetatable, newproxy, getfenv and getfenv() or _ENV, unpack or table.unpack, select)
