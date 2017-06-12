AddCSLuaFile()

if not CLIENT then return end

local math = math
local table = table

local type = type

local file = file
local hook = hook
local http = http

local GetTime = CurTime

module("midi")

local mid = nil

local function MergeTracks(tracks)
	local r = {}
	local indexes = {}
	for i = 1, #tracks do
		indexes[i] = 1
	end
	local trackend = -1
	while true do
		local lowest = math.huge
		local j = 0
		for i = 1, #tracks do
			local event = tracks[i][indexes[i]]
			if event and event.command == 0xFF and event.type == 0x2F then
				if event.ticks > trackend then trackend = event.ticks end
				indexes[i] = indexes[i] + 1
				continue
			end
			if not event then continue end
			local ticks = event.ticks
			if ticks < lowest then
				lowest = ticks
				j = i
			end
		end
		if j == 0 then break end
		table.insert(r, tracks[j][indexes[j]])
		indexes[j] = indexes[j] + 1
	end
	table.insert(r, {ticks = trackend, command = 0xFF, type = 0x2F})
	return r
end

local function CalcTimes(events)
	local lasttempo = 500000
	local time = 0
	local ticks = 0
	for i = 1, #events do
		local event = events[i]
		local tps = 1000000 * mid.tpqn / lasttempo
		time = time + (event.ticks - ticks) / tps
		ticks = event.ticks
		event.time = time
		if event.command == 0xFF and event.type == 0x51 then
			lasttempo = event.tempo
		end
	end
end

function LoadMidi(data, name)
	-- workshop file whitelist doesn't stop anyone from putting arbitrary files in the gma.
	-- it just makes things needlessly confusing.
	if not sf then LoadSF("lua/soundfont/default.sf2.lua") end
	
	Stop()
	
	mid = _CreateMidi(data, name)
	
	mid.events = MergeTracks(mid.tracks)
	CalcTimes(mid.events)
	SetTimescale(1)
	hook.Call("MIDI.Load")
end

function LoadMidiFromFile(fname)
	local s = stream.wrap(file.Open(fname, "rb", "GAME"))
	if not s then
		warnf("%s not found!\n", fname)
		return
	end
	
	local mididata = s:Read(s:Size())
	s:Close()
	
	LoadMidi(mididata, fname)
end

function LoadMidiFromUrl(url, callback)
	http.Fetch(url, function(data)
		LoadMidi(data, url)
		if callback then
			callback()
		end
	end, function(msg)
		error(msg)
	end)
end

local EventFuncs = {}
EventFuncs[0x80] = function(event) synth:NoteOff(event.channel+1, event.key) end
EventFuncs[0x90] = function(event) synth:NoteOn(event.channel+1, event.key, event.velocity) end
EventFuncs[0xA0] = function(event) synth:Aftertouch(event.channel+1, event.key, event.velocity) end
EventFuncs[0xB0] = function(event) synth:ControlChange(event.channel+1, event.control, event.value) end
EventFuncs[0xC0] = function(event) synth:ProgramChange(event.channel+1, event.program) end
EventFuncs[0xD0] = function(event) synth:ChannelAftertouch(event.channel+1, event.velocity) end
EventFuncs[0xE0] = function(event) synth:PitchBend(event.channel+1, event.value) end
EventFuncs[0xF0] = function(event) --[[system event]] end
EventFuncs[0xF7] = function(event) --[[system event]] end
EventFuncs[0xFF] = function(event)
	--tempo is already handled in CalcTimes
	if event.type == 0x51 then return end
	--warnf("Ignoring meta event: %i\n", event.type)
end

local playing = false
local looping = false
local timescale = 1
local eventindex = 1
local miditime = 0
local lasttime = 0

local function ResetVars()
	synth:Reset()
	eventindex = 1
	miditime = 0
end

local function MidiTick()
	if not mid or not playing then return end
	local thistime = GetTime()
	local delta = thistime - lasttime
	delta = delta * timescale
	
	synth:Tick(delta)
	
	miditime = miditime + delta
	
	while true do
		local event = mid.events[eventindex]
		if not event then
			if looping then ResetVars() else Stop() end
			return
		end
		if event.time > miditime then break end
		
		EventFuncs[event.command](event)
		
		eventindex = eventindex + 1
	end
	lasttime = thistime
	hook.Call("MIDI.Tick")
end
hook.Add("Think", "MidiPlayer", MidiTick)

function Play()
	lasttime = GetTime()
	playing = true
	hook.Call("MIDI.Play")
end

function Pause()
	synth:GlobalAllSoundOff()
	playing = false
	hook.Call("MIDI.Pause")
end

function Stop()
	synth:GlobalAllSoundOff()
	ResetVars()
	playing = false
	hook.Call("MIDI.Stop")
end

function Seek(time)
	if not mid then return end
	if time < 0 then time = 0 end
	if time == miditime then return end
	miditime = time
	eventindex = 1
	for i = 1, #mid.events do
		local event = mid.events[i]
		if event.time < time then
			eventindex = i
			if event.command ~= 0x80 and event.command ~= 0x90 then
				EventFuncs[event.command](event)
			end
		else
			break
		end
	end
	synth:GlobalAllSoundOff()
end

function Tell()
	if not mid then return 0 end
	return miditime
end

function GetLength()
	if not mid then return 0 end
	return mid.events[#mid.events].time
end

function GetLoop()
	return looping
end

function SetLoop(bool)
	if type(bool) ~= "boolean" then return end
	looping = bool
	hook.Call("MIDI.Loop", nil, bool)
end

function GetTimescale()
	return timescale
end

function SetTimescale(val)
	if type(val) ~= "number" then return end
	if val < 0 then return end
	if timescale == val then return end
	timescale = val
	hook.Call("MIDI.Timescale", nil, val)
end

function IsPlaying()
	return playing
end
