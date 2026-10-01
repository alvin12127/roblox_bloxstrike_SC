-- @Discord_alvin6974. / Bloxstrike Skinchanger / UIManager (arvn-based, viewport skin browser)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local API = nil
local Config = nil
local Database = nil
local KnifeCatalog = nil
local GunCatalog = nil
local GloveCatalog = nil
local ArvnRef = nil

local UIManager = {
    Initialized = false,
    MainTab = nil,
    CurrentCategory = "Knives",
    CurrentWeapon = nil,
    Popup = nil,
    ViewportCleanups = {}
}

local SkinsLib = nil
local function getSkinsLib()
    if SkinsLib then return SkinsLib end
    pcall(function()
        SkinsLib = require(ReplicatedStorage.Database.Components.Libraries.Skins)
    end)
    return SkinsLib
end

local function safeNotify(title, content, kind)
    if ArvnRef and ArvnRef.Notify then
        pcall(ArvnRef.Notify, ArvnRef, {Title = title, Content = content, Kind = kind or "Info"})
    end
end

local function cleanupViewports()
    for _, fn in ipairs(UIManager.ViewportCleanups) do
        pcall(fn)
    end
    UIManager.ViewportCleanups = {}
end

-- Render a 3D model into a ViewportFrame
local function renderModelInViewport(vp, modelName, skinName)
    if not vp then return end
    vp:ClearAllChildren()

    -- Placeholder label while loading / on failure
    local ph = Instance.new("TextLabel")
    ph.Size = UDim2.fromScale(1, 1)
    ph.BackgroundTransparency = 1
    ph.Text = "..."
    ph.TextColor3 = Color3.fromRGB(160, 160, 170)
    ph.Font = Enum.Font.Gotham
    ph.TextSize = 12
    ph.ZIndex = 504
    ph.Parent = vp

    local lib = getSkinsLib()
    if not lib then
        ph.Text = "No SkinsLib"
        return
    end

    -- Knives: "Default" maps to "CT Knife" (same as original catalogs)
    local targetModel = modelName
    if targetModel == "Default" then
        targetModel = "CT Knife"
    end

    -- Try the requested skin first, then a broad fallback list
    local model = nil
    local trySkins = {skinName, "Stock", "Vanilla", "Fade", "Midas", "Lore", "Ren", "Lebron James"}
    for _, s in ipairs(trySkins) do
        if s and s ~= "Random" and s ~= "Special" and s ~= "Default" then
            local ok, m = pcall(function()
                return lib.GetCharacterModel(targetModel, s, 0.001)
            end)
            if ok and m then
                model = m
                break
            end
        end
    end

    if not model then
        pcall(function()
            model = lib.GetCharacterModel(targetModel, "Stock", 0.001)
        end)
    end

    if not model then
        ph.Text = "No model"
        return
    end

    -- Remove placeholder once we have a model
    ph:Destroy()

    local clone = nil
    local ok, res = pcall(function() return model:Clone() end)
    clone = ok and res or model
    if not clone then return end

    clone.Parent = vp

    local cf, sz = clone:GetBoundingBox()
    local maxDim = math.max(sz.X, sz.Y, sz.Z, 0.5)
    local dist = maxDim * 0.81

    local cam = Instance.new("Camera")
    cam.FieldOfView = 50
    local camPos = cf.Position + Vector3.new(dist * 0.75, dist * 0.35, dist * 0.8)
    cam.CFrame = CFrame.new(camPos, cf.Position)
    cam.Parent = vp
    vp.CurrentCamera = cam
    vp.LightColor = Color3.fromRGB(245, 245, 255)
    vp.Ambient = Color3.fromRGB(150, 150, 160)
    vp.LightDirection = Vector3.new(-1, -1.2, -1).Unit
end

-- Close the popup
local function closePopup()
    cleanupViewports()
    if UIManager.Popup then
        pcall(function() UIManager.Popup:Destroy() end)
        UIManager.Popup = nil
    end
