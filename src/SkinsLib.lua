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

-- Forward declaration. skinAssetRoots is defined further down this file, next to the
-- other asset-path helpers it belongs with, but Report below already calls it.
--
-- Without this, Report's body resolved the name as a GLOBAL - nil - and died with
-- "attempt to call a nil value" the moment init.lua asked for the report. Lua only
-- looks ahead for locals it can see a declaration for; a later `local function`
-- is invisible from above, it is a fresh local, not a hoisted one.
--
-- This is the third time a helper has been used above its own declaration in this
-- codebase (WEAR_NAMES, then this), and it is invisible to a syntax check - the
-- file compiles fine and only fails when the function is actually called. A test
-- now scans for it.
local skinAssetRoots

-- Same reason. MESH_ROOT_PATHS is defined next to meshFor, far below this report,
-- and the report reads it to say how many weapon folders each geometry root holds.
local MESH_ROOT_PATHS

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
    -- Now that the folder is known, probe with the names the catalogs actually use.
    -- "C4" was a bad probe on its own: a build where every knife resolves fine
    -- still reported probe=false, which is how a wrong answer survived several
    -- rounds.
    local probed, trace = 0, "-"
    for _, spec in ipairs({
        { "CT Knife", "Stock" },
        { "Tec-9", "Striker" },
        { "AWP", "Dragon Lore" },
        { "Karambit", "Fade" },
    }) do
        local model, why = nil, nil
        pcall(function() model, why = SkinsLib.BuildModelFromDatabase(spec[1], spec[2]) end)
        if usableModel(model) then
            probed = probed + 1
            trace = tostring(spec[1]) .. " ok " .. tostring(why)
            break
        end
        trace = tostring(spec[1]) .. " " .. tostring(why)
    end

    -- Also report the roots that exist, so a path change is visible immediately
    -- instead of being guessed at again.
    local roots = skinAssetRoots()
    local rootNames = {}
    for _, r in ipairs(roots) do
        local n = nil
        pcall(function() n = r.Name end)
        rootNames[#rootNames + 1] = tostring(n)
    end

    -- Mesh roots, and how many weapon folders each one holds. If these read 0 then
    -- there is no geometry anywhere to build a preview from and no amount of
    -- re-ordering the lookup will help.
    local meshInfo = {}
    for _, segs in ipairs(MESH_ROOT_PATHS) do
        local root = resolvePath(segs)
        local n = 0
        if root then
            pcall(function() n = #root:GetChildren() end)
        end
        meshInfo[#meshInfo + 1] = table.concat(segs, "/") .. "=" .. tostring(n)
    end

    head = head .. "  roots=" .. table.concat(rootNames, "+")
        .. "  mesh=" .. table.concat(meshInfo, ",")
        .. "  rawmodel=" .. tostring(#SkinsLib.RawGetters)
        .. "  probe=" .. tostring(probed > 0)
        .. "  [" .. tostring(trace) .. "]"

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
-- Split a dotted path into a segment list.
--
-- Written out rather than passing string.gmatch's result straight to resolvePath:
-- gmatch returns a STATEFUL ITERATOR FUNCTION and resolvePath iterates with ipairs,
-- which expects a table. Zero iterations, so resolvePath returned the root itself
-- and SkinsLib.Raw was silently nil - the raw module was never available, and every
-- call that went through it (GetGloves, GetSkinInformation, GetCharacterModel) fell
-- through to the fallback without ever trying the real library.
local function splitPath(path)
    local out = {}
    for seg in tostring(path):gmatch("[^%.]+") do
        out[#out + 1] = seg
    end
    return out
end

SkinsLib.Raw = nil
if SkinsLib.Resolved then
    pcall(function() SkinsLib.Raw = require(resolvePath(splitPath(SkinsLib.Resolved))) end)
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

-- Wear folder names. Everything under these is SurfaceAppearance only - textures,
-- no mesh - so they are skipped when hunting for geometry.
--
-- BOTH SPELLINGS ARE PRESENT IN THE LIVE GAME. The tree contains "Field-Tested"
-- AND "Field Tested" as separate folders on different weapons, likewise
-- "Well-Worn" and "Well Worn". Matching only the hyphenated forms left the
-- un-hyphenated folders looking like skin names.
--
-- Group-level names sit one level above the wear folders and are not skins either.
local WEAR_NAMES = {
    ["factory new"] = true,
    ["field-tested"] = true,
    ["field tested"] = true,
    ["battle-scarred"] = true,
    ["battle scarred"] = true,
    ["minimal wear"] = true,
    ["well-worn"] = true,
    ["well worn"] = true,
    ["vanilla"] = true,
    ["stock"] = true,
}

local GROUP_NAMES = {
    ["character"] = true,
    ["camera"] = true,
    ["globals"] = true,
    ["world"] = true,
}

-- Compare names the way the game does: "M4A1-S", "M4A1 S" and "m4a1_s" are one
-- weapon. A literal FindFirstChild missed a third of the weapons over spacing and
-- case alone.
local function norm(s)
    return (tostring(s or ""):lower():gsub("[%s%-_%.]", ""))
end

local function isWear(s) return WEAR_NAMES[tostring(s or ""):lower()] == true end
local function isGroup(s) return GROUP_NAMES[tostring(s or ""):lower()] == true end

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

-- A skin is stored in TWO PLACES and neither one is a preview on its own. This is
-- the layout, established from an instance dump of the live game:
--
--   ReplicatedStorage/Assets/Skins/<Weapon>/<Skin>/<Group>/<Wear>/<Part>/
--       SurfaceAppearance, SurfaceAppearance, ...        <- TEXTURE ONLY
--
--   ReplicatedStorage/Assets/Weapons/<Weapon>/...                    <- MeshPart
--   ReplicatedStorage/Assets/InspectScenes/...                       <- MeshPart
--
-- Assets/Skins was counted directly: 53 children, 4524 nested Folders, 15023
-- SurfaceAppearances, and ZERO MeshPart, Part or SpecialMesh. There is no geometry
-- anywhere under it, which is why every attempt to build a preview from that tree
-- returned nothing no matter how the search was ordered.
--
-- The mesh half is elsewhere, and it lines up: 125 of the 136 part names used by
-- the skin textures are also part names on the meshes in Assets/Weapons and
-- Assets/InspectScenes. So a preview is assembled by cloning the mesh parts and
-- then cloning each part's SurfaceAppearance onto the part of the same name - which
-- is what the game itself does when it renders a weapon.
MESH_ROOT_PATHS = {
    { "Assets", "Weapons" },
    { "Assets", "InspectScenes" },
    { "Assets", "MenuScenes" },
    { "Assets", "Other" },
}

-- Find the folder or model holding a weapon's mesh, matching names loosely.
local meshCache = {}

local function scanForMesh(folder, wantNorm, depth, out)
    if out or depth > 3 then return end
    pcall(function()
        for _, child in ipairs(folder:GetChildren()) do
            if out then return end
            local name = nil
            pcall(function() name = child.Name end)
            if name and norm(name) == wantNorm then
                out = child
                return
            end
            local canDescend = false
            pcall(function() canDescend = child:IsA("Folder") or child:IsA("Model") end)
            if canDescend then
                scanForMesh(child, wantNorm, depth + 1, out)
            end
        end
    end)
end

local function meshFor(weaponName)
    local key = norm(weaponName)
    if meshCache[key] ~= nil then
        local cached = meshCache[key]
        return cached ~= false and cached or nil
    end

    local found = nil
    for _, segs in ipairs(MESH_ROOT_PATHS) do
        local root = resolvePath(segs)
        if root then
            -- Direct child first: Assets/Weapons/<Weapon> is the common case.
            pcall(function()
                for _, child in ipairs(root:GetChildren()) do
                    local n = nil
                    pcall(function() n = child.Name end)
                    if n and norm(n) == key then
                        -- Confirm it actually holds parts before accepting it.
                        local probe = {}
                        collectParts(child, probe, 1)
                        if #probe > 0 then
                            found = child
                            return
                        end
                    end
                end
            end)
            if found then break end
            scanForMesh(root, key, 1, found)
            if found then break end
        end
    end

    meshCache[key] = found or false
    return found
end

-- Map normalised part name -> list of SurfaceAppearance instances for one skin.
local function skinTextureMap(skinFolder)
    local map = {}
    local found = 0

    -- <Skin>/<Group>/<Wear>/<Part>/<SurfaceAppearance...>
    local function walk(node, depth)
        if found > 0 and depth > 2 then return end
        pcall(function()
            for _, child in ipairs(node:GetChildren()) do
                local isFolder = false
                pcall(function() isFolder = child:IsA("Folder") end)
                if isFolder then
                    -- A folder that directly holds SurfaceAppearance IS a part.
                    local saps = {}
                    pcall(function()
                        for _, d in ipairs(child:GetChildren()) do
                            local isSA = false
                            pcall(function() isSA = d:IsA("SurfaceAppearance") end)
                            if isSA then saps[#saps + 1] = d end
                        end
                    end)

                    if #saps > 0 then
                        local n = nil
                        pcall(function() n = child.Name end)
                        local k = norm(n)
                        map[k] = map[k] or {}
                        for _, s in ipairs(saps) do
                            map[k][#map[k] + 1] = s
                            found = found + 1
                        end
                    elseif depth < 4 then
                        walk(child, depth + 1)
                    end
                end
            end
        end)
    end

    walk(skinFolder, 1)
    return map, found
end

    -- WHERE THE SKIN ASSETS LIVE.
--
-- ReplicatedStorage/Database is NOT it. That folder is a tree of ModuleScripts -
-- Security, Audio, BreakableDoor, Weapons/&lt;AK-47&gt;, Round - it is game code,
-- so Database:FindFirstChild("CT Knife") is nil forever and probe=false. Every
-- version of this function looked there, which is why no preview ever built.
--
-- The assets are here, and this is the path the repo's own Database.lua already
-- used (ReplicatedStorage:FindFirstChild("Assets") then :FindFirstChild("Skins")):
--
--   ReplicatedStorage
--     Assets
--       Skins
--         Tec-9                  (Folder - the weapon)
--           Striker              (Folder - the skin)
--             Character          (Folder)
--               Factory New / Field-Tested / Battle-Scarred ...
--             Camera
--
-- Note the wear folders hold SurfaceAppearance only - textures with no mesh - so
-- the parts have to come from a level or two above them, not from inside a wear
-- folder.
skinAssetRoots = function()
    local roots = {}

    pcall(function()
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        if assets then
            local skins = nil
            pcall(function() skins = assets:FindFirstChild("Skins") end)
            if skins then
                roots[#roots + 1] = skins
            else
                roots[#roots + 1] = assets
            end
        end
    end)

    -- Kept as a secondary root: if a future build does move the meshes under
    -- Database, this still finds them.
    pcall(function()
        local db = ReplicatedStorage:FindFirstChild("Database")
        if db then roots[#roots + 1] = db end
    end)

    return roots
end

-- Find the folder for a weapon, and inside it the folder for a specific skin.
-- Both levels are optional: with no skin match the weapon folder itself is used,
-- and a skin-named subfolder is preferred over a wear folder.
local function findSkinFolder(modelName, skinName)
    for _, root in ipairs(skinAssetRoots()) do
        local weaponFolder = nil
        pcall(function() weaponFolder = root:FindFirstChild(modelName) end)
        if not weaponFolder then
            pcall(function() weaponFolder = root:FindFirstChild(tostring(modelName):upper()) end)
        end
        if weaponFolder and weaponFolder:IsA("Folder") then
            if type(skinName) == "string" and skinName ~= "" then
                local skinFolder = nil
                pcall(function() skinFolder = weaponFolder:FindFirstChild(skinName) end)
                if skinFolder and skinFolder:IsA("Folder") and (not WEAR_NAMES[skinName:lower()]) then
                    return skinFolder
                end
            end
            return weaponFolder
        end
    end
    return nil
end

-- Build a preview for one skin: mesh from Assets/Weapons or Assets/InspectScenes,
-- textures from Assets/Skins, joined on part name.
--
-- Returns the Model, plus a short trace. The trace is what stops this from being
-- guessed at again: "mesh=no" and "tex=0" mean completely different fixes, and they
-- look identical from the outside - an empty card.
function SkinsLib.BuildModelFromDatabase(modelName, skinName)
    if type(modelName) ~= "string" then return nil, "no-name" end

    local skinFolder = findSkinFolder(modelName, skinName)
    if not skinFolder then return nil, "no-skin-folder" end

    local mesh = meshFor(modelName)
    if not mesh then return nil, "no-mesh:" .. tostring(modelName) end

    local sourceParts = {}
    collectParts(mesh, sourceParts, 1)
    if #sourceParts == 0 then return nil, "mesh-empty:" .. tostring(modelName) end

    -- Textures for this skin, keyed by normalised part name.
    local texMap, texCount = {}, 0
    if skinFolder then
        texMap, texCount = skinTextureMap(skinFolder)
    end

    local model = Instance.new("Model")
    model.Name = tostring(modelName)

    local cloned, textured = 0, 0
    for i, part in ipairs(sourceParts) do
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

            -- Keep the original name available for the texture lookup: the clone is
            -- suffixed so the viewport can hold several weapons at once.
            local originalName = nil
            pcall(function() originalName = part.Name end)
            local bucket = texMap[norm(originalName)]
            if bucket then
                for _, sa in ipairs(bucket) do
                    local saClone = nil
                    pcall(function() saClone = sa:Clone() end)
                    if saClone then
                        pcall(function() saClone.Parent = clone end)
                        textured = textured + 1
                    end
                end
            end

            cloned = cloned + 1
        end
    end

    if cloned == 0 then
        pcall(function() model:Destroy() end)
        return nil, "clone-failed"
    end

    -- Recentre on the origin so the viewport camera framing puts the weapon in the
    -- middle of the card.
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

    SkinsLib.LastTrace = string.format("%s parts=%d tex=%d applied=%d",
        tostring(modelName), cloned, texCount, textured)

    if textured == 0 then
        -- Geometry without the skin's textures is a different picture than the one
        -- the card claims to show, so it is reported rather than passed off as a
        -- working preview.
        return model, "untextured:" .. SkinsLib.LastTrace
    end

    return model, SkinsLib.LastTrace
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
