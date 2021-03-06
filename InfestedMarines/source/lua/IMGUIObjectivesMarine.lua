
function GetMarineObjectivePanel()
    return ClientUI.GetScript("IMGUIObjectivesMarine")
end

class 'IMGUIObjectivesMarine' (GUIScript)

--local kTransitionTime = 0.5
local kTransitionTime = 3.0
local kTextFadeTime = 0.35
local kTextColor = Color(201/255, 231/255, 1,1)

IMGUIObjectivesMarine.kPanelBackgroundTexture = PrecacheAsset("ui/marine_objective_frame.dds")
IMGUIObjectivesMarine.kPanelTransitionMask = PrecacheAsset("ui/marine_objective_transition_mask.dds")
IMGUIObjectivesMarine.kPanelScanlines = PrecacheAsset("ui/marine_objective_scanlines.dds")
IMGUIObjectivesMarine.kPanelScanlinesMask = PrecacheAsset("ui/marine_objective_frame_mask.dds")
IMGUIObjectivesMarine.kPanelShader = "shaders/GUIObjectiveDisplay.surface_shader" --using PrecacheAsset() causes it to throw syntax errors... :/

IMGUIObjectivesMarine.kPanelBaseScale = 0.6667
IMGUIObjectivesMarine.kPanelBackgroundSize = Vector(719, 461, 0) * IMGUIObjectivesMarine.kPanelBaseScale
IMGUIObjectivesMarine.kPanelBackgroundStencilSize = Vector(IMGUIObjectivesMarine.kPanelBackgroundSize.x, IMGUIObjectivesMarine.kPanelBackgroundSize.y*5, 0)

local textPadding = Vector(60,60,0) * IMGUIObjectivesMarine.kPanelBaseScale

local kObjectivePanelOffset = Vector(-50,80,0)

local textState = enum({'hidden','fadingIn', 'visible', 'fadingOut'})

local function GetFontForScale()
    if GUIScaleHeight(1) >= 0.7 then
        return Fonts.kAgencyFB_Medium
    elseif GUIScaleHeight(1) >= 0.45 then
        return Fonts.kAgencyFB_Small
    else
        return Fonts.kAgencyFB_Tiny
    end
end

local function GetSmallerFont(font)
    if font == Fonts.kAgencyFB_Medium then
        return Fonts.kAgencyFB_Small
    elseif font == Fonts.kAgencyFB_Small then
        return Fonts.kAgencyFB_Tiny
    elseif font == Fonts.kAgencyFB_Tiny then
        return nil
    else
        Log("GetSmallerFont() Unrecognized font!")
        return nil
    end
end

function IMGUIObjectivesMarine:Initialize()
    
    self.current_state = 'hidden_before'  -- 'hidden_before', 'unhiding', 'visible', 'hiding', 'hidden_after'
    --self.interp = 0.0
    
    self.background = GUIManager:CreateGraphicItem()
    self.background:SetPosition( Vector(0,0,0) )
    self.background:SetAnchor(GUIItem.Right, GUIItem.Top)
    self.background:SetIsVisible(true)
    self.background:SetColor( Color(1, 1, 1, 0) )
    self.background:SetLayer(kGUILayerPlayerHUDBackground)
    
    self.panel = GUIManager:CreateGraphicItem()
    self.panel:SetAnchor(GUIItem.Right, GUIItem.Top)
    self.panel:SetTexture(IMGUIObjectivesMarine.kPanelBackgroundTexture)
    self.panel:SetInheritsParentAlpha(false)
    self.panel:SetColor( Color(1,1,1,1))
    self.panel:SetLayer(kGUILayerPlayerHUDForeground1)
    self.panel:SetShader(IMGUIObjectivesMarine.kPanelShader)
    self.panel:SetAdditionalTexture("transitionMap", IMGUIObjectivesMarine.kPanelTransitionMask)
    self.panel:SetAdditionalTexture("scanlineTex", IMGUIObjectivesMarine.kPanelScanlines)
    self.panel:SetAdditionalTexture("mask", IMGUIObjectivesMarine.kPanelScanlinesMask)
    self.panel:SetFloatParameter("startTime", 0.0)
    self.panel:SetFloatParameter("endTime", 1.0)
    self.panel:SetFloatParameter("startPosition", 2.0)
    self.panel:SetFloatParameter("endPosition", 2.0)
    self.panel:SetIsVisible(true)
    self.background:AddChild(self.panel)
    
    self.panel_text = GUI.CreateItem()
    self.panel_text:SetFontName(GetFontForScale())
    self.panel_text:SetAnchor(GUIItem.Right, GUIItem.Top)
    self.panel_text:SetOptionFlag(GUIItem.ManageRender)
    self.panel_text:SetTextAlignmentX(GUIItem.Align_Min)
    self.panel_text:SetTextAlignmentY(GUIItem.Align_Min)
    self.panel_text:SetLayer(kGUILayerPlayerHUDForeground2)
    self.panel_text:SetColor(Color(kTextColor.r, kTextColor.g, kTextColor.b, 0))
    self.panel_text:SetIsVisible(true)
    self.textState = textState.hidden
    self.background:AddChild(self.panel_text)
    
    self.nextText = ''
    self.nextFont = nil
    self.currentFont = nil
    
    self:UpdateLayout()
    
    self.updateInterval = 1/60 --60 fps
    
    self:SetVisibility(false)
    
