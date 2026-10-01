-- @Discord_alvin6974. / Bloxstrike Skinchanger / UIManager
-- Layout rebuilt to match the main cheat: controls are laid out as
-- toggles / dropdowns / buttons in groupboxes (list style) with a live 3D
-- preview rendered into a ViewportFrame beside them.
--
-- The 3D preview works because Linoria provides Library:Create / CreateLabel.
-- The preview is placed inside a label row that is enlarged to fit the
-- ViewportFrame (there is no AddUserFrame in this library).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Database = nil
local APIRef = nil
local Library_ = nil

local UIManager = {
    Initialized = false,
    Library = nil,
    Window = nil,
    Tabs = {}
}

local SkinsLib = nil
local function getSkinsLib()
    if SkinsLib then return SkinsLib end
    pcall(function()
        SkinsLib = require(ReplicatedStorage.Database.Components.Libraries.Skins)
    end)
    return SkinsLib
end

local function getDatabase()
    if Database then return Database end

    if type(readfile) == "function" then
        local paths = {
            "roblox_bloxstrike_SC/src/Database.lua",
            "Bloxstrike-Skinchanger/src/Database.lua",
            "src/Database.lua",
            "Database.lua"
        }
        for _, p in ipairs(paths) do
            local ok, content = pcall(readfile, p)
            if ok and content then
                local fn = loadstring(content)
                if fn then
                    Database = fn()
                    return Database
                end
            end
        end
    end

    pcall(function()
        local ok, content = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/alvin12127/roblox_bloxstrike_SC/main/src/Database.lua?t=" .. tostring(os.time()))
        end)
        if ok and content then
            local fn = loadstring(content)
            if fn then Database = fn() end
        end
    end)

    return Database
end

-- safe list fetchers -------------------------------------------------------

local function safeList(fn, fallback, arg)
    local list = nil
    if fn then
        pcall(function()
            if arg ~= nil then list = fn(arg) else list = fn() end
        end)
    end
    if type(list) ~= "table" or #list == 0 then
        return (type(fallback) == "table" and fallback) or {tostring(fallback)}
    end
    return list
end

local function knifeModels()
    if APIRef and APIRef.getKnifeList then
        local l = safeList(APIRef.getKnifeList, {"Default"})
        if #l > 0 then return l end
    end
    if Database and Database.getKnifeList then
        return safeList(Database.getKnifeList, {"Default"})
    end
    return {"Default"}
end

local function gunModels()
    if APIRef and APIRef.getWeaponList then
        local l = safeList(APIRef.getWeaponList, {"AK-47"})
        if #l > 0 then return l end
    end
    if Database and Database.getWeaponList then
        return safeList(Database.getWeaponList, {"AK-47"})
    end
    return {"AK-47"}
end

local function gloveModels()
    if APIRef and APIRef.getGloveList then
        local l = safeList(APIRef.getGloveList, {"Default"})
        if #l > 0 then return l end
    end
    if Database and Database.GloveModels then
        return Database.GloveModels
    end
    return {"Default"}
end

local function knifeSkins(model)
    if APIRef and APIRef.getKnifeSkins then
        local l = safeList(APIRef.getKnifeSkins, {"Stock"}, model)
        if #l > 0 then return l end
    end
    if Database and Database.getKnifeSkinList then
        return safeList(Database.getKnifeSkinList, {"Stock"}, model)
    end
    return {"Stock"}
end

local function gunSkins(weapon)
    if APIRef and APIRef.getWeaponSkins then
        local l = safeList(APIRef.getWeaponSkins, {"Stock"}, weapon)
        if #l > 0 then return l end
    end
    if Database and Database.getWeaponSkinList then
        return safeList(Database.getWeaponSkinList, {"Stock"}, weapon)
    end
    return {"Stock"}
end

local function gloveSkins(glove)
    if APIRef and APIRef.getGloveSkins then
        local l = safeList(APIRef.getGloveSkins, {"Stock"}, glove)
        if #l > 0 then return l end
    end
    if Database and Database.getGloveSkinList then
        return safeList(Database.getGloveSkinList, {"Stock"}, glove)
    end
    return {"Stock"}
end

-- 3D preview ---------------------------------------------------------------

