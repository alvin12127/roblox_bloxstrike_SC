-- @Discord_alvin6974. / Bloxstrike Skinchanger / SkinsLib
--
-- Resolves the game's skin library module.
--
-- Ground truth from an instance dump of the live game:
--   ReplicatedStorage
--     Components
--       Common
--         Libraries
--           Roblox
--             Skins          <-- the real ModuleScript
--               Types
--             Collections
--               Types
--
-- The catalogs previously looked for
-- ReplicatedStorage.Database.Components.Libraries.Skins, which does NOT exist
-- in this game. The require failed, SkinsLib stayed nil, and every preview
-- viewport silently rendered empty.
--
-- The path can shift between game updates, so several known layouts are probed
-- and the first one that resolves wins. GetSkinInformation / GetCharacterModel
-- are used by the catalogs; whichever exist on the resolved module are exposed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinsLib = {}
SkinsLib.Resolved = nil

-- Known layouts, most specific first.
local CANDIDATE_PATHS = {
    { "Components", "Common", "Libraries", "Roblox", "Skins" },
    { "Components", "Common", "Libraries", "Skins" },
    { "Components", "Libraries", "Skins" },
    { "Common", "Libraries", "Roblox", "Skins" },
    { "Database", "Components", "Libraries", "Skins" },
    { "Components", "Common", "Libraries", "Roblox", "Skins", "Types" },
}

-- Walk a dotted/segmented path safely and return the instance if it exists.
local function resolvePath(segments)
    local node = ReplicatedStorage
    for _, name in ipairs(segments) do
        local child = nil
        pcall(function() child = node:FindFirstChild(name) end)
        if not child then return nil end
        node = child
    end
    return node
end

-- Require a candidate and accept it only when it exposes something we use.
local function tryModule(segments)
    local inst = resolvePath(segments)
    if not inst then return nil end

    local mod = nil
    pcall(function() mod = require(inst) end)
    if type(mod) ~= "table" then return nil end

    local hasPreviewApi = (type(mod.GetCharacterModel) == "function")
        or (type(mod.GetSkinModel) == "function")
        or (type(mod.GetModel) == "function")
    local hasInfoApi = (type(mod.GetSkinInformation) == "function")
        or (type(mod.GetSkinInfo) == "function")

    if (not hasPreviewApi) and (not hasInfoApi) then return nil end

    return mod
end

do
    for _, segments in ipairs(CANDIDATE_PATHS) do
        local mod = tryModule(segments)
        if mod then
            SkinsLib.Resolved = table.concat(segments, ".")
            break
        end
    end
end

--------------------------------------------------------------------
-- Normalised public surface used by the catalogs
--------------------------------------------------------------------
SkinsLib.Available = (SkinsLib.Resolved ~= nil)

-- The raw module, for callers that need a specific function name.
SkinsLib.Raw = nil
if SkinsLib.Resolved then
    pcall(function() SkinsLib.Raw = require(resolvePath(
        (SkinsLib.Resolved:gmatch("[^%.]+")))) end)
end

-- GetCharacterModel(modelName, skinName, scale) -> Model | nil
function SkinsLib.GetCharacterModel(modelName, skinName, scale)
    local raw = SkinsLib.Raw
    if not raw then return nil end

    local getter = raw.GetCharacterModel or raw.GetSkinModel or raw.GetModel
    if type(getter) ~= "function" then return nil end

    local ok, model = pcall(function()
        return getter(modelName, skinName, scale)
    end)
    if ok and model then return model end
    return nil
end

-- GetGloves(gloveName, skinName, scale) -> Model | nil
--
-- The glove catalog uses this name, which is the same call the game itself makes
-- when it builds a glove viewmodel. Resolved separately so the glove preview
-- keeps working even if the general model getter has a different signature.
function SkinsLib.GetGloves(gloveName, skinName, scale)
    local raw = SkinsLib.Raw
    if not raw then return nil end

    local getter = raw.GetGloves or raw.GetGloveModel or raw.GetCharacterModel
    if type(getter) ~= "function" then return nil end

    local ok, model = pcall(function()
        return getter(gloveName, skinName, scale)
    end)
    if ok and model then return model end
    return nil
end

-- GetSkinInformation(modelName, skinName) -> { rarity = ... } | nil
function SkinsLib.GetSkinInformation(modelName, skinName)
    local raw = SkinsLib.Raw
    if not raw then return nil end

    local getter = raw.GetSkinInformation or raw.GetSkinInfo or raw.GetInformation
    if type(getter) ~= "function" then return nil end

    local ok, info = pcall(function() return getter(modelName, skinName) end)
    if ok and type(info) == "table" then return info end
    return nil
end

return SkinsLib
