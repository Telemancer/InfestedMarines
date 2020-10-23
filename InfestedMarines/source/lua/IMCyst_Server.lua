-- ======= Copyright (c) 2003-2010, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\IMCyst_Server.lua
--
--    Created by:   Trevor Harris (trevor@naturalselection2.com)
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

function Cyst:GetIsActuallyConnected()
    return true
end

function Cyst:OnEntityChange(entityId, newEntityId)
end

function Cyst:OnKill(attacker, doer, point, direction)
    
    -- Handle OnKill for this cyst
	self:TriggerEffects("death")
	self.connected = false
	self:SetModel(nil)
	self:Kill()
	
    if doer and doer:isa("Flamethrower") then
        -- kill all cysts within IMCystManager.kCystConnectionRadius, to make clearing easier
        -- and also as a workaround for the unreachable cyst issue.
        local cysts = GetEntitiesWithinRange("Cyst", self:GetOrigin(), IMCystManager.kCystConnectionRadius)
        for i=1, #cysts do
            if cysts[i] and cysts[i] ~= self and cysts[i].GetIsAlive then
				cysts[i]:TriggerEffects("death")
				cysts[i].connected = false
				cysts[i]:SetModel(nil)
				cysts[i]:Kill()
            end
        end
    end
    
    GetCystManager():CreateAreaOfDenial(self:GetOrigin())
    
    TipHandler_ReportCystKilled(attacker)
    
end

