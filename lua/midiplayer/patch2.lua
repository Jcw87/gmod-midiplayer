AddCSLuaFile()

if not CLIENT then return end

local error = error
local setmetatable = setmetatable

local sound = sound

module("midi")

PATCH = {}
PATCH.__index = PATCH

function PATCH:PlayEx(vol, pitch)
	self.vol = vol
	self.pitch = pitch
	self.playing = true
	if self.o then self.o:Play() end
end

function PATCH:ChangePitch(pitch)
	self.pitch = pitch
	if self.o then self.o:SetPlaybackRate(pitch) end
end

function PATCH:ChangeVolume(vol)
	self.vol = vol
	if self.o then self.o:SetVolume(vol) end
end

function PATCH:SetLoop(loop)
	-- with no way of setting the loop points, this just sounds awful
	self.loop = loop
	if self.o then self.o:EnableLooping(loop) end
end

function PATCH:Stop()
	self.playing = false
	if self.o then
		self.o:Pause()
		self.o:SetTime(0)
	end
end

function PATCH:IsPlaying()
	return self.playing
end

function PATCH:Free()
	self:Stop()
	self.free = true
end

function _CreatePatch(name)
	name = "sound/" .. name:TrimLeft("#")
	local patches = synth.patches
	if not patches[name] then patches[name] = {} end
	local a = patches[name]
	local patch
	for i = 1, #a do
		if a[i].free then
			patch = a[i]
			break
		end
	end
	if not patch then
		patch = setmetatable({}, PATCH)
		patch.name = name
		sound.PlayFile(name, "noblock noplay", function(s, errorID, errorStr)
			if not s then error(errorStr) end
			patch.o = s
			if patch.playing then
				s:SetPlaybackRate(patch.pitch)
				s:SetVolume(patch.vol)
				s:EnableLooping(patch.loop)
				s:Play()
			end
		end)
	end
	patch.free = false
	patch.playing = false
	return patch
end
