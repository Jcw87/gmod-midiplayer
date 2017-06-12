AddCSLuaFile()

if not CLIENT then return end

local pairs = pairs
local table = table

local setmetatable = setmetatable

local ents = ents
local hook = hook
local game = game
local util = util

local ClientsideModel = ClientsideModel
local CreateSound = CreateSound
local LocalPlayer = LocalPlayer
local Vector = Vector

module("midi")

SYNTH = SYNTH or {}
SYNTH.__index = SYNTH

function SYNTH:NoteOff(chan, key)
	self.channels[chan]:NoteOff(key)
end

function SYNTH:NoteOn(chan, key, vel)
	if vel == 0 then return self:NoteOff(chan, key) end
	self.channels[chan]:NoteOn(key, vel)
end

function SYNTH:Aftertouch(chan, key, val)
	-- Not implemented
end

function SYNTH:ControlChange(chan, control, val)
	self.channels[chan]:ControlChange(control, val)
end

function SYNTH:ProgramChange(chan, program)
	self.channels[chan]:ProgramChange(program)
end

function SYNTH:ChannelAftertouch(chan, val)
	-- Not implemented
end

function SYNTH:PitchBend(chan, val)
	self.channels[chan]:PitchBend(val)
end

function SYNTH:AllSoundOff(chan)
	self.channels[chan]:AllSoundOff()
end

function SYNTH:AllNotesOff(chan)
	self.channels[chan]:AllNotesOff()
end

function SYNTH:GlobalAllSoundOff()
	for i = 1, #self.channels do
		self.channels[i]:AllSoundOff()
	end
	-- extra cleanup in case of Lua errors
	for k, v in pairs(self.voices) do
		self.voices[k] = nil
	end
	for k, v in pairs(self.patches) do
		self.patches[k] = nil
	end
end

function SYNTH:GlobalAllNotesOff()
	for i = 1, #self.channels do
		self.channels[i]:AllNotesOff()
	end
end

function SYNTH:Reset()
	for i = 1, #self.channels do
		self.channels[i]:Reset()
	end
end

function SYNTH:Tick(delta)
	for i = 1, #self.channels do
		self.channels[i]:Tick(delta)
	end
end

local function _CreateSynth()
	local synth = setmetatable({}, SYNTH)
	synth.channels = {}
	synth.voices = {} -- for voice recycling
	synth.patches = {} -- for patch allocation/recycling
	for i = 1, 16 do
		synth.channels[i] = _CreateChannel(i)
	end
	
	return synth
end

synth = _CreateSynth()
synth.playbackents = {}

local function MakeEntList()
	hook.Remove("Think", "MidiInit")
	
	--[[
	if #synth.playbackents > 0 then return end
	
	local model = "models/props_borealis/bluebarrel001.mdl"
	local pos = Vector(0, 0, 0)
	util.PrecacheModel(model)
	
	for i = 1, 16 do
		--local ent = ents.CreateClientProp(model)
		local ent = ClientsideModel(model)
		ent:SetPos(pos)
		ent:Spawn()
		synth.playbackents[i] = ent
	end
	--]]

	-- CSoundPatch doesn't work correctly on client-created entities, so borrow some existing ones.
	local names = {
		"class C_PlayerResource",
		"class C_GMODGameRulesProxy",
		"class C_FogController",
		"class C_ShadowControl",
		"class C_Sun",
		"viewmodel",
		"env_skypaint",
	}
	table.insert(synth.playbackents, game.GetWorld())
	table.insert(synth.playbackents, LocalPlayer())
	for i = 1, #names do
		local name = names[i]
		local found = ents.FindByClass(name)
		for j = 1, #found do
			local ent = found[j]
			table.insert(synth.playbackents, ent)
		end
	end
end

hook.Add("Think", "MidiInit", MakeEntList)
