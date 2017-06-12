AddCSLuaFile()

if not CLIENT then return end

local math = math

module("midi")

local cb2amp_tab = {}
for i = 0, 960 do
	cb2amp_tab[i] = 10 ^ (i / -200)
end

local atten2amp_tab = {}
for i = 0, 1440 do
    atten2amp_tab[i] = 10 ^ (i / -200)
end

local convex_tab = {}
local concave_tab = {}
concave_tab[0] = 0
concave_tab[127] = 1
convex_tab[0] = 0
convex_tab[127] = 1
for i = 1, 126 do
    local x = -20.0 / 96.0 * math.log10((i * i) / (127.0 * 127.0))
    convex_tab[i] = 1.0 - x
    concave_tab[127 - i] = x
end

function cb2amp(cb)
	if cb < 0 then
		return 1
	elseif cb > 960 then
		return 0
	else
		return cb2amp_tab[math.floor(cb)]
	end
	
end

function atten2amp(atten)
	if atten < 0 then
		return 1
	elseif atten > 1440 then
		return 0
	else
		return atten2amp_tab[math.floor(atten)]
	end
end

function concave(val)
	if val < 0 then
		return 0
	elseif val > 127 then
		return 1
	else
		return concave_tab[math.floor(val)]
	end
end

function convex(val)
	if val < 0 then
		return 0
	elseif val > 127 then
		return 1
	else
		return convex_tab[math.floor(val)]
	end
end