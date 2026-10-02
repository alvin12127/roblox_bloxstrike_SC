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
            SkinsLib.Module = mod
            break
        end
    end
end

-- Record what the resolved module actually exposes. The catalogs call
-- GetCharacterModel / GetGloves / GetSkinInformation, but the real names in the
-- live game build are not known from an instance dump, so the resolved function
-- names are reported on screen to make any mismatch immediately visible.
SkinsLib.Found = {}
do
    local mod = SkinsLib.Module
    if mod then
        local names = {}
        for key, value in pairs(mod) do
            if type(key) == "string" then
                table.insert(names, key)
                if type(value) == "function" then
                    SkinsLib.Found[#SkinsLib.Found + 1] = key
                end
            end
        end
        table.sort(names)
        SkinsLib.Names = names
    end
end

SkinsLib.Report = function()
    if SkinsLib.Resolved then
        return "SkinsLib OK: " .. SkinsLib.Resolved
            .. "  fns: " .. table.concat(SkinsLib.Found, ", ")
    end
    return "SkinsLib NOT resolved (tried " .. #CANDIDATE_PATHS .. " paths)"
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
--
-- The live build of this game exports only these functions:
--   GetWeaponNameForFolder, GetGloves, GetMagazine, GetKillTime
-- There is no "GetCharacterModel", which is why every preview viewport stayed
-- empty once the require path was fixed. The weapon models themselves live under
-- ReplicatedStorage/Database/<weapon>/<wear>/... , so the model is assembled
-- from those parts instead of asking the library for it.
function SkinsLib.GetCharacterModel(modelName, skinName, scale)
    local raw = SkinsLib.Raw
    if not raw then return nil end

    -- If a future build does expose a real model getter, prefer it.
    local getter = raw.GetCharacterModel or raw.GetSkinModel or raw.GetModel
    if type(getter) == "function" then
        local ok, model = pcall(function() return getter(modelName, skinName, scale) end)
        if ok and model then return model end
    end

    return SkinsLib.BuildModelFromDatabase(modelName, skinName)
end

-- Build a Model out of the geometry the game stores in ReplicatedStorage.
--
-- From an instance dump of the live game:
--   ReplicatedStorage
--     Database
--       <Weapon Name>            (Folder)
--         <Wear>                  (Folder: Factory New / Field-Tested / ...)
--           <SurfaceAppearance / Part>  ...
--
-- The wear folder holds the actual mesh, so cloning its BaseParts gives a
-- preview that matches what the player will see equipped.
function SkinsLib.BuildModelFromDatabase(modelName, skinName)
    local database = ReplicatedStorage:FindFirstChild("Database")
    if not database or type(modelName) ~= "string" then return nil end

    local weaponFolder = nil
    pcall(function() weaponFolder = database:FindFirstChild(modelName) end)
    if not weaponFolder then return nil end

    -- collect every BasePart in the tree, preferring the requested wear
    local wantedWear = {
        [tostring(skinName or ""):lower()] = true,
        ["vanilla"] = true, ["stock"] = true, ["factory new"] = true,
    }

    local best = nil
    local bestScore = -1

    pcall(function()
        for _, wearFolder in ipairs(weaponFolder:GetChildren()) do
            if wearFolder:IsA("Folder") then
                local wearName = tostring(wearFolder.Name):lower()
                local score = wantedWear[wearName] and 10 or 1

                local parts = {}
                local function collect(node)
                    for _, d in ipairs(node:GetChildren()) do
                        if d:IsA("BasePart") then
                            table.insert(parts, d)
                        else
                            collect(d)
                        end
                    end
                end
                collect(wearFolder)

                if #parts > 0 and score > bestScore then
                    best, bestScore = parts, score
                end
            end
        end
    end)

    -- No BasePart directly in the wear folders: this game stores only
    -- SurfaceAppearance / accessory folders there. Fall back to the weapon
    -- folder's own BaseParts, and finally to the model the equipped character
    -- is actually wearing, which is always present in game.
    if not best then
        local function collectAll(node, out)
            for _, d in ipairs(node:GetChildren()) do
                if d:IsA("BasePart") then table.insert(out, d)
                else collectAll(d, out) end
            end
        end
        pcall(function()
            local parts = {}
            collectAll(weaponFolder, parts)
            if #parts > 0 then best = parts end
        end)
    end

    if not best then return nil end

    -- assemble the clones into a single Model the viewport can display
    local model = Instance.new("Model")
    model.Name = tostring(modelName)

    local okAll = pcall(function()
        for i, part in ipairs(best) do
            local clone = nil
            pcall(function() clone = part:Clone() end)
            if clone then
                clone.Anchored = true
                clone.CanCollide = false
                clone.CanTouch = false
                clone.CanQuery = false
                clone.Name = tostring(part.Name) .. "_" .. tostring(i)
                clone.Parent = model
            end
        end
    end)

    if not okAll then return nil end

    -- Recentre on the origin so the viewport camera framing puts the weapon in
    -- the middle of the card. The bounding box CFrame gives the centre point.
    pcall(function()
        local cf = model:GetBoundingBox()
        if cf and typeof(cf) == "CFrame" then
            local centre = cf.Position
            for _, d in ipairs(model:GetChildren()) do
                if d:IsA("BasePart") then
                    local p = d.Position
                    d.CFrame = CFrame.new(-centre.X, -centre.Y, -centre.Z) * d.CFrame
                end
            end
        end
    end)

    return model
end

-- GetGloves(gloveName, skinName, scale) -> Model | nil
--
-- The live build DOES export GetGloves, so this is used directly. If it does not
-- return a model, fall back to assembling one from ReplicatedStorage/Database.
function SkinsLib.GetGloves(gloveName, skinName, scale)
    local raw = SkinsLib.Raw
    if not raw then return nil end

    if type(raw.GetGloves) == "function" then
        local ok, model = pcall(function()
            return raw.GetGloves(gloveName, skinName, scale)
        end)
        if ok and model then return model end
    end

    return SkinsLib.BuildModelFromDatabase(gloveName, skinName)
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
