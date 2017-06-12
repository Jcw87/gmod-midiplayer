AddCSLuaFile()

if not CLIENT then return end

local bit = bit
local string = string
local table = table

local error = error
local setmetatable = setmetatable

local file = file

local Msg = Msg
local MsgC = MsgC

local red = Color(255, 0, 0)
local green = Color(0, 255, 0)

module("midi")

local verbose = false

function printf(...) if verbose then Msg(string.format(...)) end end
function printf2(...) if verbose then MsgC(green, string.format(...)) end end
function warnf(...) MsgC(red, string.format(...)) end
function errorf(...) error(string.format(...), 2) end

local function readvlv(s)
	local value = 0
	while true do
		local byte = s:ReadUInt8()
		value = bit.lshift(value, 7) + bit.band(byte, 127)
		if byte < 128 then break end
	end
	return value
end

function _CreateMidi(data, name)
	local s = stream.wrap(data)
	local size = s:Size()
	
	local mid = {}
	
	-- read MIDI header
	local ident = s:Read(4)
	if ident ~= "MThd" then 
		errorf("File '%s' is not a midi file\n", name)
	end
	local headersize = s:ReadUInt32BE()
	if headersize ~= 6 then
		errorf("unknown header size in '%s'\n", name)
	end
	mid.type = s:ReadUInt16BE()
	if mid.type > 1 then
		errorf("unknown midi type %i in '%s'\n", mid.type, name)
	end
	local trackcount = s:ReadUInt16BE()
	mid.tpqn = s:ReadUInt16BE()
	local tracks = {}
	
	--printf("MIDI Header: ident = %s, size = %i, trackcount = %i, ticks per quarter note = %i\n", ident, headersize, trackcount, mid.tpqn)
	
	for i = 1, trackcount do
		-- read track header
		ident = s:Read(4)
		if ident ~= "MTrk" then 
			errorf("Error reading track %i in '%s'", i-1, name)
		end
		-- throw away track size, as many midi files have incorrect sizes.
		s:ReadUInt32BE()
		--printf("Reading MIDI track %i\n", i)
		local runningstatus = 0
		local ticks = 0
		local track = {}
		table.insert(tracks, track)
		while s:Tell() < size - 1 do
			local event = {}
			table.insert(track, event)
			local deltaticks = readvlv(s)
			ticks = ticks + deltaticks
			event.ticks = ticks
			--printf("Delta: %i ", deltaticks)
			local command = s:ReadUInt8()
			if command < 0x80 then
				command = runningstatus
				event.command = bit.band(command, 0xF0)
				event.channel = bit.band(command, 0x0F)
				s:Skip(-1)
			elseif command < 0xF0 then
				runningstatus = command
				event.command = bit.band(command, 0xF0)
				event.channel = bit.band(command, 0x0F)
			else
				event.command = command
			end
			if event.command == 0x80 then
				--note off
				event.key = s:ReadUInt8()
				event.velocity = s:ReadUInt8()
				--printf("Note off! key: %i, vel: %i\n", event.key, event.velocity)
			elseif event.command == 0x90 then
				-- note on
				event.key = s:ReadUInt8()
				event.velocity = s:ReadUInt8()
				--printf("Note on! key: %i, vel: %i\n", event.key, event.velocity)
			elseif event.command == 0xA0 then
				-- aftertouch
				event.key = s:ReadUInt8()
				event.velocity = s:ReadUInt8()
				--printf("Aftertouch! key: %i, vel: %i\n", event.key, event.velocity)
			elseif event.command == 0xB0 then
				-- control change
				event.control = s:ReadUInt8()
				event.value = s:ReadUInt8()
				--printf("Controller change! controller: %i, val: %i\n", event.controller, event.value)
			elseif event.command == 0xC0 then
				-- program change
				event.program = s:ReadUInt8()
				--printf("Program change! instrument: %i\n", event.program)
			elseif event.command == 0xD0 then
				-- channel aftertouch
				event.velocity = s:ReadUInt8()
				--printf("Channel aftertouch! vel: %i\n", event.velocity)
			elseif event.command == 0xE0 then
				-- pitch bend
				local b1 = s:ReadUInt8()
				local b2 = s:ReadUInt8()
				event.value = bit.band(b1, 127) + bit.lshift(b2, 7)
				--printf("Pitch bend! pitch: %i\n", event.value)
			elseif event.command == 0xF0 or event.command == 0xF7 then
				-- system event
				local length = readvlv(s)
				event.data = s:Read(length)
				--printf("System event! length: %i, data: %s\n", length, event.data)
			elseif event.command == 0xFF then
				-- meta event
				event.type = s:ReadUInt8()
				local length = readvlv(s)
				--printf("Meta event! type: %02x, len: %i\n", event.type, length)
				if event.type == 0x2F then
					-- end of track
					break
				elseif event.type == 0x51 then
					-- set tempo (microseconds per quarter note)
					event.tempo = s:ReadUInt24BE()
				else
					event.data = s:Read(length)
				end
			else
				errorf("unknown midi command %02x\n", command)
			end
		end
	end
	s:Close()
	
	mid.tracks = tracks
	
	return mid
end