local function renderPreview(vp, modelName, skinName)
    if not vp then return end

    pcall(function() vp:ClearAllChildren() end)

    local lib = getSkinsLib()
    if not lib then return end

    local target = modelName
    if target == "Default" then target = "CT Knife" end

    local model = nil
    local try = {skinName, "Stock", "Vanilla", "Fade", "Midas", "Lore"}
    for _, s in ipairs(try) do
        if s and s ~= "Random" and s ~= "Special" and s ~= "Default" then
            local ok, m = pcall(function()
                return lib.GetCharacterModel(target, s, 0.001)
            end)
            if ok and m then
                model = m
                break
            end
        end
    end

    if not model then
        pcall(function()
            model = lib.GetCharacterModel(target, "Stock", 0.001)
        end)
    end
    if not model then return end

    local clone = model
    pcall(function() clone = model:Clone() end)
    if not clone then return end

    pcall(function() clone.Parent = vp end)

    local cf, sz = clone:GetBoundingBox()
    local maxDim = math.max(sz.X, sz.Y, sz.Z, 0.5)
    if maxDim < 0.05 then maxDim = 2 end
    local dist = maxDim * 0.81
    if dist < 1 then dist = 3 end

    pcall(function()
        local cam = Instance.new("Camera")
        cam.FieldOfView = 50
        cam.CFrame = CFrame.new(
            cf.Position + Vector3.new(dist * 0.75, dist * 0.35, dist * 0.8),
            cf.Position
        )
        cam.Parent = vp
        vp.CurrentCamera = cam
        vp.LightColor = Color3.fromRGB(245, 245, 255)
        vp.Ambient = Color3.fromRGB(150, 150, 160)
        vp.LightDirection = Vector3.new(-1, -1.2, -1).Unit
    end)

    pcall(function()
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("BasePart") then
                d.LocalTransparencyModifier = 0
                d.CanCollide = false
                d.Anchored = true
            end
        end
    end)
end

-- Build the shared list-style UI + preview for a category -------------------

