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

-- Require a candidate and accept it if it is a usable module table.
--
-- The acceptance test only checks that the module returned a table. Requiring a
-- specific function used to reject the real module, because this build exports
-- GetGloves / GetMagazine / GetKillTime / GetWeaponNameForFolder and none of the
-- names the old check looked for - so the resolver reported NOT resolved even
-- though it had found the right ModuleScript.
local function tryModule(segments)
    local inst = resolvePath(segments)
    if not inst then return nil end

    local mod = nil
    pcall(function() mod = require(inst) end)
    if type(mod) ~= "table" then return nil end

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

-- Getters in the game module that could plausibly return a weapon MODEL.
--
-- The live build does not export "GetCharacterModel" - the observed names are
-- GetWearNameForFloat, GetGloves, GetMagazine, GetkillTrackValue,
-- GetBadgeModel, GetItemIconImage, ObserveItemStockSchemas, GetCharmModel and a
-- truncated "GetWor...". Rather than hard-code a guess, every function whose name
-- looks model-ish is collected and TRIED at runtime: the caller passes the
-- arguments, and the first call that comes back with a real Model wins. That is
-- self-validating, so it does not matter which of them is the right one.
--
-- Excluded: anything that returns an image, and the schema observer, which would
-- otherwise be called with weapon arguments and could block or throw.
SkinsLib.RawGetters = {}