end

-- Open the skin browser popup
local function openPopup(category, weaponName)
    closePopup()

    local library = ArvnRef
    if not library then return end

    -- Get the ScreenGui from arvn
    local screenGui = library.ScreenGui
    if not screenGui then return end

    -- Get skins for this weapon
    local skins = {}
    if category == "Knives" then
        if Database and Database.getKnifeSkinList then
            pcall(function() skins = Database.getKnifeSkinList(weaponName) end)
        end
    else
        if Database and Database.getWeaponSkinList then
            pcall(function() skins = Database.getWeaponSkinList(weaponName) end)
        end
    end
    if #skins == 0 then
        skins = {"Special", "Fade", "Stock", "Vanilla"}
    end

    -- Popup frame
    local popup = Instance.new("Frame")
    popup.Name = "SkinBrowserPopup"
    popup.Size = UDim2.fromOffset(560, 420)
    popup.Position = UDim2.fromScale(0.5, 0.5)
    popup.AnchorPoint = Vector2.new(0.5, 0.5)
    popup.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
    popup.BorderSizePixel = 0
    popup.ZIndex = 500
    popup.Parent = screenGui

    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", popup)
    stroke.Color = Color3.fromRGB(45, 48, 58)
    stroke.Transparency = 0.65

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 36)
    header.BackgroundColor3 = Color3.fromRGB(23, 23, 25)
    header.BorderSizePixel = 0
    header.ZIndex = 501
    header.Parent = popup
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.fromOffset(12, 0)
    title.BackgroundTransparency = 1
    title.Text = weaponName .. " - " .. category .. " Skins (" .. #skins .. ")"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 502
    title.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(30, 30)
    closeBtn.Position = UDim2.new(1, -30, 0, 3)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.ZIndex = 503
    closeBtn.Parent = header
    closeBtn.MouseButton1Click:Connect(closePopup)

    -- Scrolling grid
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -48)
    scroll.Position = UDim2.fromOffset(8, 42)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(186, 140, 255)
    scroll.ZIndex = 501
    scroll.Parent = popup
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(130, 150)
    grid.CellPadding = UDim2.fromOffset(8, 8)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = scroll

    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 10)
    end)

    -- Rarity colors
    local rarityColors = {
        Special = Color3.fromRGB(255, 215, 0),
        Stock = Color3.fromRGB(150, 155, 165),
        Default = Color3.fromRGB(150, 155, 165),
        Vanilla = Color3.fromRGB(150, 155, 165),
    }

    -- Create skin cards
    for idx, skinName in ipairs(skins) do
        local rarityColor = rarityColors[skinName] or Color3.fromRGB(75, 106, 255)

        local card = Instance.new("TextButton")
        card.Name = "Skin_" .. idx
        card.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        card.BorderSizePixel = 0
        card.Text = ""
        card.LayoutOrder = idx
        card.ZIndex = 502
        card.Parent = scroll
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

        local cardStroke = Instance.new("UIStroke", card)
        cardStroke.Color = Color3.fromRGB(45, 48, 58)
        cardStroke.Transparency = 0.5

        -- Viewport
        local vp = Instance.new("ViewportFrame")
        vp.Size = UDim2.new(1, -6, 0, 100)
        vp.Position = UDim2.fromOffset(3, 3)
        vp.BackgroundTransparency = 1
        vp.ZIndex = 503
        vp.Parent = card

        renderModelInViewport(vp, weaponName, skinName)

        -- Rarity bar
        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, 3)
        bar.Position = UDim2.new(0, 0, 1, -3)
        bar.BackgroundColor3 = rarityColor
        bar.BorderSizePixel = 0
        bar.ZIndex = 504
        bar.Parent = card

        -- Skin name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -6, 0, 20)
        nameLabel.Position = UDim2.new(0, 3, 0, 106)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = skinName
        nameLabel.TextColor3 = rarityColor
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Center
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.ZIndex = 504
        nameLabel.Parent = card

        -- Model name
        local modelLabel = Instance.new("TextLabel")
        modelLabel.Size = UDim2.new(1, -6, 0, 16)
        modelLabel.Position = UDim2.new(0, 3, 0, 126)
        modelLabel.BackgroundTransparency = 1
        modelLabel.Text = weaponName
        modelLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
        modelLabel.Font = Enum.Font.Gotham
        modelLabel.TextSize = 10
        modelLabel.TextXAlignment = Enum.TextXAlignment.Center
        modelLabel.TextTruncate = Enum.TextTruncate.AtEnd
        modelLabel.ZIndex = 504
        modelLabel.Parent = card

        -- Hover highlight
        card.MouseEnter:Connect(function()
            cardStroke.Color = Color3.fromRGB(100, 105, 120)
        end)
        card.MouseLeave:Connect(function()
            cardStroke.Color = Color3.fromRGB(45, 48, 58)
        end)

        -- Click to apply
        card.MouseButton1Click:Connect(function()
            if category == "Knives" then
                Config.KNIFE_MODEL = weaponName
                Config.KNIFE_SKIN = skinName
                if API and API.setKnife then
                    pcall(API.setKnife, weaponName, skinName)
                end
            else
                Config.SELECTED_WEAPON_TYPE = weaponName
                if API and API.setWeaponSkin then
                    pcall(API.setWeaponSkin, weaponName, skinName)
                end
            end
            safeNotify("Skinchanger", weaponName .. " - " .. skinName, "Success")
            closePopup()
        end)
    end

    UIManager.Popup = popup