end


function IMGUIObjectivesMarine:SetVisibility(vis)
    if self.panel then
        self.panel:SetIsVisible(vis)
    end
    
    if self.panel_text then
        self.panel_text:SetIsVisible(vis)
    end
end


function IMGUIObjectivesMarine:UpdateLayout()
    
    self.panel:SetPosition( GUIScaleHeight(Vector(-IMGUIObjectivesMarine.kPanelBackgroundSize.x,0,0) + kObjectivePanelOffset))
    self.panel:SetSize( GUIScaleHeight( IMGUIObjectivesMarine.kPanelBackgroundSize ) )
    
    self.panel_text:SetPosition( self.panel:GetPosition() + GUIScaleHeight( textPadding))
    self.panel_text:SetSize( self.panel:GetSize() - GUIScaleHeight( textPadding*2))
    self:SetText(self.raw_text or '') --to update the text wrapping
    
end


function IMGUIObjectivesMarine:Uninitialize()
    GUI.DestroyItem(self.stencil)
    GUI.DestroyItem(self.panel)
    GUI.DestroyItem(self.panel_text)
    self.panel_text = nil
    self.stencil = nil
    self.panel = nil
end


function IMGUIObjectivesMarine:OnResolutionChanged()
    
    self:UpdateLayout()
    
end


function IMGUIObjectivesMarine:SetText(text, duration, immediate)
    
    if duration and duration > 0.001 then --it's a temporary text, need to store the last permanent value
        self.last_permanent_raw_text = self.last_permanent_raw_text or self.raw_text
        self.revert_time = Shared.GetTime() + duration
    else
        self.last_permanent_raw_text = text
    end
    
    -- size text appropriately
    local good = false
    local font = GetFontForScale()
    local maxHeight = self.panel:GetSize().y - GUIScaleHeight(textPadding.y * 2)
    local wrapped_text = nil
    while not good do
        
        self.raw_text = text --store unwrapped copy, for when resolution changes
        self.panel_text:SetFontName(font)
        wrapped_text = WordWrap( self.panel_text, self.raw_text, 0, self.panel:GetSize().x - GUIScaleHeight(textPadding.x * 2))
        local height = self.panel_text:GetTextHeight(wrapped_text)
        if height <= maxHeight then
            good = true
        else
            local smallerFont = GetSmallerFont(font)
            if smallerFont then
                font = smallerFont
            else
                good = true --smallest font still doesn't cut it, move along.
            end
        end
        
    end
    
    self.nextFont = font
    self.panel_text:SetFontName(self.currentFont or font)
    self.nextText = wrapped_text
    self.textState = textState.fadingOut
    
    if immediate then
        self.textOpacity = 1
        self.textState = textState.visible
        GUIItem.SetText( self.panel_text, self.nextText )
        self.currentFont = self.nextFont
        self.panel_text:SetFontName(self.currentFont)
    end
    
end


