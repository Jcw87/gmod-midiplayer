AddCSLuaFile()

if not CLIENT then return end

local table = table

local setmetatable = setmetatable

module("midi")

CHANNEL = CHANNEL or {}
CHANNEL.__index = CHANNEL

function CHANNEL:Reset()
	self.bank = (self.id == 10) and 128 or 0
	self.program = 0
	self.pitchbend = 8192
	self.volume = 127
	self.expression = 127
	self.preset = sf:GetPreset(self.bank, self.program)
end

function CHANNEL:NoteOff(key)
	for i = 1, #self.voices do
		local voice = self.voices[i]
		if not voice then continue end -- LuaJIT pisses me off sometimes
		if voice.key == key then voice:NoteOff() end
	end
end

function CHANNEL:NoteOn(key, vel)
	if not self.preset then
		warnf("Ignoring note on. channel: %i program: %i key: %i vel: %i\n", self.id, self.program, key, vel)
		return
	end
	self:NoteOff(key)
	
	-- Certain soundfonts (Arachno) go overboard with how many samples play per note.
	-- Source can't handle it, so only play 1
	local finished = false
	
	local preset = self.preset
	for i = 1, #preset.bags do
		local pbag = preset.bags[i]
		if not pbag:InRange(key, vel) then continue end
		local inst = pbag.instrument
		for j = 1, #inst.bags do
			local ibag = inst.bags[j]
			if not ibag:InRange(key, vel) then continue end
			if not ibag.sample then continue end
			local sample = ibag.sample
			local voice = _CreateVoice(self, pbag, ibag, sample, key, vel)
			if not voice then
				warnf("not enough ents to play %s\n", sample.name)
				return
			end
			table.insert(self.voices, voice)
			voice:NoteOn()
			finished = true
			if finished then break end
		end
		if finished then break end
	end
	
	printf("Note on! chan: %2i key: %3i vel: %3i preset: %-20s\n", self.id, key, vel, preset.name)
end

function CHANNEL:ControlChange(control, value)
	if control == 0 then
		-- bank change
		--self.bank = bit.bor(bit.band(self.bank, 0x7F), bit.lshift(value, 7))
		self.bank = value
		printf("Bank change! channel: %i bank: %i\n", self.id, self.bank)
		return
	end
	if control == 7 then
		-- volume
		self.volume = value
		for i = 1, #self.voices do
			local voice = self.voices[i]
			voice:UpdateVolume()
		end
		printf("Volume change! channel: %i volume: %i\n", self.id, value)
		return
	end
	if control == 10 then
		--warnf("Ignoring pan! channel %i value: %i\n", self.id, value)
		return
	end
	if control == 11 then
		self.expression = value
		for i = 1, #self.voices do
			local voice = self.voices[i]
			voice:UpdateVolume()
		end
		printf("Expression change! channel: %i expression: %i\n", self.id, value)
		return
	end
	--[[
	if control == 32 then
		-- bank change
		self.bank = bit.bor(bit.band(self.bank, 0x3F80), bit.band(value, 0x7F))
		printf("Bank change! channel: %i bank: %i\n", self.id, self.bank)
		return
	end
	]]
	--warnf("Ignoring control change! channel: %i controller: %i value: %i\n", self.id, control, value)
	self.cc[control+1] = value
end

function CHANNEL:ProgramChange(program)
	self.program = program
	self.preset = sf:GetPreset(self.bank, program)
	printf2("Program change! channel: %i program: %i\n", self.id, program)
end

function CHANNEL:PitchBend(value)
	self.pitchbend = value
	printf("Pitch bend! channel: %i bend: %i\n", self.id, value - 8192)
	for i = 1, #self.voices do
		local voice = self.voices[i]
		voice:UpdatePitch()
	end
end

function CHANNEL:AllSoundOff()
	for i = #self.voices, 1, -1 do
		local voice = self.voices[i]
		voice:Stop()
		voice:Free()
		table.remove(self.voices, i)
	end
end

function CHANNEL:AllNotesOff()
	for i = 1, #self.voices do
		local voice = self.voices[i]
		voice:NoteOff()
	end
end

function CHANNEL:Tick(delta)
	for i = #self.voices, 1, -1 do
		local voice = self.voices[i]
		voice:Tick(delta)
		if not voice:IsPlaying() then
			voice:Free()
			table.remove(self.voices, i)
		end
	end
end

function _CreateChannel(i)
	local channel = setmetatable({}, CHANNEL)
	channel.id = i
	channel.cc = {}
	channel.voices = {}
	return channel
end