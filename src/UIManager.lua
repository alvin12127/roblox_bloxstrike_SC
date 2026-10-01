-- @Discord_alvin6974. / Bloxstrike Skinchanger / UIManager
-- FINAL: visual catalog architecture.
--
-- The Knife / Gun / Glove catalogs build their own 3D viewports inside their
-- Linoria tabs. This is the arrangement that actually renders the previews -
-- the catalogs require Library:Create / CreateLabel and Tab.TabFrame, which
-- only Linoria provides (arvn does not). Do NOT replace this with a plain
-- toggle/dropdown layout: the 3D previews stop rendering if you do.
--
-- Customisation applied on top of the working catalog setup:
--   * window title / paths use @Discord_alvin6974. + roblox_bloxstrike_SC
--   * Gloves tab wired in (glove catalog)
--   * Settings tab: master toggle, presets, per-slot resets, refresh, unload
--   * theme taken from Config.UI_THEME so it matches the main cheat

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

    local Tabs = {
        Knife = Window:AddTab("Knives"),
        Guns = Window:AddTab("Guns"),
        Gloves = Window:AddTab("Gloves"),
        Settings = Window:AddTab("Settings")
    }
    UIManager.Tabs = Tabs

    -- Visual catalogs render the 3D cards (the only working arrangement)
    if KnifeCatalog and KnifeCatalog.init then
        KnifeCatalog.init(Tabs.Knife, Config, API, Library, Database)
    end
    if GunCatalog and GunCatalog.init then
        GunCatalog.init(Tabs.Guns, Config, API, Library, Database)
    end
    if GloveCatalog and GloveCatalog.init then
        GloveCatalog.init(Tabs.Gloves, Config, API, Library, Database)
    end

    -- Settings tab
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

    local function refreshAll()
        if API and API.refresh then API.refresh() end
        if KnifeCatalog and KnifeCatalog.refresh then pcall(KnifeCatalog.refresh) end
        if GunCatalog and GunCatalog.refresh then pcall(GunCatalog.refresh) end
        if GloveCatalog and GloveCatalog.refresh then pcall(GloveCatalog.refresh) end
    end

    if API then
        local presets = {
            {"All Special", API.setAllSpecial},
            {"All Random", API.setAllRandom},
            {"All Default", API.setAllDefault},
            {"Reroll Random", API.rerollRandom},
        }
        for _, p in ipairs(presets) do
            PresetGroup:AddButton({
                Text = p[1],
                Func = function()
                    if p[2] then pcall(p[2]) end
                    refreshAll()
                    Library:Notify(p[1] .. " applied", 2)
                end,
                DoubleClick = false,
                Tooltip = "Apply " .. p[1]
            })
        end

        local resets = {
            {"Reset knife skins", API.resetKnifeSkins},
            {"Reset weapon skins", API.resetWeaponSkins},
            {"Reset glove skins", API.resetGloveSkins},
        }
        for _, r in ipairs(resets) do
            StateGroup:AddButton({
                Text = r[1],
                Func = function()
                    if r[2] then pcall(r[2]) end
                    refreshAll()
                    Library:Notify(r[1] .. " done", 2)
                end,
                DoubleClick = false,
                Tooltip = "Resets the selected slot to stock"
            })
        end
    end

    StateGroup:AddButton({
        Text = "Refresh skins",
        Func = function()
            refreshAll()
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