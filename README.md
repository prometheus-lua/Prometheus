-- La Kabra Hub Script v1.0 - Stable Release (Sin Auto Kill)
-- Murder Vs Sheriff Duelos - Roblox

local function Notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
    print("[" .. title .. "] " .. text)
end

-- Intentar cargar Rayfield con múltiples fuentes
local Rayfield = nil
local UISources = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua"
}

for _, url in ipairs(UISources) do
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if success and result then
        Rayfield = result
        Notify("La Kabra Hub", "UI cargada correctamente")
        break
    end
end

-- Si Rayfield falla, usar Orion como fallback
if not Rayfield then
    Notify("La Kabra Hub", "Rayfield falló, usando Orion...")
    local success, Orion = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()
    end)
    
    if success and Orion then
        return CreateOrionVersion(Orion)
    else
        Notify("ERROR", "No se pudo cargar ninguna UI")
        return
    end
end

-- Servicios
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

-- Configuración
local Settings = {
    ESP = {Enabled = false, Color = Color3.fromRGB(255, 0, 0)},
    Triggerbot = {Enabled = false}
}

-- ==================== FUNCIONES DE EQUIPO ====================
local function GetPlayerTeam(player)
    -- Intentar obtener el equipo de diferentes maneras (compatibilidad con varios juegos)
    if player.Team then
        return player.Team.Name
    end
    
    -- Buscar en el personaje (algunos juegos usan valores en el personaje)
    local char = player.Character
    if char then
        local teamValue = char:FindFirstChild("Team") or char:FindFirstChild("Role") or char:FindFirstChild("RoleColor")
        if teamValue then
            return tostring(teamValue.Value)
        end
        
        -- Verificar por color de nombre (algunos juegos usan esto)
        if player.Neutral == false then
            return "Team"
        end
    end
    
    -- Para Murder Vs Sheriff Duelos - buscar en leaderstats o atributos
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local role = leaderstats:FindFirstChild("Role") or leaderstats:FindFirstChild("Rol")
        if role then
            return role.Value
        end
    end
    
    -- Buscar atributos del jugador
    local roleAttr = player:GetAttribute("Role") or player:GetAttribute("Team")
    if roleAttr then
        return tostring(roleAttr)
    end
    
    return nil
end

local function IsEnemy(player)
    if player == LocalPlayer then return false end
    
    local localTeam = GetPlayerTeam(LocalPlayer)
    local playerTeam = GetPlayerTeam(player)
    
    -- Si no podemos determinar equipos, asumir enemigo (comportamiento por defecto)
    if not localTeam or not playerTeam then
        return true
    end
    
    -- Son enemigos si están en equipos diferentes
    return localTeam ~= playerTeam
end

local function GetTeamColor(player)
    local team = GetPlayerTeam(player)
    if not team then return Color3.fromRGB(255, 0, 0) end
    
    -- Colores para Murder Vs Sheriff
    local teamLower = team:lower()
    if teamLower:find("sheriff") or teamLower:find("police") or teamLower:find("good") then
        return Color3.fromRGB(0, 100, 255) -- Azul para Sheriff
    elseif teamLower:find("murder") or teamLower:find("killer") or teamLower:find("bad") or teamLower:find("asesino") then
        return Color3.fromRGB(255, 0, 0) -- Rojo para Murder
    end
    
    return Settings.ESP.Color
end

-- ==================== VERIFICACIÓN DE PARTIDA ACTIVA ====================
local function IsInActiveRound()
    -- Verificar si el jugador local tiene un rol/equipo asignado (está en partida)
    local localTeam = GetPlayerTeam(LocalPlayer)
    
    -- Si no tiene equipo, no está en partida
    if not localTeam then
        return false
    end
    
    -- Verificar que no esté en lobby/esperando
    local teamLower = localTeam:lower()
    if teamLower:find("lobby") or teamLower:find("waiting") or teamLower:find("espera") or teamLower:find("spectator") or teamLower:find("none") or teamLower:find("ninguno") then
        return false
    end
    
    -- Verificar que el personaje exista y esté vivo
    local character = LocalPlayer.Character
    if not character then
        return false
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    
    return true
end

-- ==================== ANTI-BAN SIMPLE ====================
pcall(function()
    local oldKick = LocalPlayer.Kick
    LocalPlayer.Kick = function(self, ...) 
        Notify("Anti-Ban", "Intento de kick bloqueado")
        return nil 
    end
end)

-- ==================== ESP SISTEMA (SOLO ENEMIGOS) ====================
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "LaKabra_ESP"
ESPFolder.Parent = CoreGui

local ESPTable = {}

local function CreateESP(player)
    -- No crear ESP para uno mismo
    if player == LocalPlayer then return end
    
    -- NO crear ESP para compañeros de equipo - SOLO ENEMIGOS
    if not IsEnemy(player) then
        -- Si ya existe ESP de este jugador, eliminarlo (por si cambió de equipo)
        if ESPTable[player] and ESPTable[player].Highlight then
            ESPTable[player].Highlight:Destroy()
            ESPTable[player] = nil
        end
        return
    end
    
    -- Limpiar anterior si existe
    if ESPTable[player] and ESPTable[player].Highlight then
        ESPTable[player].Highlight:Destroy()
    end
    
    local character = player.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "LaKabraESP"
    highlight.FillColor = GetTeamColor(player)
    highlight.OutlineColor = GetTeamColor(player)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = character
    highlight.Parent = ESPFolder
    
    ESPTable[player] = {
        Highlight = highlight, 
        Character = character,
        Player = player
    }
