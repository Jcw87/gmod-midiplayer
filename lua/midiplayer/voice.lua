AddCSLuaFile()

if not CLIENT then return end

local setmetatable = setmetatable
local tonumber = tonumber

local math = math
local table = table

module("midi")

VOICE = VOICE or {}
VOICE.__index = VOICE

function VOICE:CalcPitch()
	local rootkey = self.gens[GEN.OVERRIDEROOTKEY]
	local scaletune = self.gens[GEN.SCALETUNE] / 100
	local pitch = 2^((self.key-rootkey)*scaletune/12 + (self.channel.pitchbend - 8192)/(4096*12))
	return pitch
end

function VOICE:UpdatePitch()
	local pitch = self:CalcPitch()
	self.patch:ChangePitch(pitch)
end

function VOICE:CalcVolume()
	local instvol = self.gens[GEN.ATTENUATION] * 0.4
	local chanvol = concave(127 - self.channel.volume) * 960
	local exprvol = concave(127 - self.channel.expression) * 960
	local velvol = concave(127 - self.velocity) * 960
	local atten = math.Clamp(instvol + chanvol + exprvol + velvol, 0, 1440)
	local env = 960 * (1 - self.volenv.value)
	--printf("chanvol: %f velvol: %f, atten: %f\n", chanvol, velvol, atten)
	-- thanks to scripts/soundmixers.txt, almost all sounds will have their volume reduced
	-- counteract this here
	local target_amp = atten2amp(atten) * cb2amp(env) * 1.6
	return target_amp
end

function VOICE:UpdateVolume()
	local vol = self:CalcVolume()
	self.patch:ChangeVolume(vol)
end

function VOICE:Play()
	self.time = 0
	self.volenv:Reset()
	local volume = self:CalcVolume()
	local pitch = self:CalcPitch()
	local loop = true
	if self.gens[GEN.SAMPLEMODE] == 0 then
		self.sampletime = self.sample.time / pitch
		loop = false
	end
	self.patch:SetLoop(loop)
	self.patch:PlayEx(volume, pitch)
end

function VOICE:Stop()
	self.patch:Stop()
end

function VOICE:NoteOff()
	self.volenv:NoteOff()
	--self:Stop()
end

function VOICE:NoteOn()
	self:Play()
end

function VOICE:IsPlaying()
	return self.patch:IsPlaying()
end

function VOICE:Tick(delta)
	if self.free then return end
	self.volenv:Tick(delta)
	local vol = self:CalcVolume()
	self.patch:ChangeVolume(vol)
	self.time = self.time + delta
	-- kill sounds that have finished
	if self.volenv.phase == FLUID_VOICE_ENVFINISHED or self.time > self.sampletime then self:Stop() return end
	-- kill sounds that are in release phase, but too quiet to care about
	if self.volenv.phase == FLUID_VOICE_ENVRELEASE and vol < 0.05 then self:Stop() return end
	--printf("key: %i, time: %f, phase: %i\n", self.key, self.volenv.time, self.volenv.phase)
end

function VOICE:Free()
	self.patch:Stop()
	self.patch:Free()
	self.free = true
end

function _CreateVoice(channel, pbag, ibag, sample, key, vel)
	local patch = _CreatePatch(sample.enginename)
	if not patch then return end
	
	local voices = synth.voices
	local voice
	for i = 1, #voices do
		if voices[i].free then
			voice = voices[i]
			break
		end
	end
	if not voice then
		voice = setmetatable({}, VOICE)
		voice.gens = {}
		voice.volenv = _CreateEnvelope()
		table.insert(voices, voice)
	end
	voice.free = false
	voice.channel = channel
	voice.sample = sample
	voice.sampletime = math.huge
	voice.patch = patch
	voice.key = key
	voice.velocity = vel
	for i = 0, GEN.LAST-1 do
		local pgen = pbag.gens[i]
		local gen = ibag.gens[i]
		if gen and pgen then gen = gen + pgen end
		voice.gens[i] = gen
	end
	if not voice.gens[GEN.OVERRIDEROOTKEY] then voice.gens[GEN.OVERRIDEROOTKEY] = sample.rootkey end
	voice.volenv.data[FLUID_VOICE_ENVDELAY].time = 2^(voice.gens[GEN.VOLENVDELAY]/1200)
	voice.volenv.data[FLUID_VOICE_ENVATTACK].time = 2^(voice.gens[GEN.VOLENVATTACK]/1200)
	voice.volenv.data[FLUID_VOICE_ENVHOLD].time = 2^(voice.gens[GEN.VOLENVHOLD]/1200)
	voice.volenv.data[FLUID_VOICE_ENVDECAY].time = 2^(voice.gens[GEN.VOLENVDECAY]/1200)
	voice.volenv.data[FLUID_VOICE_ENVRELEASE].time = 2^(voice.gens[GEN.VOLENVRELEASE]/1200)
	local sustain = 1 - 0.001 * voice.gens[GEN.VOLENVSUSTAIN]
	voice.volenv.data[FLUID_VOICE_ENVDECAY].target = sustain
	voice.volenv.data[FLUID_VOICE_ENVSUSTAIN].target = sustain
	return voice
end
