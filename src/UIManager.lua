-- @Discord_alvin6974. / Bloxstrike Skinchanger / UIManager (arvn-based, viewport cards)
local Arvn = nil
local API = nil
local Config = nil
local Database = nil
local KnifeCatalog = nil
local GunCatalog = nil
local GloveCatalog = nil

local UIManager = {
    Initialized = false,
    Window = nil,
    CurrentView = "Knives", -- "Knives" | "Guns"
    CurrentKnife = nil,
    CurrentGun = nil,
    ViewportCleanups = {}
}

local RarityColors = {
    Special   = Color3.fromRGB(255, 215, 0),
    Forbidden = Color3.fromRGB(255, 140, 0),
    Red       = Color3.fromRGB(235, 75, 75),
    Pink      = Color3.fromRGB(211, 44, 230),
    Purple    = Color3.fromRGB(136, 71, 255),
    Blue      = Color3.fromRGB(75, 106, 255),
    Stock     = Color3.fromRGB(150, 155, 165),
}

local function getRarityColor(name)
    if name == "Special" or name == "Random" then return RarityColors.Special end
    if name == "Stock" or name == "Default" or name == "Vanilla" then return RarityColors.Stock end
    return RarityColors.Blue
end

local function cleanupViewports()
    for _, fn in ipairs(UIManager.ViewportCleanups) do
        pcall(fn)
    end
    UIManager.ViewportCleanups = {}
end

local function setupViewport(parent, modelName, skinName, isKnife)
    if not parent then return nil end
    
    parent:ClearAllChildren()
    
    local SkinsLib = nil
    pcall(function()
        SkinsLib = require(game:GetService("ReplicatedStorage").Database.Components.Libraries.Skins)
    end)
    
    if not SkinsLib then return nil end
    
    local model = nil
    local trySkins = { skinName, "Stock", "Vanilla", "Fade", "Midas", "Lore" }
    for _, s in ipairs(trySkins) do
        if s and s ~= "Random" and s ~= "Special" then
            local ok, m = pcall(function()
                return SkinsLib.GetCharacterModel(modelName, s, 0.001)
            end)
            if ok and m then
                model = m
                break
            end
        end
    end
    
    if not model then
        pcall(function()
            model = SkinsLib.GetCharacterModel(modelName, "Stock", 0.001)
        end)
    end
    
    if not model then return nil end
    
    local clone = nil
    local cloneOk, cloneRes = pcall(function()
        return model:Clone()
    end)
    if cloneOk and cloneRes then
        clone = cloneRes
    else
        clone = model
    end
    
    if not clone then return nil end
    clone.Parent = parent
    
    local cf, sz = clone:GetBoundingBox()
    local maxDim = math.max(sz.X, sz.Y, sz.Z, 0.5)
    local dist = maxDim * 0.81
    
    local camera = Instance.new("Camera")
    camera.FieldOfView = 50
    local camPos = cf.Position + Vector3.new(dist * 0.75, dist * 0.35, dist * 0.8)
    camera.CFrame = CFrame.new(camPos, cf.Position)
    camera.Parent = parent
    
    parent.CurrentCamera = camera
    parent.LightColor = Color3.fromRGB(245, 245, 255)
    parent.Ambient = Color3.fromRGB(150, 150, 160)
    parent.LightDirection = Vector3.new(-1, -1.2, -1).Unit
    
    local RunService = game:GetService("RunService")
    local rotConn = nil
    local isHovered = false
    local currentAngle = 0
    
    local function onStep(dt)
        if isHovered and clone and clone.Parent and camera and camera.Parent then
            currentAngle = currentAngle + dt * 1.8
            local rotatedOffset = CFrame.Angles(0, currentAngle, 0) * Vector3.new(dist * 0.75, dist * 0.35, dist * 0.8)
            camera.CFrame = CFrame.new(cf.Position + rotatedOffset, cf.Position)
        end
    end
    
    rotConn = RunService.RenderStepped:Connect(onStep)
    table.insert(UIManager.ViewportCleanups, function()
        if rotConn then pcall(function() rotConn:Disconnect() end) end
    end)
    
    return {
        setHover = function(hovered)
            isHovered = hovered
            if not hovered and camera and camera.Parent then
                camera.CFrame = CFrame.new(camPos, cf.Position)
                currentAngle = 0
            end
        end
    }
end