local function buildCategory(tab, opts)
    local Left = tab:AddLeftGroupbox(opts.Title)
    local Right = tab:AddRightGroupbox(opts.PreviewTitle or "Preview")

    -- Master toggle for the category
    if opts.SetEnabled then
        Left:AddToggle(opts.Key .. "_on", {
            Text = "Enable " .. opts.Title,
            Default = (opts.GetEnabled and opts.GetEnabled()) or true,
            Callback = function(v) opts.SetEnabled(v) end
        })
    end

    -- Model / skin selection state
    local modelList = opts.ModelList()
    local curModel = opts.GetModel() or modelList[1]

    local skinList = opts.SkinList(curModel)
    local curSkin = opts.GetSkin() or skinList[1]

    -- 3D preview: enlarge a label row so the ViewportFrame has room
    local vp = nil
    local prevLabel = nil

    pcall(function()
        prevLabel = Right:AddLabel(opts.PreviewTitle or "Preview")
    end)

    pcall(function()
        if prevLabel and prevLabel.Root then
            prevLabel.Root.Size = UDim2.new(1, 0, 0, 240)
        end
    end)

    pcall(function()
        local parent = (prevLabel and prevLabel.Root) or Right
        vp = Library_:Create('ViewportFrame', {
            Size = UDim2.new(1, -8, 1, -8),
            Position = UDim2.fromOffset(4, 4),
            BackgroundTransparency = 1,
            Parent = parent
        })
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = vp
    end)

    local function updatePreview()
        if vp then renderPreview(vp, curModel, curSkin) end
    end

    local skinDD = nil

    local modelDD = Left:AddDropdown(opts.Key .. "_model", {
        Values = modelList,
        Default = curModel,
        Text = opts.ModelLabel or "Model",
        Callback = function(v)
            curModel = v
            if opts.SetModel then opts.SetModel(v) end

            local sl = opts.SkinList(v)
            if skinDD and skinDD.SetValues then
                pcall(function() skinDD:SetValues(sl) end)
            end
            curSkin = sl[1]
            if opts.SetSkin then opts.SetSkin(curSkin) end
            updatePreview()
        end
    })

    skinDD = Left:AddDropdown(opts.Key .. "_skin", {
        Values = skinList,
        Default = curSkin,
        Text = opts.SkinLabel or "Skin",
        Callback = function(v)
            curSkin = v
            if opts.SetSkin then opts.SetSkin(v) end
            updatePreview()
        end
    })

    Left:AddButton({
        Text = "Apply " .. opts.Title,
        Func = function()
            if opts.Apply then
                pcall(opts.Apply, curModel, curSkin)
            end
            updatePreview()
            pcall(function()
                Library_:Notify("Applied " .. opts.Title .. ": "
                    .. tostring(curModel) .. " - " .. tostring(curSkin), 2)
            end)
        end,
        DoubleClick = false,
        Tooltip = "Applies the selected model and skin"
    })

    -- Quick preset buttons
    Left:AddButton({
        Text = "Random " .. opts.Title,
        Func = function()
            local sl = opts.SkinList(curModel)
            local pick = sl[math.random(1, #sl)]
            curSkin = pick
            if opts.SetSkin then opts.SetSkin(pick) end
            if opts.Apply then pcall(opts.Apply, curModel, pick) end
            updatePreview()
        end,
        DoubleClick = false,
        Tooltip = "Applies a random skin for the current model"
    })

    updatePreview()
end

-- init ----------------------------------------------------------------------

function UIManager.bindCatalogs(kc, gc)
    -- Catalogs are no longer used for rendering; kept for API compatibility
end

function UIManager.bindGloveCatalog(gc)
    -- kept for API compatibility
end

function UIManager.init(Config, Library, API, Db, unloadCallback)
    if type(API) == "function" and Db == nil then
        unloadCallback = API
        API = nil
        Db = nil
    elseif type(Db) == "function" and unloadCallback == nil then
        unloadCallback = Db
        Db = nil
    end

    Database = Db or Database or getDatabase()
    APIRef = API
    Library_ = Library

    if UIManager.Initialized then return end
    UIManager.Initialized = true
    UIManager.Library = Library

    -- Apply the shared theme so the skinchanger matches the main cheat
    if Config.UI_THEME and Library_ then
        for prop, val in pairs(Config.UI_THEME) do
            if Library_[prop] ~= nil then
                Library_[prop] = val
            end
        end
    end

    local w = Config.WINDOW_SIZE_X or 720
    local h = Config.WINDOW_SIZE_Y or 520
    if w < 620 then w = 720 end
    if h < 420 then h = 520 end

    local Window = Library_:CreateWindow({
        Title = "@Discord_alvin6974. / Bloxstrike / Skin Changer",
        Center = true,
        AutoShow = true,
        TabPadding = 6,
        MenuFadeTime = 0.2,
        Size = UDim2.fromOffset(w, h),
        ToggleKey = Config.TOGGLE_UI_KEY or Enum.KeyCode.Insert,
        UnloadKey = Config.UNLOAD_KEY or Enum.KeyCode.K,
        ResizeCallback = function(nw, nh)
            Config.WINDOW_SIZE_X = nw
            Config.WINDOW_SIZE_Y = nh
            if Config.queueSave then Config.queueSave() else Config.save() end
        end
    })
    UIManager.Window = Window

    local Tabs = {
        Knives = Window:AddTab("Knives"),
        Guns = Window:AddTab("Guns"),
        Gloves = Window:AddTab("Gloves"),
        Settings = Window:AddTab("Settings")
    }
    UIManager.Tabs = Tabs

    ---- Knives ----
    buildCategory(Tabs.Knives, {
        Key = "knife",
        Title = "Knife",
        PreviewTitle = "Knife Preview",
        ModelLabel = "Knife model",
        SkinLabel = "Knife skin",
        ModelList = knifeModels,
        SkinList = knifeSkins,
        GetModel = function() return Config.KNIFE_MODEL end,
        GetSkin = function() return Config.KNIFE_SKIN end,
        SetModel = function(v) Config.KNIFE_MODEL = v; Config.save() end,
        SetSkin = function(v) Config.KNIFE_SKIN = v; Config.save() end,
        Apply = function(m, s) if APIRef and APIRef.setKnife then APIRef.setKnife(m, s) end end,
        SetEnabled = function(v) if APIRef and APIRef.setKnifeEnabled then APIRef.setKnifeEnabled(v) end end,
        GetEnabled = function() return Config.KNIFE_SKINS_ENABLED ~= false end
    })

    ---- Guns ----
    buildCategory(Tabs.Guns, {
        Key = "gun",
        Title = "Weapon",
        PreviewTitle = "Weapon Preview",
        ModelLabel = "Weapon",
        SkinLabel = "Weapon skin",
        ModelList = gunModels,
        SkinList = gunSkins,
        GetModel = function() return Config.SELECTED_WEAPON_TYPE end,
        GetSkin = function()
            local v = Config.SELECTED_SKINS and Config.SELECTED_SKINS[Config.SELECTED_WEAPON_TYPE]
            if type(v) == "table" then return v.Skin end
            return v
        end,
        SetModel = function(v) Config.SELECTED_WEAPON_TYPE = v; Config.save() end,
        SetSkin = function(v)
            Config.SELECTED_SKINS = Config.SELECTED_SKINS or {}
            Config.SELECTED_SKINS[Config.SELECTED_WEAPON_TYPE] = v
            Config.save()
        end,
        Apply = function(m, s)
            if APIRef and APIRef.setWeaponSkin then APIRef.setWeaponSkin(m, s) end
        end,
        SetEnabled = function(v) if APIRef and APIRef.setWeaponEnabled then APIRef.setWeaponEnabled(v) end end,
        GetEnabled = function() return Config.WEAPON_SKINS_ENABLED ~= false end
    })

    ---- Gloves ----
    buildCategory(Tabs.Gloves, {
        Key = "glove",
        Title = "Gloves",
        PreviewTitle = "Glove Preview",
        ModelLabel = "Glove model",
        SkinLabel = "Glove skin",
        ModelList = gloveModels,
        SkinList = gloveSkins,
        GetModel = function() return Config.GLOVE_MODEL end,
        GetSkin = function() return Config.GLOVE_SKIN end,
        SetModel = function(v) Config.GLOVE_MODEL = v; Config.save() end,
        SetSkin = function(v) Config.GLOVE_SKIN = v; Config.save() end,
        Apply = function(m, s) if APIRef and APIRef.setGlove then APIRef.setGlove(m, s) end end,
        SetEnabled = function(v) if APIRef and APIRef.setGloveEnabled then APIRef.setGloveEnabled(v) end end,
        GetEnabled = function() return Config.GLOVE_SKINS_ENABLED ~= false end
    })

    ---- Settings ----
    local PresetGroup = Tabs.Settings:AddLeftGroupbox("Presets")
    local ResetGroup = Tabs.Settings:AddRightGroupbox("Reset & State")

    -- Master toggle
    ResetGroup:AddToggle("sc_master", {
        Text = "Skinchanger enabled",
        Default = Config.ENABLED ~= false,
        Callback = function(v)
            Config.ENABLED = v
            if APIRef and APIRef.setEnabled then APIRef.setEnabled(v) end
            Config.save()
        end
    })

    local presets = {
        {"All Special", function() if APIRef and APIRef.setAllSpecial then APIRef.setAllSpecial() end end},
        {"All Random", function() if APIRef and APIRef.setAllRandom then APIRef.setAllRandom() end end},
        {"All Default", function() if APIRef and APIRef.setAllDefault then APIRef.setAllDefault() end end},
        {"Reroll Random", function() if APIRef and APIRef.rerollRandom then APIRef.rerollRandom() end end},
    }

    for _, p in ipairs(presets) do
        PresetGroup:AddButton({
            Text = p[1],
            Func = function()
                pcall(p[2])
                if APIRef and APIRef.refresh then APIRef.refresh() end
                pcall(function() Library_:Notify(p[1] .. " applied", 2) end)
            end,
            DoubleClick = false,
            Tooltip = "Apply " .. p[1] .. " to the relevant slots"
        })
    end

    local resets = {
        {"Reset knife skins", function() if APIRef and APIRef.resetKnifeSkins then APIRef.resetKnifeSkins() end end},
        {"Reset weapon skins", function() if APIRef and APIRef.resetWeaponSkins then APIRef.resetWeaponSkins() end end},
        {"Reset glove skins", function() if APIRef and APIRef.resetGloveSkins then APIRef.resetGloveSkins() end end},
    }

    for _, r in ipairs(resets) do
        ResetGroup:AddButton({
            Text = r[1],
            Func = function()
                pcall(r[2])
                if APIRef and APIRef.refresh then APIRef.refresh() end
                pcall(function() Library_:Notify(r[1] .. " done", 2) end)
            end,
            DoubleClick = false,
            Tooltip = "Resets the selected slot back to stock"
        })
    end

    ResetGroup:AddButton({
        Text = "Refresh skins",
        Func = function()
            if APIRef and APIRef.refresh then APIRef.refresh() end
            pcall(function() Library_:Notify("Refreshed", 2) end)
        end,
        DoubleClick = false,
        Tooltip = "Re-applies the current configuration"
    })

    Tabs.Knives:ShowTab()
end

function UIManager.cleanup()
    if UIManager.Library and UIManager.Library.Unload then
        pcall(function() UIManager.Library:Unload() end)
    end

    UIManager.Initialized = false
    UIManager.Library = nil
    UIManager.Window = nil
    UIManager.Tabs = {}
end

return UIManager