end

local function UpdateESPForPlayer(player)
    if ESPTable[player] and ESPTable[player].Highlight then
        local color = GetTeamColor(player)
        ESPTable[player].Highlight.FillColor = color
        ESPTable[player].Highlight.OutlineColor = color
    end
end

local function ClearESP()
    for _, data in pairs(ESPTable) do
        if data.Highlight then
            data.Highlight:Destroy()
        end
    end
    ESPTable = {}
end

local function RefreshESP()
    ClearESP()
    if not Settings.ESP.Enabled then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end
end

-- Actualizar ESP cuando cambian equipos
local function MonitorTeamChanges()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            -- Monitorear cambios de equipo
            local connection
            connection = player:GetPropertyChangedSignal("Team"):Connect(function()
                if Settings.ESP.Enabled then
                    task.delay(0.5, function()
                        CreateESP(player)
                    end)
                end
            end)
        end
    end
end

-- ==================== TRIGGERBOT (SOLO EN PARTIDA) ====================
local TriggerbotConnection = nil

local function SetupTriggerbot()
    if TriggerbotConnection then
        TriggerbotConnection:Disconnect()
        TriggerbotConnection = nil
    end
    
    if not Settings.Triggerbot.Enabled then return end
    
    TriggerbotConnection = RunService.RenderStepped:Connect(function()
        -- SOLO FUNCIONAR SI ESTÁ EN PARTIDA ACTIVA
        if not IsInActiveRound() then
            return
        end
        
        local success, err = pcall(function()
            local mouse = LocalPlayer:GetMouse()
            local target = mouse.Target
            if target then
                local character = target:FindFirstAncestorOfClass("Model")
                if character then
                    local player = Players:GetPlayerFromCharacter(character)
                    -- Solo activar en enemigos
                    if player and player ~= LocalPlayer and IsEnemy(player) then
                        mouse1press()
                        task.wait(0.01)
                        mouse1release()
                    end
                end
            end
        end)
    end)
end

-- ==================== UI CON RAYFIELD ====================
local Window = Rayfield:CreateWindow({
    Name = "La Kabra Hub v1.0",
    LoadingTitle = "La Kabra Hub",
    LoadingSubtitle = "Murder Vs Sheriff Duelos",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "LaKabraHub",
        FileName = "Settings"
    },
    KeySystem = false
})

-- TAB ESP
local ESPTab = Window:CreateTab("ESP", "eye")

ESPTab:CreateToggle({
    Name = "ESP Solo Enemigos",
    CurrentValue = false,
    Flag = "ESP_Toggle",
    Callback = function(Value)
        Settings.ESP.Enabled = Value
        if Value then
            RefreshESP()
            MonitorTeamChanges()
            Notify("ESP", "Activado - Solo enemigos visibles")
        else
            ClearESP()
        end
    end
})

ESPTab:CreateColorPicker({
    Name = "Color Personalizado",
    Color = Settings.ESP.Color,
    Flag = "ESP_Color",
    Callback = function(Color)
        Settings.ESP.Color = Color
    end
})

-- TAB COMBAT
local CombatTab = Window:CreateTab("Combat", "sword")

CombatTab:CreateToggle({
    Name = "Triggerbot (Solo Enemigos)",
    CurrentValue = false,
    Flag = "Triggerbot_Toggle",
    Callback = function(Value)
        Settings.Triggerbot.Enabled = Value
        SetupTriggerbot()
        Notify("Triggerbot", Value and "Activado - Solo enemigos" or "Desactivado")
    end
})

-- Eventos de jugadores
Players.PlayerAdded:Connect(function(player)
    if Settings.ESP.Enabled then
        task.delay(1, function()
            CreateESP(player)
        end)
    end
    
    -- Monitorear cambios de equipo
    player:GetPropertyChangedSignal("Team"):Connect(function()
        if Settings.ESP.Enabled then
            task.delay(0.5, function()
                CreateESP(player)
            end)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPTable[player] then
        if ESPTable[player].Highlight then
            ESPTable[player].Highlight:Destroy()
        end
        ESPTable[player] = nil
    end
end)

-- Actualizar ESP cuando cambian personajes
LocalPlayer.CharacterAdded:Connect(function()
    if Settings.ESP.Enabled then
        task.delay(1, RefreshESP)
    end
end)

-- Monitorear cambio de equipo del jugador local
LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    if Settings.ESP.Enabled then
        Notify("La Kabra Hub", "Cambio de equipo detectado - Actualizando ESP")
        task.delay(0.5, RefreshESP)
    end
end)

-- Cargar configuración
pcall(function()
    Rayfield:LoadConfiguration()
end)

Notify("La Kabra Hub", "Script cargado correctamente v1.0 - ESP solo enemigos activo")
