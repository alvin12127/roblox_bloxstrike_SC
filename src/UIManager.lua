-- @Discord_alvin6974. / Bloxstrike Skinchanger / UIManager (image-based skin selector)
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
    Visible = false,
    SkinsLib = nil
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

local function getSkinsLib()
    if UIManager.SkinsLib then return UIManager.SkinsLib end
    local ok, lib = pcall(function()
        return require(game:GetService("ReplicatedStorage").Database.Components.Libraries.Skins)
    end)
    if ok and lib then
        UIManager.SkinsLib = lib
        return lib
    end
    return nil
end

local function createSkinCard(parent, modelName, skinName, isKnife, rarityColor)
    local SkinsLib = getSkinsLib()
    if not SkinsLib then return nil end
    
    local card = Instance.new("Frame")
    card.Name = "SkinCard"
    card.Size = UDim2.new(0, 120, 0, 140)
    card.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    card.BorderSizePixel = 0
    card.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card
    
    -- Try to load 3D model preview
    local model = nil
    local trySkins = { skinName, "Stock", "Vanilla", "Fade" }
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
    
    if model then
        local viewport = Instance.new("ViewportFrame")
        viewport.Size = UDim2.new(1, -8, 0, 100)
        viewport.Position = UDim2.new(0, 4, 0, 4)
        viewport.BackgroundTransparency = 1
        viewport.Parent = card
        
        local clone = model:Clone()
        clone.Parent = viewport
        
        local cf, sz = clone:GetBoundingBox()
        local maxDim = math.max(sz.X, sz.Y, sz.Z, 0.5)
        local dist = maxDim * 0.81
        
        local camera = Instance.new("Camera")
        camera.FieldOfView = 50
        local camPos = cf.Position + Vector3.new(dist * 0.75, dist * 0.35, dist * 0.8)
        camera.CFrame = CFrame.new(camPos, cf.Position)
        camera.Parent = viewport
        viewport.CurrentCamera = camera
    end
    
    -- Skin name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -8, 0, 20)
    nameLabel.Position = UDim2.new(0, 4, 0, 104)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = skinName
    nameLabel.TextColor3 = rarityColor
    nameLabel.TextSize = 12
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.Parent = card
    
    -- Model name label
    local modelLabel = Instance.new("TextLabel")
    modelLabel.Size = UDim2.new(1, -8, 0, 16)
    modelLabel.Position = UDim2.new(0, 4, 0, 124)
    modelLabel.BackgroundTransparency = 1
    modelLabel.Text = modelName
    modelLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
    modelLabel.TextSize = 10
    modelLabel.Font = Enum.Font.Gotham
    modelLabel.TextXAlignment = Enum.TextXAlignment.Center
    modelLabel.Parent = card
    
    -- Click to select
    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = card
    
    clickDetector.MouseButton1Click:Connect(function()
        if isKnife then
            Config.KNIFE_MODEL = modelName
            Config.KNIFE_SKIN = skinName
            if API and API.setKnife then
                API.setKnife(modelName, skinName)
            end
        else
            Config.SELECTED_WEAPON_TYPE = modelName
            if API and API.setWeaponSkin then
                API.setWeaponSkin(modelName, skinName)
            end
        end
        Arvn:Notify({Title = "Skinchanger", Content = modelName .. " - " .. skinName, Kind = "Success"})
    end)
    
    return card
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
        Title = "Skin Changer",
        Author = "@Discord_alvin6974.",
        Folder = "Bloxstrike_Skinchanger"
    })
    UIManager.Window = Window

    local Main = Window:Group("Main")
    local Tab = Main:Tab({Name = "Skins", Icon = "palette"})
    local Section = Tab:Section("Knives")

    -- Knife models
    local knifeNames = {}
    if KnifeCatalog and KnifeCatalog.getNames then
        local ok, list = pcall(function() return KnifeCatalog.getNames() end)
        if ok and list then knifeNames = list end
    end
    if #knifeNames == 0 then
        knifeNames = {"Butterfly Knife", "Karambit", "M9 Bayonet", "Skeleton", "Default"}
    end

    for _, knifeName in ipairs(knifeNames) do
        local skins = {"Special", "Fade", "Stock", "Vanilla"}
        for _, skinName in ipairs(skins) do
            local rarityColor = getRarityColor(skinName)
            createSkinCard(Section.Container, knifeName, skinName, true, rarityColor)
        end
    end

    -- Guns section
    local GunsSection = Tab:Section({Name = "Guns", Side = "Right"})

    local gunNames = {}
    if GunCatalog and GunCatalog.getNames then
        local ok, list = pcall(function() return GunCatalog.getNames() end)
        if ok and list then gunNames = list end
    end
    if #gunNames == 0 then
        gunNames = {"AK-47", "M4A1", "AWP", "Desert Eagle", "USP-S", "Glock-18"}
    end

    for _, gunName in ipairs(gunNames) do
        local skins = {"Special", "Fade", "Stock", "Vanilla"}
        for _, skinName in ipairs(skins) do
            local rarityColor = getRarityColor(skinName)
            createSkinCard(GunsSection.Container, gunName, skinName, false, rarityColor)
        end
    end

    -- Presets
    local PresetsSection = Tab:Section({Name = "Presets", Side = "Right"})

    PresetsSection:Button({
        Name = "All Special",
        Callback = function()
            if API and API.setAllSpecial then
                API.setAllSpecial()
                Arvn:Notify({Title = "Skinchanger", Content = "All special!", Kind = "Success"})
            end
        end
    })

    PresetsSection:Button({
        Name = "All Random",
        Callback = function()
            if API and API.setAllRandom then
                API.setAllRandom()
                Arvn:Notify({Title = "Skinchanger", Content = "Random!", Kind = "Success"})
            end
        end
    })

    PresetsSection:Button({
        Name = "All Default",
        Callback = function()
            if API and API.setAllDefault then
                API.setAllDefault()
                Arvn:Notify({Title = "Skinchanger", Content = "Default!", Kind = "Success"})
            end
        end
    })

    PresetsSection:Button({
        Name = "Reroll",
        Callback = function()
            if API and API.rerollRandom then
                API.rerollRandom()
                Arvn:Notify({Title = "Skinchanger", Content = "Rerolled!", Kind = "Success"})
            end
        end
    })

    -- Hide by default
    if Arvn.Toggle then
        pcall(Arvn.Toggle, Arvn)
    end
end

function UIManager.cleanup()
    UIManager.Initialized = false
    UIManager.Window = nil
end

function UIManager.show()
    if Arvn and not Arvn.Toggled then
        pcall(Arvn.Toggle, Arvn)
    end
end

function UIManager.hide()
    if Arvn and Arvn.Toggled then
        pcall(Arvn.Toggle, Arvn)
    end
end

return UIManager