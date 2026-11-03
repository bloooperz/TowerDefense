-- Pure rules for Studio-only dev grants (server/Dev calls these; lune tests them).
-- Gems go through the REAL grant path (PlayerData.grant { gems = n }), so dirty/save and
-- replication (Gems attribute -> currency UI) are identical to stage rewards.
local DevGrants = {}

DevGrants.GEMS = 500 -- = Summon.STARTER_GEMS (one x10 summon); kept equal by tests/specs/devgrants

-- isStudio: RunService:IsStudio(). hasData: profile loaded. grant(g): the real grant function.
-- Returns reason string on refusal, nil on success.
function DevGrants.giveGems(isStudio, hasData, grant)
	if not isStudio then
		return "Dev menu is Studio-only"
	end
	if not hasData then
		return "Your data hasn't loaded yet"
	end
	grant({ gems = DevGrants.GEMS })
	return nil
end

return DevGrants
