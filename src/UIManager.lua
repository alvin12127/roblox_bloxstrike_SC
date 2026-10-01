-- @Discord_alvin6974. / Bloxstrike Skinchanger / UIManager (integrated into main window)
local API = nil
local Config = nil
local Database = nil
local KnifeCatalog = nil
local GunCatalog = nil
local GloveCatalog = nil

local UIManager = {
    Initialized = false,
    MainTab = nil,
    ArvnRef = nil
}

local function safeNotify(title, content, kind)
    local arvn = UIManager.ArvnRef
    if arvn and arvn.Notify then
        pcall(arvn.Notify, arvn, {Title = title, Content = content, Kind = kind or "Info"})
    end
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
    UIManager.ArvnRef = arvn

    -- If mainWindow is nil, create a standalone window
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

    -- Knives section
    local KnivesSection = Tab:Section("Knives")

    local knifeNames = {}
    if KnifeCatalog and KnifeCatalog.getNames then
        local ok, list = pcall(function() return KnifeCatalog.getNames() end)
        if ok and list then knifeNames = list end
    end
    if #knifeNames == 0 then
        knifeNames = {"Butterfly Knife", "Karambit", "M9 Bayonet", "Skeleton", "Default"}
    end

    for _, knifeName in ipairs(knifeNames) do
        KnivesSection:Button({
            Name = knifeName,
            Callback = function()
                Config.KNIFE_MODEL = knifeName
                Config.KNIFE_SKIN = "Special"
                if API and API.setKnife then
                    pcall(API.setKnife, knifeName, "Special")
                end
                safeNotify("Skinchanger", "Equipped " .. knifeName, "Success")
            end
        })
    end

    -- Knife skins
    local knifeSkins = {"Special", "Fade", "Stock", "Vanilla"}
    for _, skinName in ipairs(knifeSkins) do
        KnivesSection:Button({
            Name = "  " .. skinName,
            Callback = function()
                Config.KNIFE_SKIN = skinName
                if API and API.setKnife then
                    pcall(API.setKnife, Config.KNIFE_MODEL or "Butterfly Knife", skinName)
                end
                safeNotify("Skinchanger", "Knife skin: " .. skinName, "Success")
            end
        })
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
        GunsSection:Button({
            Name = gunName,
            Callback = function()
                Config.SELECTED_WEAPON_TYPE = gunName
                safeNotify("Skinchanger", "Selected " .. gunName, "Success")
            end
        })
    end

    -- Gun skins
    local gunSkins = {"Special", "Fade", "Stock", "Vanilla"}
    for _, skinName in ipairs(gunSkins) do
        GunsSection:Button({
            Name = "  " .. skinName,
            Callback = function()
                if API and API.setWeaponSkin then
                    pcall(API.setWeaponSkin, Config.SELECTED_WEAPON_TYPE or "AK-47", skinName)
                end
                safeNotify("Skinchanger", "Weapon skin: " .. skinName, "Success")
            end
        })
    end

    -- Presets
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

    UIManager.MainTab = Tab
end

function UIManager.cleanup()
    UIManager.Initialized = false
    UIManager.MainTab = nil
end

-- These are no-ops since the skinchanger shares the main window
function UIManager.show() end
function UIManager.hide() end
function UIManager.toggle() end

return UIManager