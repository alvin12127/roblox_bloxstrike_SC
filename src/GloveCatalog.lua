-- @Discord_alvin6974. / Bloxstrike Skinchanger / GloveCatalog
-- Visual glove catalog, built with the same layout language as the knife and gun
-- catalogs so the tab feels like part of the same hub:
--   Left-Click  : equip the glove model
--   Right-Click : open the skin list for that model
-- Gloves are rendered through SkinsLib.GetGloves, which is the same call the game
-- itself uses when it builds the glove model.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- SkinsLib is injected by init.lua. The hardcoded path these catalogs used to
-- require does not exist in this game, so every preview viewport stayed empty.
local SkinsLib = (_G.__bloxstrikeSkinsLib) or nil

local GloveCatalog = {
    Initialized = false,
    CurrentView = "Models",
    ActiveGlove = nil,
    ViewportCleanups = {}
}

local CARD_WIDTH = 136
local CARD_HEIGHT = 148

local function cleanupViewports()
    for _, fn in ipairs(GloveCatalog.ViewportCleanups) do
        pcall(fn)
    end
    GloveCatalog.ViewportCleanups = {}
end

-- A ViewportFrame no longer renders instances parented directly to it: the model
-- has to live in a WorldModel assigned to the frame's WorldModel property.
--
-- This is what broke when the catalogs moved out of the standalone Linoria
-- window and into the arvn tab. The previews were building correctly the whole
-- time - they were simply being parented somewhere that stopped displaying them,
-- so every card came up as an empty box. Nothing about the UI move was wrong; the
-- parenting was always one API generation behind.
local function attachPreviewModel(viewportFrame, clone)
    local world = nil
    pcall(function() world = Instance.new("WorldModel") end)

    if not world then
        -- Very old client: direct parenting is all it understands.
        attachPreviewModel(viewportFrame, clone)
        return clone
    end

    -- Clear whatever the previous preview left behind. ClearAllChildren on the
    -- frame does NOT touch the WorldModel, so it has to be emptied explicitly or
    -- every card accumulates one dead model per wear that was ever opened.
    local previous = nil
    pcall(function() previous = viewportFrame.WorldModel end)
    if previous then
        pcall(function()
            for _, child in ipairs(previous:GetChildren()) do
                child:Destroy()
            end
        end)
    end

    world.Name = "PreviewWorld"
    pcall(function() viewportFrame.WorldModel = world end)

    -- A WorldModel must not be parented into the live scene.
    clone.Parent = world
    return clone
end

local function setupGloveViewport(viewportFrame, gloveModel, skinName)
    viewportFrame:ClearAllChildren()
    if not SkinsLib then return nil end

    local targetModel = gloveModel
    if targetModel == "Default" then
        targetModel = "CT Glove"
    end

    local model = nil
    local trySkins = { skinName, "Stock", "Vanilla" }

    -- temporarily bypass the engine hook so the preview shows the glove on the
    -- card rather than whatever pair is currently equipped
    local previousBypass = _G.__gloveCatalogPreview
    _G.__gloveCatalogPreview = true

    for _, s in ipairs(trySkins) do
        if s and s ~= "Random" and s ~= "Special" and s ~= "Default" then
            local ok, res = pcall(function()
                return SkinsLib.GetGloves(targetModel, s, 0.001)
            end)
            if ok and res then
                model = res
                break
            end
        end
    end

    if not model then
        local ok, res = pcall(function()
            return SkinsLib.GetGloves(targetModel, "Stock", 0.001)
        end)
        if ok then model = res end
    end

    _G.__gloveCatalogPreview = previousBypass

    if not model then return nil end

    local clone = model
    local cloneOk, cloneRes = pcall(function() return model:Clone() end)
    if cloneOk and cloneRes then clone = cloneRes end

    attachPreviewModel(viewportFrame, clone)

    local cf, size = clone:GetBoundingBox()
    local maxDim = math.max(size.X, size.Y, size.Z, 0.5)
    local distance = maxDim * 1.1

    local camera = Instance.new("Camera")
    camera.FieldOfView = 50
    local homePos = cf.Position + Vector3.new(distance * 0.7, distance * 0.35, distance * 0.75)
    camera.CFrame = CFrame.new(homePos, cf.Position)
    camera.Parent = viewportFrame

    viewportFrame.CurrentCamera = camera
    viewportFrame.LightColor = Color3.fromRGB(245, 245, 255)
    viewportFrame.Ambient = Color3.fromRGB(150, 150, 160)
    viewportFrame.LightDirection = Vector3.new(-1, -1.2, -1).Unit

    local rotationConn = nil
    local isHovered = false
    local angle = 0

    rotationConn = RunService.RenderStepped:Connect(function(delta)
        if isHovered and clone.Parent and camera.Parent then
            angle = angle + delta * 1.8
            local offset = CFrame.Angles(0, angle, 0)
                * Vector3.new(distance * 0.7, distance * 0.35, distance * 0.75)
            camera.CFrame = CFrame.new(cf.Position + offset, cf.Position)
        end
    end)

    table.insert(GloveCatalog.ViewportCleanups, function()
        if rotationConn then pcall(function() rotationConn:Disconnect() end) end
    end)

    return {
        setHover = function(hovered)
            isHovered = hovered
            if not hovered and camera.Parent then
                camera.CFrame = CFrame.new(homePos, cf.Position)
                angle = 0
            end
        end
    }