do
    local mod = SkinsLib.Module
    if mod then
        local names = {}
        for key, value in pairs(mod) do
            if type(key) == "string" then
                table.insert(names, key)
                if type(value) == "function" then
                    SkinsLib.Found[#SkinsLib.Found + 1] = key

                    local lower = key:lower()
                    local looksModel = lower:find("model", 1, true) ~= nil
                    local excluded = lower:find("icon", 1, true) ~= nil
                        or lower:find("image", 1, true) ~= nil
                        or lower:find("schema", 1, true) ~= nil
                        or lower:find("observe", 1, true) ~= nil
                        or lower:find("mag", 1, true) ~= nil
                    if looksModel and not excluded then
                        SkinsLib.RawGetters[#SkinsLib.RawGetters + 1] = key
                    end
                end
            end
        end
        table.sort(names)
        SkinsLib.Names = names
    end
end

-- Does the value look like a Model that actually has geometry in it?
local function usableModel(value)
    if type(value) ~= "table" then return false end

    local className = nil
    pcall(function() className = value.ClassName end)
    if className ~= "Model" then return false end

    local count = 0
    pcall(function()
        for _, d in ipairs(value:GetDescendants()) do
            local isPart = false
            pcall(function() isPart = d:IsA("BasePart") end)
            if isPart then count = count + 1 end
            if count > 0 then return end
        end
    end)

    return count > 0
end

SkinsLib.RawGetters = SkinsLib.RawGetters or {}

SkinsLib.Report = function()
    local head
    if SkinsLib.Resolved then
        head = "SkinsLib OK: " .. SkinsLib.Resolved
    else
        head = "SkinsLib NOT resolved (tried " .. #CANDIDATE_PATHS .. " paths)"
    end

    -- getchar used to report SkinsLib.GetCharacterModel, which is this file's own
    -- wrapper and therefore always non-nil - a diagnostic that could not fail is
    -- worse than none. It now counts the RAW module's model-ish getters.
    --
    -- The probe tries several weapons rather than one: "C4" happens to keep only
    -- textures in its wear folders, so probing with it alone reported probe=false
    -- for a build where knives and guns resolved perfectly fine. A single-name
    -- probe is a false negative waiting to happen.
    local probed = 0
    for _, name in ipairs({ "CT Knife", "T Knife", "Knife", "C4" }) do
        local model = nil
        pcall(function() model = SkinsLib.BuildModelFromDatabase(name, "Factory New") end)
        if usableModel(model) then
            probed = probed + 1
            break
        end
    end

    head = head .. "  rawmodel=" .. tostring(#SkinsLib.RawGetters)
        .. "  probe=" .. tostring(probed > 0)

    return head
end

-- Every exported function name, one per line. A single joined line got truncated
-- on screen and the cut fell in the middle of the one name that mattered.
SkinsLib.ReportFns = function()
    local lines = {}
    for i = 1, #SkinsLib.Found do
        lines[#lines + 1] = SkinsLib.Found[i]
    end
    return lines
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
-- GetCharacterModel(modelName, skinName, scale) -> Model | nil
--
-- There is no "GetCharacterModel" in the live build, so the old hard-coded list
-- of guesses never matched and every card fell through to the Database fallback -
-- which also returns nothing, because the wear folders hold only SurfaceAppearance
-- instances and no BaseParts at all.
--
-- Instead every model-ish getter the module actually exports is tried, in turn,
-- with the arguments this library is already given. The first one that returns a
-- real Model with geometry in it wins. Getter names are collected from the module
-- itself, so this works whatever the next update renames things to.
--
-- The scale argument is the third one because the observed naming convention is
-- float-based ("GetWearNameForFloat"), so the float is what these functions
-- expect in that position.
function SkinsLib.GetCharacterModel(modelName, skinName, scale)
    local raw = SkinsLib.Raw
    if raw then
        -- Exact names first, in case a build does ship one of them.
        for _, preferred in ipairs({ "GetCharacterModel", "GetSkinModel", "GetModel" }) do
            local getter = nil
            pcall(function() getter = raw[preferred] end)
            if type(getter) == "function" then
                local ok, model = pcall(function()
                    return getter(modelName, skinName, scale)
                end)
                if ok and usableModel(model) then return model end
            end
        end

        -- Then everything that looks model-ish, tried for real.
        for _, name in ipairs(SkinsLib.RawGetters) do
            local getter = nil
            pcall(function() getter = raw[name] end)
            if type(getter) == "function" then
                local ok, model = pcall(function()
                    return getter(modelName, skinName, scale)
                end)
                if ok and usableModel(model) then
                    SkinsLib.LastGetter = name
                    return model
                end
            end
        end
    end

    local fallback = SkinsLib.BuildModelFromDatabase(modelName, skinName)
    if fallback then return fallback end
    return nil
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
-- Per-weapon part cache.
--
-- The catalog calls this once per card (12 knives, 27 guns, 8 gloves), and each
-- call used to walk the whole weapon folder recursively. Re-walking the same
-- static tree dozens of times per render produced the frame stutter, so the part
-- list is gathered once per weapon and reused.
local partCache = {}

-- Depth cap so a pathological tree can never hang the render loop.
local MAX_DEPTH = 5

-- A weapon is made of many MeshParts. Cloning all of them for every card (47
-- cards across the three catalogs) in one frame is what caused the stutter, so a
-- single preview uses only the largest few parts - visually identical at card
-- size, a fraction of the cost.
local MAX_PARTS = 8

-- Which wear folders exist for a weapon, and the BaseParts inside the best one.
--
-- THE WEAR FOLDERS ARE NOT WHERE THE GEOMETRY IS. An instance dump of the live
-- game shows Database/<Weapon>/<Wear>/ containing nothing but SurfaceAppearance
-- instances - textures with no mesh and no BasePart to attach to. Searching there
-- is why probe=false: there is literally nothing to clone.
--
-- The geometry sits one level up, in a sibling folder under Database/<Weapon>/
-- that holds the weapon's own models. For the C4 that is:
--
--   Database/<Weapon>/C4/Weapon/{ Body, Details, Switch, SwitchFlip,
--                                  Screen, FlashingLight, ... }
--
-- so the search walks the weapon folder's subfolders and keeps the one with the
-- smallest bounding extent - the weapon is small and the character rig stored
-- beside it is not, so "smallest" identifies the gun rather than the soldier.
local function collectParts(node, out, depth)
    if depth > MAX_DEPTH or #out >= MAX_PARTS then return end
    pcall(function()
        for _, d in ipairs(node:GetChildren()) do
            if #out >= MAX_PARTS then return end
            local isPart = false
            pcall(function() isPart = d:IsA("BasePart") end)
            if isPart then
                table.insert(out, d)
            else
                collectParts(d, out, depth + 1)
            end
        end
    end)
end

local function partsExtent(parts)
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local n = 0
    for _, part in ipairs(parts) do
        local p, s = nil, nil
        pcall(function() p = part.Position end)
        pcall(function() s = part.Size end)
        if p and s then
            n = n + 1
            if p.X - s.X / 2 < minX then minX = p.X - s.X / 2 end
            if p.Y - s.Y / 2 < minY then minY = p.Y - s.Y / 2 end
            if p.Z - s.Z / 2 < minZ then minZ = p.Z - s.Z / 2 end
            if p.X + s.X / 2 > maxX then maxX = p.X + s.X / 2 end
            if p.Y + s.Y / 2 > maxY then maxY = p.Y + s.Y / 2 end
            if p.Z + s.Z / 2 > maxZ then maxZ = p.Z + s.Z / 2 end
        end
    end
    if n == 0 then return nil end
    return (maxX - minX) * (maxY - minY) * (maxZ - maxZ)
end

-- Which wear folders exist for a weapon, and the BaseParts inside the best one.
--
-- This game only stores a handful of wear folders (Factory New / Field-Tested /
-- Battle-Scarred), so a plain "prefer a known good wear" score is enough and no
-- per-skin-name matching is required.
local function getWeaponParts(weaponFolder)
    local best = nil
    local bestScore = -1

    -- WEAR FOLDERS FIRST. This is the order the previews worked in, because the
    -- original standalone window produced them with exactly this lookup - the C4
    -- folder happens to hold only SurfaceAppearance, which made it look like the
    -- wear folders were the wrong place, but knives, guns and gloves all keep
    -- their mesh there. Demoting wear to a fallback is what broke the cards.
    pcall(function()
        for _, wearFolder in ipairs(weaponFolder:GetChildren()) do
            if wearFolder:IsA("Folder") then
                local wearName = tostring(wearFolder.Name):lower()
                local score = (wearName == "factory new" or wearName == "vanilla"
                    or wearName == "stock") and 5 or 1

                local parts = {}
                collectParts(wearFolder, parts, 1)

                if #parts > 0 and score > bestScore then
                    best, bestScore = parts, score
                end
            end
        end
    end)

    if best then return best end

    -- Only then the geometry subfolders, for a weapon whose wear folders are
    -- texture-only (the C4 is one of them).
    local smallest = nil
    local smallestVolume = math.huge
    pcall(function()
        for _, folder in ipairs(weaponFolder:GetChildren()) do
            if folder:IsA("Folder") and (not WEAR_NAMES[tostring(folder.Name):lower()]) then
                local parts = {}
                collectParts(folder, parts, 1)
                if #parts > 0 then
                    local volume = partsExtent(parts)
                    if volume and volume < smallestVolume then
                        smallestVolume = volume
                        smallest = parts
                    end
                end
            end
        end
    end)
    if smallest then return smallest end

    -- Last resort: the whole weapon folder.
    pcall(function()
        local parts = {}
        collectParts(weaponFolder, parts, 0)
        if #parts > 0 then return parts end
    end)

    return nil
end

function SkinsLib.BuildModelFromDatabase(modelName, skinName)
    local database = ReplicatedStorage:FindFirstChild("Database")
    if not database or type(modelName) ~= "string" then return nil end

    local weaponFolder = nil
    pcall(function() weaponFolder = database:FindFirstChild(modelName) end)
    if not weaponFolder then return nil end

    local key = tostring(modelName):lower()

    if partCache[key] == nil then
        partCache[key] = getWeaponParts(weaponFolder) or false
    end

    local parts = partCache[key]
    if not parts or #parts == 0 then return nil end

    -- assemble the clones into a single Model the viewport can display
    local model = Instance.new("Model")
    model.Name = tostring(modelName)

    for i, part in ipairs(parts) do
        local clone = nil
        pcall(function() clone = part:Clone() end)
        if clone then
            pcall(function()
                clone.Anchored = true
                clone.CanCollide = false
                clone.CanTouch = false
                clone.CanQuery = false
                clone.Name = tostring(part.Name) .. "_" .. tostring(i)
                clone.Parent = model
            end)
        end
    end

    if #model:GetChildren() == 0 then
        pcall(function() model:Destroy() end)
        return nil
    end

    -- Recentre on the origin so the viewport camera framing puts the weapon in
    -- the middle of the card.
    pcall(function()
        local cf = model:GetBoundingBox()
        if cf and typeof(cf) == "CFrame" then
            local centre = cf.Position
            local offset = CFrame.new(-centre.X, -centre.Y, -centre.Z)
            for _, d in ipairs(model:GetChildren()) do
                if d:IsA("BasePart") then
                    d.CFrame = offset * d.CFrame
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
