-- @Discord_alvin6974. / Bloxstrike Skinchanger / UIManager
-- Visual catalog architecture: the Knife / Gun / Glove catalogs build their own
-- 3D viewports inside their Linoria tabs. This is the arrangement that renders
-- the previews correctly (the catalogs need Library:Create / CreateLabel and
-- Tab.TabFrame, which only Linoria provides).
--
-- Layout / naming is kept consistent with the main cheat, and the glove
-- catalog is wired in so gloves are configurable too.

local Database = nil
local KnifeCatalog = nil
local GunCatalog = nil
local GloveCatalog = nil

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
    local okHttp, content = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/alvin12127/roblox_bloxstrike_SC/main/src/Database.lua?t=" .. tostring(os.time()))
    end)
    if okHttp and content then
        local fn = loadstring(content)
        if fn then
            Database = fn()
            return Database
        end
    end
    return nil
end

local function getKnifeCatalog()
    if KnifeCatalog then return KnifeCatalog end
    if type(readfile) == "function" then
        local paths = {
            "roblox_bloxstrike_SC/src/KnifeCatalog.lua",
            "Bloxstrike-Skinchanger/src/KnifeCatalog.lua",
            "src/KnifeCatalog.lua",
            "KnifeCatalog.lua"
        }
        for _, p in ipairs(paths) do
            local ok, content = pcall(readfile, p)
            if ok and content then
                local fn = loadstring(content)
                if fn then
                    KnifeCatalog = fn()
                    return KnifeCatalog
                end
            end
        end
    end
    local okHttp, content = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/alvin12127/roblox_bloxstrike_SC/main/src/KnifeCatalog.lua?t=" .. tostring(os.time()))
    end)
    if okHttp and content then
        local fn = loadstring(content)
        if fn then
            KnifeCatalog = fn()
            return KnifeCatalog
        end
    end
    return nil
end

local function getGunCatalog()
    if GunCatalog then return GunCatalog end
    if type(readfile) == "function" then
        local paths = {
            "roblox_bloxstrike_SC/src/GunCatalog.lua",
            "Bloxstrike-Skinchanger/src/GunCatalog.lua",
            "src/GunCatalog.lua",
            "GunCatalog.lua"
        }
        for _, p in ipairs(paths) do
            local ok, content = pcall(readfile, p)
            if ok and content then
                local fn = loadstring(content)
                if fn then
                    GunCatalog = fn()
                    return GunCatalog
                end
            end
        end
    end
    local okHttp, content = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/alvin12127/roblox_bloxstrike_SC/main/src/GunCatalog.lua?t=" .. tostring(os.time()))
    end)
    if okHttp and content then
        local fn = loadstring(content)
        if fn then
            GunCatalog = fn()
            return GunCatalog
        end
    end
    return nil
end

local UIManager = {
    Initialized = false,
    Library = nil,
    Window = nil,
    Tabs = {}
}

function UIManager.bindCatalog(kc, gc)
    KnifeCatalog = kc
    if gc then GunCatalog = gc end
end

function UIManager.bindCatalogs(kc, gc)
    KnifeCatalog = kc
    GunCatalog = gc
end