end

function GloveCatalog.init(Tab, Config, API, Library, Database)
    if GloveCatalog.Initialized then return end
    GloveCatalog.Initialized = true

    if Tab.LeftSide then Tab.LeftSide.Visible = false end
    if Tab.RightSide then Tab.RightSide.Visible = false end

    local TabFrame = Tab.TabFrame
    if not TabFrame then return end

    local MainContainer = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 6, 0, 6),
        Size = UDim2.new(1, -12, 1, -12),
        ZIndex = 2,
        Parent = TabFrame
    })

    ------------------------------------------------------------------
    -- Model view
    ------------------------------------------------------------------
    local ModelView = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        Visible = true,
        ZIndex = 2,
        Parent = MainContainer
    })

    local ModelHeader = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 26),
        ZIndex = 3,
        Parent = ModelView
    })
    Library:AddToRegistry(ModelHeader, {
        BackgroundColor3 = 'BackgroundColor',
        BorderColor3 = 'OutlineColor'
    })

    Library:CreateLabel({
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(0.5, 0, 1, 0),
        Text = "Glove Models",
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = ModelHeader
    })

    Library:CreateLabel({
        Position = UDim2.new(0.4, 0, 0, 0),
        Size = UDim2.new(0.6, -8, 1, 0),
        Text = "Left-Click: Equip  |  Right-Click: View Skins",
        TextColor3 = Color3.fromRGB(160, 160, 170),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4,
        Parent = ModelHeader
    })

    local ModelScroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 32),
        Size = UDim2.new(1, 0, 1, -32),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Library.AccentColor,
        ZIndex = 3,
        Parent = ModelView
    })
    Library:AddToRegistry(ModelScroll, { ScrollBarImageColor3 = 'AccentColor' })

    local ModelGrid = Library:Create('UIGridLayout', {
        CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
        CellPadding = UDim2.fromOffset(8, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = ModelScroll
    })

    ModelGrid:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        ModelScroll.CanvasSize = UDim2.fromOffset(0, ModelGrid.AbsoluteContentSize.Y + 12)
    end)

    ------------------------------------------------------------------
    -- Skin view
    ------------------------------------------------------------------
    local SkinView = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
        ZIndex = 2,
        Parent = MainContainer
    })

    local SkinHeader = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 26),
        ZIndex = 3,
        Parent = SkinView
    })
    Library:AddToRegistry(SkinHeader, {
        BackgroundColor3 = 'BackgroundColor',
        BorderColor3 = 'OutlineColor'
    })

    local BackButton = Library:Create('TextButton', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 4, 0, 3),
        Size = UDim2.new(0, 60, 0, 20),
        Text = "< Back",
        TextColor3 = Library.FontColor,
        TextSize = 12,
        ZIndex = 4,
        Parent = SkinHeader
    })
    Library:AddToRegistry(BackButton, {
        BackgroundColor3 = 'MainColor',
        BorderColor3 = 'OutlineColor'
    })

    local SkinTitle = Library:CreateLabel({
        Position = UDim2.new(0, 70, 0, 0),
        Size = UDim2.new(1, -78, 1, 0),
        Text = "Gloves / Skins",
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = SkinHeader
    })

    local SkinScroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 32),
        Size = UDim2.new(1, 0, 1, -32),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
        TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Library.AccentColor,
        ZIndex = 3,
        Parent = SkinView
    })
    Library:AddToRegistry(SkinScroll, { ScrollBarImageColor3 = 'AccentColor' })

    local SkinGrid = Library:Create('UIGridLayout', {
        CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
        CellPadding = UDim2.fromOffset(8, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = SkinScroll
    })

    SkinGrid:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        SkinScroll.CanvasSize = UDim2.fromOffset(0, SkinGrid.AbsoluteContentSize.Y + 12)
    end)

    ------------------------------------------------------------------
    -- Card builders
    ------------------------------------------------------------------
    local renderModelCards = nil
    local renderSkinCards = nil

    local function showModelView()
        GloveCatalog.CurrentView = "Models"
        SkinView.Visible = false
        ModelView.Visible = true
        renderModelCards()
    end

    local function showSkinView(gloveModel)
        GloveCatalog.CurrentView = "Skins"
        GloveCatalog.ActiveGlove = gloveModel
        SkinTitle.Text = gloveModel .. " / Skins"
        ModelView.Visible = false
        SkinView.Visible = true
        renderSkinCards(gloveModel)
    end

    BackButton.MouseButton1Click:Connect(showModelView)

    local function buildCard(parent, index, title, subtitle, isSelected, viewportModel, viewportSkin, onClick)
        local Card = Library:Create('TextButton', {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = isSelected and Library.AccentColor or Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
            LayoutOrder = index,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 4,
            Parent = parent
        })

        Library:Create('Frame', {
            BackgroundColor3 = isSelected and Library.AccentColor or Color3.fromRGB(40, 40, 45),
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, 2),
            ZIndex = 5,
            Parent = Card
        })

        local Viewport = Library:Create('ViewportFrame', {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 2, 0, 4),
            Size = UDim2.new(1, -4, 0, 100),
            ZIndex = 5,
            Parent = Card
        })

        local controller = setupGloveViewport(Viewport, viewportModel, viewportSkin)

        Library:CreateLabel({
            Position = UDim2.new(0, 4, 0, 104),
            Size = UDim2.new(1, -8, 0, 20),
            Text = title,
            TextSize = 15,
            TextColor3 = isSelected and Library.AccentColor or Library.FontColor,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 6,
            Parent = Card
        })

        Library:CreateLabel({
            Position = UDim2.new(0, 4, 0, 126),
            Size = UDim2.new(1, -8, 0, 18),
            Text = subtitle,
            TextSize = 13,
            TextColor3 = isSelected and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(140, 140, 150),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 6,
            Parent = Card
        })

        Card.MouseEnter:Connect(function()
            if controller then controller.setHover(true) end
            if not isSelected then Card.BorderColor3 = Color3.fromRGB(100, 105, 120) end
        end)

        Card.MouseLeave:Connect(function()
            if controller then controller.setHover(false) end
            if not isSelected then Card.BorderColor3 = Library.OutlineColor end
        end)

        Card.MouseButton1Click:Connect(onClick)

        return Card
    end

    renderModelCards = function()
        for _, child in ipairs(ModelScroll:GetChildren()) do
            if not child:IsA('UIGridLayout') then child:Destroy() end
        end
        cleanupViewports()

        local equipped = Config.GLOVE_MODEL or "Default"
        local list = (Database and Database.GloveModels) or { "Default" }

        for index, gloveModel in ipairs(list) do
            local isSelected = (equipped == gloveModel)
            local skin = (gloveModel == "Default") and "Stock" or (Config.GLOVE_SKIN or "Stock")

            local Card = buildCard(
                ModelScroll, index, gloveModel,
                isSelected and ("[" .. tostring(skin) .. "]") or tostring(skin),
                isSelected, gloveModel, skin,
                function()
                    if API and API.setGlove then
                        API.setGlove(gloveModel, skin)
                    else
                        Config.GLOVE_MODEL = gloveModel
                        Config.GLOVE_SKIN = skin
                        if Config.queueSave then Config.queueSave() else Config.save() end
                    end
                    Library:Notify("Equipped gloves: " .. tostring(gloveModel), 1.5)
                    renderModelCards()
                end
            )

            Card.MouseButton2Click:Connect(function()
                showSkinView(gloveModel)
            end)
        end
    end

    renderSkinCards = function(gloveModel)
        for _, child in ipairs(SkinScroll:GetChildren()) do
            if not child:IsA('UIGridLayout') then child:Destroy() end
        end
        cleanupViewports()

        local list = (Database and Database.getGloveSkinList)
            and Database.getGloveSkinList(gloveModel) or { "Stock" }

        local equipped = Config.GLOVE_MODEL or "Default"
        local activeSkin = Config.GLOVE_SKIN or "Stock"

        for index, skinName in ipairs(list) do
            local isSelected = (equipped == gloveModel and activeSkin == skinName)

            buildCard(
                SkinScroll, index, skinName, gloveModel,
                isSelected, gloveModel, skinName,
                function()
                    if API and API.setGlove then
                        API.setGlove(gloveModel, skinName)
                    else
                        Config.GLOVE_MODEL = gloveModel
                        Config.GLOVE_SKIN = skinName
                        if Config.queueSave then Config.queueSave() else Config.save() end
                    end
                    Library:Notify("Glove skin: " .. tostring(skinName), 1.5)
                    renderSkinCards(gloveModel)
                end
            )
        end
    end

    GloveCatalog.refresh = function()
        if GloveCatalog.CurrentView == "Skins" and GloveCatalog.ActiveGlove then
            pcall(renderSkinCards, GloveCatalog.ActiveGlove)
        else
            pcall(renderModelCards)
        end
    end

    renderModelCards()
end

function GloveCatalog.cleanup()
    cleanupViewports()
    GloveCatalog.Initialized = false
    GloveCatalog.CurrentView = "Models"
    GloveCatalog.ActiveGlove = nil
end

return GloveCatalog
