-- Fails if any source file (UI included) contains emoji / non-ASCII glyphs. Icons are blank slots now.
local fs = require("@lune/fs")

local function walk(dir, out)
	for _, name in ipairs(fs.readDir(dir)) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			walk(p, out)
		elseif p:match("%.luau?$") then
			table.insert(out, p)
		end
	end
	return out
end

return function(ctx)
	local t = ctx.test
	t("no non-ASCII glyphs in src/", function()
		local bad = {}
		for _, p in ipairs(walk("src", {})) do
			local n = 0
			for line in (fs.readFile(p) .. "\n"):gmatch("([^\n]*)\n") do
				n += 1
				if line:find("[\128-\255]") then
					table.insert(bad, p .. ":" .. n)
				end
			end
		end
		assert(#bad == 0, "non-ASCII glyphs found:\n" .. table.concat(bad, "\n"))
	end)
	t("corners: UICorner only via UI/Shape, radius clamped to 8px or less", function()
		local shape = fs.readFile("src/client/UI/Shape.luau")
		local max = tonumber(shape:match("MAX_RADIUS = %d+, (%d+)"))
		assert(max and max <= 8, "Shape MAX_RADIUS must be <= 8")
		for _, p in ipairs(walk("src", {})) do
			if not p:match("UI/Shape%.luau$") then
				assert(not fs.readFile(p):find("UICorner"), "UICorner in " .. p)
			end
		end
	end)
end
