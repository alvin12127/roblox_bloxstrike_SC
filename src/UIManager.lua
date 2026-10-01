-- @Discord_alvin6974. / Bloxstrike Skinchanger / UIManager (arvn-based)
local Arvn = nil
local API = nil
local Config = nil
local Database = nil
local KnifeCatalog = nil
local GunCatalog = nil
local GloveCatalog = nil

local UIManager = {
    Initialized = false,
    Window = nil
}

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

    -- knives tab
    local KnivesTab = Main:Tab({Name = "Knives", Icon = "sword"})
    local KnivesSection = KnivesTab:Section("Knife Selection")

    local knifeNames = {}
    if KnifeCatalog and KnifeCatalog.getNames then
        knifeNames = KnifeCatalog.getNames()
    end

    KnivesSection:Dropdown({
        Name = "Knife Model",
        Values = knifeNames,
        Default = Config.KNIFE_MODEL or "Butterfly Knife",
        Callback = function(value)
            Config.KNIFE_MODEL = value
            if API and API.setKnife then
                API.setKnife(value, Config.KNIFE_SKIN or "Special")
            end
        end
    })

    local knifeSkins = {}
    if KnifeCatalog and KnifeCatalog.getSkins then
        knifeSkins = KnifeCatalog.getSkins(Config.KNIFE_MODEL or "Butterfly Knife")
    end

    KnivesSection:Dropdown({
        Name = "Knife Skin",
        Values = knifeSkins,
        Default = Config.KNIFE_SKIN or "Special",
        Callback = function(value)
            Config.KNIFE_SKIN = value
            if API and API.setKnife then
                API.setKnife(Config.KNIFE_MODEL or "Butterfly Knife", value)
            end
        end
    })

    KnivesSection:Button({
        Name = "Equip Knife",
        Callback = function()
            if API and API.setKnife then
                API.setKnife(Config.KNIFE_MODEL or "Butterfly Knife", Config.KNIFE_SKIN or "Special")
                Arvn:Notify({Title = "Skinchanger", Content = "Knife equipped!", Kind = "Success"})
            end
        end
    })

    -- weapons tab
    local WeaponsTab = Main:Tab({Name = "Weapons", Icon = "crosshair"})
    local WeaponsSection = WeaponsTab:Section("Weapon Skins")

    local gunNames = {}
    if GunCatalog and GunCatalog.getNames then
        gunNames = GunCatalog.getNames()
    end

    WeaponsSection:Dropdown({
        Name = "Weapon",
        Values = gunNames,
        Default = Config.SELECTED_WEAPON_TYPE or "AK-47",
        Callback = function(value)
            Config.SELECTED_WEAPON_TYPE = value
        end
    })

    local gunSkins = {}
    if GunCatalog and GunCatalog.getSkins then
        gunSkins = GunCatalog.getSkins(Config.SELECTED_WEAPON_TYPE or "AK-47")
    end

    WeaponsSection:Dropdown({
        Name = "Weapon Skin",
        Values = gunSkins,
        Default = "Special",
        Callback = function(value)
            if API and API.setWeaponSkin then
                API.setWeaponSkin(Config.SELECTED_WEAPON_TYPE or "AK-47", value)
            end
        end
    })

    WeaponsSection:Button({
        Name = "Apply Skin",
        Callback = function()
            if API and API.setWeaponSkin then
                API.setWeaponSkin(Config.SELECTED_WEAPON_TYPE or "AK-47", "Special")
                Arvn:Notify({Title = "Skinchanger", Content = "Weapon skin applied!", Kind = "Success"})
            end
        end
    })

    -- presets tab
    local PresetsTab = Main:Tab({Name = "Presets", Icon = "sparkles"})
    local PresetsSection = PresetsTab:Section("Quick Presets")

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

    -- gloves tab
    local GlovesTab = Main:Tab({Name = "Gloves", Icon = "hand"})
    local GlovesSection = GlovesTab:Section("Glove Selection")

    local gloveNames = {}
    if GloveCatalog and GloveCatalog.getNames then
        gloveNames = GloveCatalog.getNames()
    end

    GlovesSection:Dropdown({
        Name = "Glove Model",
        Values = gloveNames,
        Default = "Default",
        Callback = function(value)
            if API and API.setGlove then
                API.setGlove(value)
            end
        end
    })

    -- settings tab
    local SettingsTab = Main:Tab({Name = "Settings", Icon = "settings"})
    local SettingsSection = SettingsTab:Section("Config")

    SettingsSection:Button({
        Name = "Refresh",
        Callback = function()
            if API and API.refresh then
                API.refresh()
                Arvn:Notify({Title = "Skinchanger", Content = "Refreshed!", Kind = "Success"})
            end
        end
    })

    SettingsSection:Button({
        Name = "Save Config",
        Callback = function()
            if Config and Config.save then
                Config.save()
                Arvn:Notify({Title = "Skinchanger", Content = "Config saved!", Kind = "Success"})
            end
        end
    })

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
    -- Hide the menu instead of unloading the entire UI library
    if Arvn and Arvn.Toggled then
        pcall(Arvn.Toggle, Arvn)
    end
    UIManager.Initialized = false
    UIManager.Window = nil
end

return UIManager