function IMGUIObjectivesMarine:AnimateIn(immediate)
    
    self.showing = true
    self.current_state = 'unhiding'
    local startTime = Shared.GetTime()
    self.endTime = immediate and startTime or (startTime + kTransitionTime)
    self.panel:SetFloatParameter("startTime", startTime)
    self.panel:SetFloatParameter("endTime", self.endTime)
    self.panel:SetFloatParameter("startPosition", 2.0)
    self.panel:SetFloatParameter("endPosition", 1.0)
    
end


function IMGUIObjectivesMarine:AnimateOut(immediate)
    
    self.showing = false
    self.current_state = 'hiding'
    local startTime = Shared.GetTime()
    self.endTime = immediate and startTime or (startTime + kTransitionTime)
    self.panel:SetFloatParameter("startTime", startTime)
    self.panel:SetFloatParameter("endTime", self.endTime)
    self.panel:SetFloatParameter("startPosition", 1.0)
    self.panel:SetFloatParameter("endPosition", 0.0)
    self:SetText('',0)
    
end


function IMGUIObjectivesMarine:GetTypeString()
    return "marine"
end


local function UpdateVisibilityAndText(self)
    
    local player = Client.GetLocalPlayer()
    if not player then
        return
    end
    
    local playerId = player:GetId()
    local immediateUpdate = playerId ~= self.lastPlayerId
    
    local isMarine = player and player:isa("Marine") and player.GetIsAlive and player:GetIsAlive()
    local isInfested = isMarine and player.GetIsInfested and player:GetIsInfested()
    
    local objective = Marine.kObjective.NoObjective
    if isMarine then
        objective = (player.GetObjective and player:GetObjective()) or objective
    end
    
    local lut = Marine.kObjectiveStatusEvaluationTable[self:GetTypeString()][objective]
    
    local desiredVisibility = lut.vis
    local desiredText = lut.textFunc()
    local updateNeeded = immediateUpdate or (self.lastObjective ~= objective)
    
    if updateNeeded then
        if desiredVisibility then
            if not self.showing then
                self:AnimateIn(immediateUpdate)
                self:SetVisibility(true)
            end
            self:SetText(desiredText, nil, immediateUpdate)
        else
            if self.showing then
                self:AnimateOut(immediateUpdate)
            end
        end
    end
    
    self.lastPlayerId = playerId
    self.lastObjective = objective
    
end

function IMGUIObjectivesMarine:Update(deltaTime)
    
    UpdateVisibilityAndText(self)
    
    if self.current_state == 'hidden_before' then
        return
    end
    
    if self.current_state == 'hidden_after' then
        return
    end
    
    if self.current_state == 'visible' then
        return
    end
    
    local now = Shared.GetTime()
    
    if self.current_state == 'unhiding' then
        if self.end_time and self.end_time <= now then
            self.current_state = 'visible'
            self.end_time = nil
            if self.callback then
                self.callback()
            end
        end
    end
    
    if self.current_state == 'hiding' then
        if self.end_time and self.end_time <= now then
            self.current_state = 'hidden_after'
            self.end_time = nil
            if self.callback then
                self.callback()
            end
        end
    end
    
    if self.revert_time and now > self.revert_time then
        self:SetText(self.last_permanent_raw_text, 0.0)
        self.revert_time = nil
    end
    
    self.textOpacity = self.textOpacity or 0
    
    if self.textState == textState.fadingOut then
        self.textOpacity = self.textOpacity - deltaTime / kTextFadeTime
        
        if self.textOpacity <= 0 then
            self.textOpacity = 0
            self.textState = textState.fadingIn
            GUIItem.SetText( self.panel_text, self.nextText )
            self.currentFont = self.nextFont
            self.panel_text:SetFontName(self.currentFont)
        end
        
    end
    
    if self.textState == textState.fadingIn then
        self.textOpacity = self.textOpacity + deltaTime / kTextFadeTime
        
        if self.textOpacity >= 1 then
            self.textOpacity = 1
            self.textState = textState.visible
        end
    end
    
    if self.textState == textState.visible then
        self.textOpacity = 1
    end
    
    if self.textState == textState.hidden then
        self.textOpacity = 0
    end
    
    self.panel_text:SetColor(Color(kTextColor.r, kTextColor.g, kTextColor.b, self.textOpacity))
end