function UIManager.bindGloveCatalog(gc)
    GloveCatalog = gc
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
    KnifeCatalog = KnifeCatalog or getKnifeCatalog()
    GunCatalog = GunCatalog or getGunCatalog()

    if UIManager.Initialized then return end
    UIManager.Initialized = true
    UIManager.Library = Library

    -- Shared theme so the skinchanger matches the main cheat
    if Config.UI_THEME then
        for prop, val in pairs(Config.UI_THEME) do
            if Library[prop] ~= nil then
                Library[prop] = val
            end
        end
    end

    local w = Config.WINDOW_SIZE_X or 720
    local h = Config.WINDOW_SIZE_Y or 520
    if w < 620 then w = 720 end
    if h < 420 then h = 520 end

    local Window = Library:CreateWindow({
        Title = "@Discord_alvin6974. / Bloxstrike / Skin Changer",
        Center = true,
        AutoShow = true,
        TabPadding = 6,
        MenuFadeTime = 0.2,
        Size = UDim2.fromOffset(w, h),
        MinWidth = 520,
        MinHeight = 320,
        ToggleKey = Config.TOGGLE_UI_KEY or Enum.KeyCode.Insert,
        UnloadKey = Config.UNLOAD_KEY or Enum.KeyCode.K,
        ResizeCallback = function(nw, nh)
            Config.WINDOW_SIZE_X = nw
            Config.WINDOW_SIZE_Y = nh
            if Config.queueSave then Config.queueSave() else Config.save() end
        end
    })
    UIManager.Window = Window

    -- Tabs: Knives / Guns / Gloves / Settings
    local Tabs = {
        Knife = Window:AddTab("Knives"),
        Guns = Window:AddTab("Guns"),
        Gloves = Window:AddTab("Gloves"),
        Settings = Window:AddTab("Settings")
    }
    UIManager.Tabs = Tabs

    -- 1. Visual knife catalog (3D cards)
    if KnifeCatalog and KnifeCatalog.init then
        KnifeCatalog.init(Tabs.Knife, Config, API, Library, Database)
    end

    -- 2. Visual gun catalog (3D cards)
    if GunCatalog and GunCatalog.init then
        GunCatalog.init(Tabs.Guns, Config, API, Library, Database)
    end

    -- 3. Visual glove catalog (3D cards)
    if GloveCatalog and GloveCatalog.init then
        GloveCatalog.init(Tabs.Gloves, Config, API, Library, Database)
    end

    -- 4. Settings tab
    local PresetGroup = Tabs.Settings:AddLeftGroupbox("Presets")
    local StateGroup = Tabs.Settings:AddRightGroupbox("State & Reset")

    StateGroup:AddToggle("sc_master", {
        Text = "Skinchanger enabled",
        Default = Config.ENABLED ~= false,
        Callback = function(v)
            Config.ENABLED = v
            if API and API.setEnabled then API.setEnabled(v) end
            Config.save()
        end
    })

    local function applyPreset(name, fn)
        PresetGroup:AddButton({
            Text = name,
            Func = function()
                if fn then pcall(fn) end
                if API and API.refresh then API.refresh() end
                if KnifeCatalog and KnifeCatalog.refresh then pcall(KnifeCatalog.refresh) end
                if GunCatalog and GunCatalog.refresh then pcall(GunCatalog.refresh) end
                if GloveCatalog and GloveCatalog.refresh then pcall(GloveCatalog.refresh) end
                Library:Notify(name .. " applied", 2)
            end,
            DoubleClick = false,
            Tooltip = "Apply " .. name .. " to the relevant slots"
        })
    end

    if API then
        applyPreset("All Special", API.setAllSpecial)
        applyPreset("All Random", API.setAllRandom)
        applyPreset("All Default", API.setAllDefault)
        applyPreset("Reroll Random", API.rerollRandom)
    end

    local function addReset(text, fn, catalog)
        StateGroup:AddButton({
            Text = text,
            Func = function()
                if fn then pcall(fn) end
                if API and API.refresh then API.refresh() end
                if catalog and catalog.refresh then pcall(catalog.refresh) end
                Library:Notify(text .. " done", 2)
            end,
            DoubleClick = false,
            Tooltip = "Resets the selected slot back to stock"
        })
    end

    if API then
        addReset("Reset knife skins", API.resetKnifeSkins, KnifeCatalog)
        addReset("Reset weapon skins", API.resetWeaponSkins, GunCatalog)
        addReset("Reset glove skins", API.resetGloveSkins, GloveCatalog)
    end

    StateGroup:AddButton({
        Text = "Refresh skins",
        Func = function()
            if API and API.refresh then API.refresh() end
            Library:Notify("Refreshed", 2)
        end,
        DoubleClick = false,
        Tooltip = "Re-applies the current configuration"
    })

    StateGroup:AddButton({
        Text = "Unload Skinchanger",
        Func = function()
            if unloadCallback then
                unloadCallback()
            elseif Library and Library.Unload then
                Library:Unload()
            end
        end,
        DoubleClick = true,
        Tooltip = "Double-click to close the skinchanger"
    })

    Tabs.Knife:ShowTab()
end

function UIManager.cleanup()
    if KnifeCatalog and KnifeCatalog.cleanup then
        pcall(KnifeCatalog.cleanup)
    end
    if GunCatalog and GunCatalog.cleanup then
        pcall(GunCatalog.cleanup)
    end
    if GloveCatalog and GloveCatalog.cleanup then
        pcall(GloveCatalog.cleanup)
    end
    if UIManager.Library and UIManager.Library.Unload then
        pcall(function() UIManager.Library:Unload() end)
    end
    UIManager.Initialized = false
    UIManager.Library = nil
    UIManager.Window = nil
    UIManager.Tabs = {}
end

return UIManager