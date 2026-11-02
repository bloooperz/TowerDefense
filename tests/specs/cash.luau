local Cash = require("../../src/shared/Cash")
local function fakePlayer()
	local attrs, kids = {}, {}
	local p = {}
	function p:GetAttribute(k) return attrs[k] end
	function p:SetAttribute(k, v) attrs[k] = v end
	function p:GetAttributeChangedSignal() return { Connect = function() end } end
	function p:FindFirstChild(n) return kids[n] end
	local ls = { children = {} }
	function ls:FindFirstChild(n) return self.children[n] end
	kids.leaderstats = ls
	return p, ls
end
local function newValue()
	local v = { Value = 0 }
	function v:Destroy() self.Parent.children[self.Name] = nil end
	return setmetatable({}, { __index = v, __newindex = function(_, k, x)
		v[k] = x
		if k == "Parent" then x.children[v.Name] = v end
	end })
end
return function(ctx)
	local t = ctx.test
	t("cash defaults to 0 with no leaderstats value (lobby)", function()
		local p = fakePlayer()
		assert(Cash.get(p) == 0 and Cash.of(p).Value == 0)
	end)
	t("cash mirror exists only while visible", function()
		local p, ls = fakePlayer()
		local h = Cash.of(p)
		h.Value = 600
		Cash.setVisible(p, true, newValue)
		assert(ls.children.Cash and ls.children.Cash.Value == 600)
		h.Value -= 100
		assert(Cash.get(p) == 500 and ls.children.Cash.Value == 500)
		Cash.setVisible(p, false)
		assert(ls.children.Cash == nil and Cash.get(p) == 500)
	end)
end
