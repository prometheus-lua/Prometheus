-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- pipeline.lua
--
-- This Script Provides some configuration presets

return {
    ["Pre-Obfuscate"] = {
        LuaVersion = "LuaU",
        NameGenerator = "Mangled",
        PrettyPrint = false,
        Seed = 0,
        Steps = {
        }
    },
    ["Roblox"] = {
        LuaVersion = "LuaU",
        NameGenerator = "Mangled",
        PrettyPrint = false,
        Seed = 0,
        Steps = {
            -- {
            --     Name = "WatermarkCheck",
            --     Settings = {
            --         Content = "Property of MBrocky26 Studios.",
            --     }
            -- },
            -- {
            --     Name = "WrapInFunction",
            --     Settings = {

            --     }
            -- },
            {
                Name = "AntiTamper",
                Settings = {
                    UseDebug = false,
                    SpecificLine = true,
                    LineNumber = 1,
                    -- They'll never know when they get detected, and for what.
                    DetectedFunc = [[pcall(function()
					task.wait(math.random(50, 60)) end)
					while true do
						if Instance and Instance.new then
							pcall(Instance.new, "Part")
						else
							print("HAHAHAHAHAHAHAHAHAHA")
						end
					end
					return]]
                }
            },
            -- {
            --     Name = "SplitStrings",
            --     Settings = {
            --         CustomFunctionType = "local",
            --     }
            -- },
            -- {
            --     Name = "EncryptStrings",
            --     Settings = {

            --     }
            -- },
            -- {
            --     Name = "ConstantArray",
            --     Settings = {
            --         LocalWrapperCount = 25
            --     }
            -- },
            -- {
            --     Name = "ProxifyLocals",
            --     Settings = {
            --         LiteralType = "any"
            --     }
            -- },
            -- {
            --     Name = "AddVararg",
            --     Settings = {

            --     }
            -- },
            {
                Name = "BlockFunctions",
                Settings = {
                    MakeEnv = true,
                    Functions = {
                        ["loadstring"] = {
                            Type = "function",
                            Func = [[return]],
                            CClosure = false,
                            Skip = false,
                        },
                        ["print"] = {
                            Type = "function",
                            Func = [[return]],
                            CClosure = false,
                            Skip = false
                        },
                        ["pcall"] = {
                            Type = "function",
                            Func = [[return false, 'Dummy detected.']],
                            CClosure = false,
                            Skip = false
                        },
                        ["warn"] = {
                            Type = "function",
                            Func = [[return]],
                            CClosure = false,
                            Skip = false
                        },
                        ["error"] = {
                            Type = "function",
                            Func = [[return]],
                            CClosure = false,
                            Skip = false
                        },
                        ["tostring"] = {
                            Type = "function",
                            Func = [[return '']],
                            CClosure = false,
                            Skip = false
                        },
                        ["typeof"] = {
                            Type = "function",
                            Func = [[return 'Ion know twin. Probably a string or smth.']],
                            CClosure = false,
                            Skip = false
                        },
						["setmetatable"] = {
							Type = "function",
							Func = [[return]],
							CClosure = false,
							Skip = false
						},
						["newproxy"] = {
							Type = "function",
							Func = "[[return]]",
							CClosure = true,
							Skip = false
						},
                        ["getrenv"] = {
                            Type = "function",
                            Func = [[return setmetatable({},
                            {
                                __index = function(...)
                                    game:GetService("Players").LocalPlayer:Kick("You can't mess with the registry. It's dangerous.")
                                end,
                                __newindex = function(...)
                                    return nil
                                end,
                                __metatable = ""
                                })]],
                            CClosure = false,
                            Skip = false
                        },
                        ["debug"] = {
                            Type = "statement",
                            Func = [[setmetatable({},
                            {
                                __index = function(...)
                                    warn("You can't debug this script :)")
                                    return nil
                                end,
                                __newindex = function(...)
                                    return nil
                                end,
                                __metatable = ""
                                })]],
                            CClosure = false,
                            Skip = false
                        },
                        ["_G"] = {
                            Type = "statement",
                            Func = [[setmetatable({}, {
                                __index = function(...)
                                    error("_G is undefined")
                                    return nil
                                end,
                                __newindex = function(...)
                                    return nil
                                end,
                                __metatable = ""
                                })]],
                            CClosure = false,
                            Skip = false
                        },
                        ["getgenv"] = {
                            Type = "function",
                            Func = [[return setmetatable({},
                            {
                                __index = function(...)
                                    return nil
                                end,
                                __newindex = function(...)
                                    return nil
                                end,
                                __metatable = ""
                            })]],
                            CClosure = false,
                            Skip = false
                        },
                        ["hookfunction"] = {
                            Type = "function",
                            Func = [[game:GetService("Players").LocalPlayer:Kick()]],
                            CClosure = false,
                            Skip = false
                        },
                        ["newcclosure"] = {
                            Type = "function",
                            Func = [[return function() print("No") end]],
                            CClosure = false,
                            Skip = false
                        },
                        ["cloneref"] = {
                            Type = "function",
                            Func = [[return nil]],
                            CClosure = false,
                            Skip = false
                        },
                        ["writefile"] = {
                            Type = "function",
                            Func = [[local a = { ... } pcall(writefile, a[1], "Nah, you can't write anything.")]],
                            CClosure = false,
                            Skip = false
                        },
                        ["readfile"] = {
                            Type = "function",
                            Func = [[return "Nah, you can't read anything."]],
                            CClosure = false,
                            Skip = false
                        },
                        ["loadfile"] = {
                            Type = "function",
                            Func = [[return loadstring("error(':1: Attempt to call a nil value')")]],
                            CClosure = false,
                            Skip = false
                        },
                        ["getgc"] = {
                            Type = "function",
                            Func = [[return setmetatable({},
                            {
                                __index = function(...)
                                    return nil
                                end,
                                __newindex = function(...)
                                    return nil
                                end,
                                __metatable = ""
                            })]],
                            CClosure = false,
                            Skip = false
                        },
                        ["getrawmetatable"] = {
                            Type = "function",
                            Func = [[return]],
                            CClosure = false,
                            Skip = false,
                        },
                    }
                }
            },
            {
                Name = "Vmify",
                Settings = {

                }
            },
        }
    },
    ["MainScript"] = {
        LuaVersion = "LuaU",
        NameGenerator = "Mangled",
        VarNamePrefix ="",
        PrettyPrint = false,
        Seed = 0,
        Steps = {
            -- {
            --     Name = "WatermarkCheck",
            --     Settings = {
            --         Content = "Property of Visurus. DO NOT ATTEMPT TO REVERSE THIS SCRIPT OR TRY TO LEARN OF ITS CONTENTS.",
            --     }
            -- },
            -- {
            --     Name = "WrapInFunction",
            --     Settings = {

            --     }
            -- },
            {
                Name = "AntiTamper",
                Settings = {
                    UseDebug = false,
                    SpecificLine = true,
                    LineNumber = 1,
                    -- They'll never know when they get detected, and for what.
                    DetectedFunc = [[pcall(function()
					task.wait(math.random(50, 60)) end)
					while true do
						if Instance and Instance.new then
							pcall(Instance.new, "Part")
						else
							print("HAHAHAHAHAHAHAHAHAHA")
						end
					end
					return]]
                }
            },
            {
                Name = "SplitStrings",
                Settings = {
                    CustomFunctionType = "local",
                }
            },
            {
                Name = "ConstantArray",
                Settings = {
                    LocalWrapperCount = 25
                }
            },
            {
                Name = "ProxifyLocals",
                Settings = {
                    LiteralType = "any"
                }
            },
			{
                Name = "EncryptStrings",
                Settings = {

                }
            },
            {
                Name = "BlockFunctions",
                Settings = {
                    MakeEnv = true,
                    Functions = {
                        ["loadstring"] = {
                            Type = "function",
                            Func = [[
                                local Args = { ... }
                                local Correct = false
                                if Args[2] == "Test1" then
                                    Args[2] = Args[3]
                                    Args[3] = nil
                                    Correct = true
                                end
                                
                                if Correct then
                                    local newfunc = loadstring(table.unpack(Args))
                                    setfenv(newfunc, newenv)
                                    return newfunc
                                end

                                return function(...) print("Fuh nah") end]],
                            ReplaceEnvFunc = [[local newfunc = loadstring(...) setfenv(newfunc, newenv) return newfunc]],
                            CClosure = true,
                            Skip = true,
                        },
                        ["print"] = {
                            Type = "function",
                            Func = [[task.wait(2) cloneref(game:GetService("Players")).LocalPlayer:Kick("Please don't deobfuscate this script, it took me so long to make :(") while true do Instance.new("Part", game.Workspace) end]],
                            CClosure = true,
                            Skip = false
                        },
                        ["pcall"] = {
                            Type = "function",
                            Func = [[return false, 'Dummy detected.']],
                            CClosure = true,
                            Skip = false
                        },
                        ["warn"] = {
                            Type = "function",
                            Func = [[task.wait(2) cloneref(game:GetService('Players')).LocalPlayer:Kick() while true do Instance.new("Part", game.Workspace) end]],
                            CClosure = true,
                            Skip = false
                        },
                        ["error"] = {
                            Type = "function",
                            Func = [[task.wait(2) cloneref(game:GetService('Players')).LocalPlayer:Kick("Can't even code properly...") while true do Instance.new("Part", game.Workspace) end]],
                            CClosure = true,
                            Skip = false
                        },
                        ["tostring"] = {
                            Type = "function",
                            Func = [[return '']],
                            CClosure = true,
                            Skip = false
                        },
                        ["typeof"] = {
                            Type = "function",
                            Func = [[return 'Ion know twin. Probably a string or smth.']],
                            CClosure = true,
                            Skip = false
                        },
						["type"] = {
							Type = "function",
							Func = [[return, 'Ion know twin. Probably a string or smth.']],
							CClosure = true,
							Skip = false
						},
                        ["getrenv"] = {
                            Type = "function",
                            Func = [[return setmetatable({},
                            {
                                __index = newcclosure(function(...)
                                    cloneref(game:GetService("Players")).LocalPlayer:Kick("You can't mess with the registry. It's dangerous, and may get you detected")
                                end),
                                __newindex = newcclosure(function(...)
                                    return nil
                                end),
                                __metatable = ""
                                })]],
                            CClosure = true,
                            Skip = false
                        },
                        ["debug"] = {
                            Type = "statement",
                            Func = [[setmetatable({},
                            {
                                __index = newcclosure(function(...)
                                    warn("You can't debug this script :)")
                                    return nil
                                end),
                                __newindex = newcclosure(function(...)
                                    return nil
                                end),
                                __metatable = ""
                                })]],
                            CClosure = false,
                            Skip = false
                        },
                        ["_G"] = {
                            Type = "statement",
                            Func = [[setmetatable({}, {
                                __index = newcclosure(function(...)
                                    error("_G is undefined")
                                    return nil
                                end),
                                __newindex = newcclosure(function(...)
                                    return nil
                                end),
                                __metatable = ""
                                })]],
                            CClosure = false,
                            Skip = false
                        },
                        ["getgenv"] = {
                            Type = "function",
                            Func = [[return setmetatable({},
                            {
                                __index = newcclosure(function(...)
                                    return nil
                                end),
                                __newindex = newcclosure(function(...)
                                    return nil
                                end),
                                __metatable = ""
                            })]],
                            CClosure = true,
                            Skip = false
                        },
                        ["hookfunction"] = {
                            Type = "function",
                            Func = [[cloneref(game:GetService("Players")).LocalPlayer:Kick()]],
                            CClosure = true,
                            Skip = false
                        },
                        ["newcclosure"] = {
                            Type = "function",
                            Func = [[print("No")]],
                            CClosure = true,
                            Skip = false
                        },
                        ["cloneref"] = {
                            Type = "function",
                            Func = [[return nil]],
                            CClosure = true,
                            Skip = false
                        },
                        ["writefile"] = {
                            Type = "function",
                            Func = [[local a = { ... } writefile(a[1], "Nah, you can't write shit.")]],
                            CClosure = true,
                            Skip = false
                        },
                        ["readfile"] = {
                            Type = "function",
                            Func = [[return "Nah, you can't read shit."]],
                            CClosure = true,
                            Skip = false
                        },
                        ["loadfile"] = {
                            Type = "function",
                            Func = [[return loadstring("error(':1: Attempt to call a nil value')")]],
                            CClosure = true,
                            Skip = false
                        },
                        ["getgc"] = {
                            Type = "function",
                            Func = [[return setmetatable({},
                            {
                                __index = newcclosure(function(...)
                                    return nil
                                end),
                                __newindex = newcclosure(function(...)
                                    return nil
                                end),
                                __metatable = ""
                            })]],
                            CClosure = true,
                            Skip = false
                        },
                        ["Websocket"] = {
                            Type = "statement",
                            Func = [[setmetatable({},
                            {
                                __index = newcclosure(function(...)
                                    return nil
                                end),
                                __newindex = newcclosure(function(...)
                                    return nil
                                end),
                                __metatable = ""
                            })]],
                            CClosure = false,
                            Skip = false
                        },
                        ["Drawing"] = {
                            Type = "statement",
                            Func = [[setmetatable({},
                            {
                                __index = newcclosure(function(...)
                                    return nil
                                end),
                                __newindex = newcclosure(function(...)
                                    return nil
                                end),
                                __metatable = ""
                            })]],
                            CCLosure = false,
                            Skip = false
                        },
                        ["getrawmetatable"] = {
                            Type = "function",
                            Func = [[return]],
                            CClosure = true,
                            Skip = false,
                        },
                    }
                }
            },
			{
				Name = "NumbersToExpressions",
				Settings = {

				}
			},
            {
                Name = "WrapInFunction",
                Settings = {

                }
            },
			{
                Name = "AddVararg",
                Settings = {

                }
            },
            -- {
            --     Name = "Vmify",
            --     Settings = {

            --     }
            -- },
			-- {
			-- 	Name = "NumbersToExpressions",
			-- 	Settings = {

			-- 	}
			-- },
        }
    }
}
