AddCSLuaFile()

if not CLIENT then return end

local bit = bit
local math = math
local string = string
local table = table

local file = file

module("midi")

SF = SF or {}

local rates = {
	11025,
	22050,
	44100,
}

local function GetNewRate(rate)
	local newrate = rates[1]
	for i = 1, #rates do
		if rate > rates[i] then newrate = rates[i] end
	end
	return newrate
end

local function Coeff(x)
	local c1 = x * (-0.5 + x * (1 - 0.5 * x))
	local c2 = 1.0 + x * x * (1.5 * x - 2.5)
	local c3 = x * (0.5 + x * (2.0 - 1.5 * x))
	local c4 = 0.5 * x * x * (x - 1.0)
	return c1, c2, c3, c4
end

local function Resample(data, rate, newrate)
	local in_count = #data / 2
	local in_data = {}
	for i = 1, in_count do
		local b1, b2 = string.byte(data, i*2-1, i*2)
		if b2 > 127 then b2 = b2 - 256 end
		in_data[i] = b1 + b2*256
	end
	local out_count = math.floor(in_count * newrate / rate)
	local out_data = {}
	for out_pos = 1, out_count do
		local in_pos = (out_pos-1) * rate / newrate + 1
		local i = math.floor(in_pos)
		
		local p1 = in_data[i-1] or in_data[1]
		local p2 = in_data[i]
		local p3 = in_data[i+1] or in_data[in_count]
		local p4 = in_data[i+2] or in_data[in_count]
		
		local c1, c2, c3, c4 = Coeff(in_pos - i)
		
		out_data[out_pos] = math.floor(p1*c1 + p2*c2 + p3*c3 + p4*c4)
		out_data[out_pos] = math.min(math.max(out_data[out_pos], -32768), 32767)
		local unsigned = bit.band(out_data[out_pos], 65535)
		local b1 = bit.band(unsigned, 255)
		local b2 = bit.rshift(unsigned, 8)
		out_data[out_pos] = string.char(b1, b2)
	end
	return table.concat(out_data)
end

function SF:DumpSample(idx, loop)
	local sample = self.samples[idx]
	printf("Dumping sample %3i: %-20s %s\n", sample.id, sample.name, loop and "looped" or "")
	local startloop = sample.startloop - sample.start
	local endloop = sample.endloop - sample.start
	local data = string.sub(sf.sampledata, sample.start*2+1, (sample.endloop+1)*2)
	local rate = sample.samplerate
	if rate ~= 44100 and rate ~= 22050 and rate ~= 11025 then
		local newrate = GetNewRate(rate)
		data = Resample(data, rate, newrate)
		startloop = math.floor(startloop * newrate / rate)
		endloop = math.floor(endloop * newrate / rate)
		rate = newrate
	end
	
	local f = file.Open(string.format("%s/%i.wav.txt", sf.name, sample.id), "wb", "DATA")
	
	local smpllen = 36
	if loop then smpllen = smpllen + 24 end
	
	local rifflen = 4 + 24 + 8 + smpllen + 8 + #data
	
	f:Write("RIFF") -- id
	f:WriteLong(rifflen) -- size
	f:Write("WAVE") -- 4 bytes
	
	-- fmt chunk: 24 bytes
	f:Write("fmt ") -- id
	f:WriteLong(16) -- size
	f:WriteShort(1) -- format (1 = PCM)
	f:WriteShort(1) -- channels
	f:WriteLong(rate) -- sample rate
	f:WriteLong(rate*2) -- byte rate
	f:WriteShort(2) -- block align
	f:WriteShort(16) -- bits per sample
	
	-- smpl chunk header: 44 bytes
	f:Write("smpl") -- id
	f:WriteLong(smpllen) -- size
	f:WriteLong(0) -- manufacturer id
	f:WriteLong(0) -- product id
	f:WriteLong(math.floor(1000000000 / rate)) -- sample period (nanoseconds)
	f:WriteLong(sample.rootkey)
	f:WriteLong(0)
	f:WriteLong(0)
	f:WriteLong(0)
	f:WriteLong(loop and 1 or 0) -- num sample loop structs
	f:WriteLong(0)
	
	-- loop struct: 24 bytes
	if loop then
		f:WriteLong(0) -- id
		f:WriteLong(0) -- loop type
		f:WriteLong(startloop) -- loop start
		f:WriteLong(endloop)
		f:WriteLong(0)
		f:WriteLong(0) -- loop count
	end
	
	-- data chunk: 8 + sample data bytes
	f:Write("data") -- id
	f:WriteLong(#data) -- size
	f:Write(data)
	
	f:Close()
end

function SF:DumpSamples()
	local s_loops = {}
	for i = 1, #self.instruments do
		local inst = self.instruments[i]
		for j = 1, #inst.bags do
			local ibag = inst.bags[j]
			local ibag_gen = ibag.gens[GEN.SAMPLEMODE] or (inst.glob_bag and inst.glob_bag.gens[GEN.SAMPLEMODE]) or 0
			if ibag_gen > 0 then s_loops[ibag.sample.id+1] = true end
		end
	end
	
	file.CreateDir(self.name)
	for i = 1, #self.samples do
		self:DumpSample(i, s_loops[i])
	end
end