end

function UIManager.init(config, arvn, api, database, knifeCatalog, gunCatalog, gloveCatalog, mainWindow)
    if UIManager.Initialized then return end
    UIManager.Initialized = true

    Config = config
    API = api
    Database = database
    KnifeCatalog = knifeCatalog
    GunCatalog = gunCatalog
    GloveCatalog = gloveCatalog
    ArvnRef = arvn

    local Window = mainWindow
    if not Window and arvn and arvn.CreateWindow then
        Window = arvn:CreateWindow({
            Title = "Skin Changer",
            Author = "@Discord_alvin6974.",
            Folder = "Bloxstrike_Skinchanger"
        })
    end

    if not Window then
        UIManager.Initialized = false
        return
    end

    local Main = nil
    pcall(function()
        Main = Window:Group("Skinchanger")
    end)
    if not Main then
        UIManager.Initialized = false
        return
    end

    local Tab = Main:Tab({Name = "Skins", Icon = "palette"})

    -- ==========================================
    -- KNIVES
    -- ==========================================
    local KnivesSection = Tab:Section("Knives")

    local knifeNames = {}
    if KnifeCatalog and KnifeCatalog.getNames then
        pcall(function() knifeNames = KnifeCatalog.getNames() end)
    end
    if #knifeNames == 0 and Database and Database.getKnifeList then
        pcall(function() knifeNames = Database.getKnifeList() end)
    end
    if #knifeNames == 0 then
        knifeNames = {"Butterfly Knife", "Karambit", "M9 Bayonet", "Skeleton", "Default"}
    end

    local selectedKnife = Config.KNIFE_MODEL or knifeNames[1]

    KnivesSection:Dropdown({
        Name = "Knife model",
        Values = knifeNames,
        Default = selectedKnife,
        Description = "Select a knife model",
        Callback = function(v)
            selectedKnife = v
            Config.KNIFE_MODEL = v
        end
    })

    -- Get actual skins for selected knife
    local knifeSkins = {"Special", "Random", "Stock"}
    if Database and Database.getKnifeSkinList then
        pcall(function()
            local list = Database.getKnifeSkinList(selectedKnife)
            if list and #list > 0 then knifeSkins = list end
        end)
    end

    KnivesSection:Dropdown({
        Name = "Knife skin",
        Values = knifeSkins,
        Default = Config.KNIFE_SKIN or "Special",
        Description = "Select a skin for the chosen knife",
        Callback = function(v)
            Config.KNIFE_SKIN = v
            if API and API.setKnife then
                pcall(API.setKnife, Config.KNIFE_MODEL or selectedKnife, v)
            end
            safeNotify("Skinchanger", (Config.KNIFE_MODEL or selectedKnife) .. " - " .. v, "Success")
        end
    })

    KnivesSection:Button({
        Name = "Browse knife skins (visual)",
        Callback = function()
            openPopup("Knives", Config.KNIFE_MODEL or selectedKnife)
        end
    })

    -- ==========================================
    -- WEAPONS
    -- ==========================================
    local GunsSection = Tab:Section({Name = "Guns", Side = "Right"})

    local gunNames = {}
    if GunCatalog and GunCatalog.getNames then
        pcall(function() gunNames = GunCatalog.getNames() end)
    end
    if #gunNames == 0 and Database and Database.getWeaponList then
        pcall(function() gunNames = Database.getWeaponList() end)
    end
    if #gunNames == 0 then
        gunNames = {"AK-47", "M4A1-S", "AWP", "Desert Eagle", "USP-S", "Glock-18"}
    end

    local selectedGun = Config.SELECTED_WEAPON_TYPE or gunNames[1]

    GunsSection:Dropdown({
        Name = "Weapon",
        Values = gunNames,
        Default = selectedGun,
        Description = "Select a weapon",
        Callback = function(v)
            selectedGun = v
            Config.SELECTED_WEAPON_TYPE = v
        end
    })

    -- Get actual skins for selected gun
    local gunSkins = {"Special", "Random", "Stock"}
    if Database and Database.getWeaponSkinList then
        pcall(function()
            local list = Database.getWeaponSkinList(selectedGun)
            if list and #list > 0 then gunSkins = list end
        end)
    end

    GunsSection:Dropdown({
        Name = "Weapon skin",
        Values = gunSkins,
        Default = "Special",
        Description = "Select a skin for the chosen weapon",
        Callback = function(v)
            if API and API.setWeaponSkin then
                pcall(API.setWeaponSkin, Config.SELECTED_WEAPON_TYPE or selectedGun, v)
            end
            safeNotify("Skinchanger", (Config.SELECTED_WEAPON_TYPE or selectedGun) .. " - " .. v, "Success")
        end
    })

    GunsSection:Button({
        Name = "Browse weapon skins (visual)",
        Callback = function()
            openPopup("Guns", Config.SELECTED_WEAPON_TYPE or selectedGun)
        end
    })

    -- ==========================================
    -- PRESETS
    -- ==========================================
    local PresetsSection = Tab:Section({Name = "Presets", Side = "Right"})

    local presets = {
        {Name = "All Special", Fn = function() return API.setAllSpecial end},
        {Name = "All Random", Fn = function() return API.setAllRandom end},
        {Name = "All Default", Fn = function() return API.setAllDefault end},
        {Name = "Reroll Random", Fn = function() return API.rerollRandom end},
    }

    for _, preset in ipairs(presets) do
        PresetsSection:Button({
            Name = preset.Name,
            Callback = function()
                local fn = preset.Fn()
                if fn then
                    pcall(fn)
                    safeNotify("Skinchanger", preset.Name .. " applied!", "Success")
                end
            end
        })
    end

    PresetsSection:Button({
        Name = "Refresh skins list",
        Callback = function()
            if API and API.refresh then
                pcall(API.refresh)
                safeNotify("Skinchanger", "Refreshed!", "Success")
            end
        end
    })

    UIManager.MainTab = Tab
end

function UIManager.cleanup()
    closePopup()
    cleanupViewports()
    UIManager.Initialized = false
    UIManager.MainTab = nil
end

function UIManager.show() end
function UIManager.hide() end
function UIManager.toggle() end

return UIManager