function UIManager.init(config, arvn, api, database, knifeCatalog, gunCatalog, gloveCatalog)
    if UIManager.Initialized then return end
    UIManager.Initialized = true
    
    Config = config
    Arvn = arvn
    API = api
    Database = database
    KnifeCatalog = knifeCatalog
    GunCatalog = gunCatalog
    GloveCatalog = gloveCatalog

    local Window = Arvn:CreateWindow({
        Title = "Bloxstrike Skinchanger",
        Author = "@Discord_alvin6974.",
        Folder = "Bloxstrike_Skinchanger"
    })
    UIManager.Window = Window

    local Main = Window:Group("Main")
    local Tab = Main:Tab({Name = "Skins", Icon = "palette"})
    local Section = Tab:Section("Skin Selection")

    -- Toggle buttons for Knives/Guns
    Section:Button({
        Name = "Show Knives",
        Callback = function()
            UIManager.CurrentView = "Knives"
            if UIManager.Refresh then UIManager.Refresh() end
        end
    })

    Section:Button({
        Name = "Show Guns",
        Callback = function()
            UIManager.CurrentView = "Guns"
            if UIManager.Refresh then UIManager.Refresh() end
        end
    })

    -- Refresh function to render cards
    UIManager.Refresh = function()
        cleanupViewports()
        
        if UIManager.CurrentView == "Knives" then
            local knifeNames = KnifeCatalog.getNames and KnifeCatalog.getNames() or {}
            for _, knifeName in ipairs(knifeNames) do
                local isSelected = (Config.KNIFE_MODEL == knifeName)
                local card = Section:Button({
                    Name = knifeName,
                    Callback = function()
                        Config.KNIFE_MODEL = knifeName
                        Config.KNIFE_SKIN = "Special"
                        if API and API.setKnife then
                            API.setKnife(knifeName, "Special")
                        end
                        Arvn:Notify({Title = "Skinchanger", Content = "Equipped " .. knifeName, Kind = "Success"})
                        if UIManager.Refresh then UIManager.Refresh() end
                    end
                })
            end
        else
            local gunNames = GunCatalog.getNames and GunCatalog.getNames() or {}
            for _, gunName in ipairs(gunNames) do
                local card = Section:Button({
                    Name = gunName,
                    Callback = function()
                        Config.SELECTED_WEAPON_TYPE = gunName
                        if UIManager.Refresh then UIManager.Refresh() end
                    end
                })
                
                -- Show skins for selected gun
                if Config.SELECTED_WEAPON_TYPE == gunName then
                    local skins = GunCatalog.getSkins and GunCatalog.getSkins(gunName) or {}
                    for _, skinName in ipairs(skins) do
                        local isSelected = (Config.SELECTED_SKINS and Config.SELECTED_SKINS[gunName] == skinName)
                        Section:Button({
                            Name = "  " .. skinName,
                            Callback = function()
                                if API and API.setWeaponSkin then
                                    API.setWeaponSkin(gunName, skinName)
                                end
                                Arvn:Notify({Title = "Skinchanger", Content = gunName .. " - " .. skinName, Kind = "Success"})
                            end
                        })
                    end
                end
            end
        end
    end

    -- Presets section
    local PresetsSection = Tab:Section({Name = "Presets", Side = "Right"})
    
    PresetsSection:Button({
        Name = "All Special",
        Callback = function()
            if API and API.setAllSpecial then
                API.setAllSpecial()
                Arvn:Notify({Title = "Skinchanger", Content = "All special skins applied!", Kind = "Success"})
            end
        end
    })

    PresetsSection:Button({
        Name = "All Random",
        Callback = function()
            if API and API.setAllRandom then
                API.setAllRandom()
                Arvn:Notify({Title = "Skinchanger", Content = "Random skins applied!", Kind = "Success"})
            end
        end
    })

    PresetsSection:Button({
        Name = "All Default",
        Callback = function()
            if API and API.setAllDefault then
                API.setAllDefault()
                Arvn:Notify({Title = "Skinchanger", Content = "Default skins restored!", Kind = "Success"})
            end
        end
    })

    PresetsSection:Button({
        Name = "Reroll Random",
        Callback = function()
            if API and API.rerollRandom then
                API.rerollRandom()
                Arvn:Notify({Title = "Skinchanger", Content = "Random skins rerolled!", Kind = "Success"})
            end
        end
    })

    -- Initial render
    UIManager.Refresh()

    -- Show menu on startup
    task.spawn(function()
        task.wait(0.5)
        if not Arvn.Toggled then
            pcall(Arvn.Toggle, Arvn)
        end
    end)

    Arvn:Notify({Title = "Skinchanger", Content = "Loaded!", Kind = "Success"})
end

function UIManager.cleanup()
    cleanupViewports()
    if Arvn and Arvn.Toggled then
        pcall(Arvn.Toggle, Arvn)
    end
    UIManager.Initialized = false
    UIManager.Window = nil
end

return UIManager