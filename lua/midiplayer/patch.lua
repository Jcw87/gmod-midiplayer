AddCSLuaFile()

if not CLIENT then return end

local setmetatable = setmetatable

local math = math

local CreateSound = CreateSound

module("midi")

PATCH = {}
PATCH.__index = PATCH

function PATCH:PlayEx(vol, pitch)
	pitch = math.floor(pitch * 100 + 0.5)
	if pitch > 255 then
		warnf("Ignoring voice with pitch: %i\n", pitch)
		return
	end
	self.o:PlayEx(vol, pitch)
end

function PATCH:ChangePitch(pitch)
	pitch = math.floor(pitch * 100 + 0.5)
	self.o:ChangePitch(pitch)
end

function PATCH:ChangeVolume(vol)
	self.o:ChangeVolume(vol)
end

function PATCH:SetLoop(loop) end

function PATCH:Stop()
	self.o:Stop()
end

function PATCH:IsPlaying()
	return self.o:IsPlaying()
end

function PATCH:Free()
	self:Stop()
	self.free = true
end

function _CreatePatch(name)
	local patches = synth.patches
	if not patches[name] then patches[name] = {} end
	local a = patches[name]
	local slot
	for i = 1, #synth.playbackents do
		if a[i] and a[i].free then
			a[i].free = false
			return a[i]
		end
		if not a[i] then
			slot = i
			break
		end
	end
	if not slot then return end
	local patch = setmetatable({}, PATCH)
	patch.free = false
	patch.name = name
	patch.slot = slot
	patch.o = CreateSound(synth.playbackents[slot], name)
	patch.o:SetSoundLevel(0)
	patches[name][slot] = patch
	return patch
end
