AddCSLuaFile()

if not CLIENT then return end

local math = math

local setmetatable = setmetatable

local Lerp = Lerp

module("midi")

FLUID_VOICE_ENVDELAY = 1
FLUID_VOICE_ENVATTACK = 2
FLUID_VOICE_ENVHOLD = 3
FLUID_VOICE_ENVDECAY = 4
FLUID_VOICE_ENVSUSTAIN = 5
FLUID_VOICE_ENVRELEASE = 6
FLUID_VOICE_ENVFINISHED = 7

--[[ from SF 2.0 spec:	
	An envelope generates a control signal in six phases.  When key-on occurs, a delay period begins during which the envelope
value is zero.  The envelope then rises in a convex curve to a value of one during the attack phase.  When a value of one is
reached, the envelope enters a hold phase during which it remains at one.  When the hold phase ends, the envelope enters a
decay phase during which its value decreases linearly to a sustain level.  When the sustain level is reached, the envelope
enters sustain phase, during which the envelope stays at the sustain level.  Whenever a key-off occurs, the envelope
immediately enters a release phase during which the value linearly ramps from the current value to zero.  When zero is
reached, the envelope value remains at zero. 
--]]

ENVELOPE = {}
ENVELOPE.__index = ENVELOPE

function ENVELOPE:Reset()
	self.phase = FLUID_VOICE_ENVDELAY
	self.value = 1
	self.time = 0
end

function ENVELOPE:NoteOff()
	if self.phase == FLUID_VOICE_ENVRELEASE then return end
	self.data[FLUID_VOICE_ENVSUSTAIN].target = self.value
	self.phase = FLUID_VOICE_ENVRELEASE
	self.time = 0
end

function ENVELOPE:Tick(delta)
	self.time = self.time + delta
	-- ignoring delay and attack for now
	while (self.time > self.data[self.phase].time) do
		self.time = self.time - self.data[self.phase].time
		self.phase = self.phase + 1
	end
	local prev_target = self.phase > 1 and self.data[self.phase-1].target or 0
	local curdata = self.data[self.phase]
	self.value = Lerp(self.time / curdata.time, prev_target, curdata.target)
end

function _CreateEnvelope()
	local env = setmetatable({}, ENVELOPE)
	env.data = {
		{time = 0, target = 1}, -- delay
		{time = 0, target = 1}, -- attack
		{time = 0, target = 1}, -- hold
		{time = 0, target = 0}, -- decay
		{time = math.huge, target = 0}, -- sustain
		{time = 0, target = 0}, -- release
		{time = math.huge, target = 0} -- finished
	}
	
	env:Reset()
	return env
end
