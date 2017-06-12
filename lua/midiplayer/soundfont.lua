AddCSLuaFile()

if not CLIENT then return end

local bit = bit
local string = string
local table = table

local setmetatable = setmetatable

local file = file
local sound = sound

local function cstr(str) return string.match(str, "(.-)%z") end

module("midi")

GEN = {}
GEN.STARTADDROFS = 0
GEN.ENDADDROFS = 1
GEN.STARTLOOPADDROFS = 2
GEN.ENDLOOPADDROFS = 3
GEN.STARTADDRCOARSEOFS = 4
GEN.MODLFOTOPITCH = 5
GEN.VIBLFOTOPITCH = 6
GEN.MODENVTOPITCH = 7
GEN.FILTERFC = 8
GEN.FILTERQ = 9
GEN.MODLFOTOFILTERFC = 10
GEN.MODENVTOFILTERFC = 11
GEN.ENDADDRCOARSEOFS = 12
GEN.MODLFOTOVOL = 13
GEN.UNUSED1 = 14
GEN.CHORUSSEND = 15
GEN.REVERBSEND = 16
GEN.PAN = 17
GEN.UNUSED2 = 18
GEN.UNUSED3 = 19
GEN.UNUSED4 = 20
GEN.MODLFODELAY = 21
GEN.MODLFOFREQ = 22
GEN.VIBLFODELAY = 23
GEN.VIBLFOFREQ = 24
GEN.MODENVDELAY = 25
GEN.MODENVATTACK = 26
GEN.MODENVHOLD = 27
GEN.MODENVDECAY = 28
GEN.MODENVSUSTAIN = 29
GEN.MODENVRELEASE = 30
GEN.KEYTOMODENVHOLD = 31
GEN.KEYTOMODENVDECAY = 32
GEN.VOLENVDELAY = 33
GEN.VOLENVATTACK = 34
GEN.VOLENVHOLD = 35
GEN.VOLENVDECAY = 36
GEN.VOLENVSUSTAIN = 37
GEN.VOLENVRELEASE = 38
GEN.KEYTOVOLENVHOLD = 39
GEN.KEYTOVOLENVDECAY = 40
GEN.INSTRUMENT = 41
GEN.RESERVED1 = 42
GEN.KEYRANGE = 43
GEN.VELRANGE = 44
GEN.STARTLOOPADDRCOARSEOFS = 45
GEN.KEYNUM = 46
GEN.VELOCITY = 47
GEN.ATTENUATION = 48
GEN.RESERVED2 = 49
GEN.ENDLOOPADDRCOARSEOFS = 50
GEN.COARSETUNE = 51
GEN.FINETUNE = 52
GEN.SAMPLEID = 53
GEN.SAMPLEMODE = 54
GEN.RESERVED3 = 55
GEN.SCALETUNE = 56
GEN.EXCLUSIVECLASS = 57
GEN.OVERRIDEROOTKEY = 58
GEN.LAST = 59

local igens_default = {}
igens_default.__index = igens_default
igens_default[GEN.STARTADDROFS] = 0
igens_default[GEN.ENDADDROFS] = 0
igens_default[GEN.STARTLOOPADDROFS] = 0
igens_default[GEN.ENDLOOPADDROFS] = 0
igens_default[GEN.STARTADDRCOARSEOFS] = 0
igens_default[GEN.MODLFOTOPITCH] = 0
igens_default[GEN.VIBLFOTOPITCH] = 0
igens_default[GEN.MODENVTOPITCH] = 0
igens_default[GEN.FILTERFC] = 13500
igens_default[GEN.FILTERQ] = 0
igens_default[GEN.MODLFOTOFILTERFC] = 0
igens_default[GEN.MODENVTOFILTERFC] = 0
igens_default[GEN.ENDADDRCOARSEOFS] = 0
igens_default[GEN.MODLFOTOVOL] = 0
igens_default[GEN.UNUSED1] = 0
igens_default[GEN.CHORUSSEND] = 0
igens_default[GEN.REVERBSEND] = 0
igens_default[GEN.PAN] = 0
igens_default[GEN.UNUSED2] = 0
igens_default[GEN.UNUSED3] = 0
igens_default[GEN.UNUSED4] = 0
igens_default[GEN.MODLFODELAY] = -12000
igens_default[GEN.MODLFOFREQ] = 0
igens_default[GEN.VIBLFODELAY] = -12000
igens_default[GEN.VIBLFOFREQ] = 0
igens_default[GEN.MODENVDELAY] = -12000
igens_default[GEN.MODENVATTACK] = -12000
igens_default[GEN.MODENVHOLD] = -12000
igens_default[GEN.MODENVDECAY] = -12000
igens_default[GEN.MODENVSUSTAIN] = 0
igens_default[GEN.MODENVRELEASE] = -12000
igens_default[GEN.KEYTOMODENVHOLD] = 0
igens_default[GEN.KEYTOMODENVDECAY] = 0
igens_default[GEN.VOLENVDELAY] = -12000
igens_default[GEN.VOLENVATTACK] = -12000
igens_default[GEN.VOLENVHOLD] = -12000
igens_default[GEN.VOLENVDECAY] = -12000
igens_default[GEN.VOLENVSUSTAIN] = 0
igens_default[GEN.VOLENVRELEASE] = -12000
igens_default[GEN.KEYTOVOLENVHOLD] = 0
igens_default[GEN.KEYTOVOLENVDECAY] = 0
igens_default[GEN.RESERVED1] = 0
igens_default[GEN.STARTLOOPADDRCOARSEOFS] = 0
igens_default[GEN.ATTENUATION] = 0
igens_default[GEN.RESERVED2] = 0
igens_default[GEN.ENDLOOPADDRCOARSEOFS] = 0
igens_default[GEN.COARSETUNE] = 0
igens_default[GEN.FINETUNE] = 0
igens_default[GEN.SAMPLEMODE] = 0
igens_default[GEN.RESERVED3] = 0
igens_default[GEN.SCALETUNE] = 100
igens_default[GEN.EXCLUSIVECLASS] = 0

local funcs = {}
local function RIFFChunk(s)
	local ch = {}
	ch.id = s:Read(4)
	ch.size = s:ReadUInt32LE()
	ch.start = s:Tell()
	printf("Reading SoundFont chunk '%s' at offset '%i' with size '%i'\n", ch.id, ch.start, ch.size)
	if not funcs[ch.id] then errorf("Unknown chunk '%s'", ch.id) end
	local sub = funcs[ch.id](s, ch)
	local name = ch.id
	if name == "LIST" then name = ch.listname end
	if (ch.size % 2 > 0) then s:Seek(ch.start+ch.size+1) else s:Seek(ch.start+ch.size) end
	return sub, name
end

local function SubChunks(s, ch)
	while s:Tell() < ch.start + ch.size do
		local sub, name = RIFFChunk(s)
		ch[name] = sub
	end
end

local function VersionChunk(s, ch)
	local s1 = s:ReadUInt16LE()
	local s2 = s:ReadUInt16LE()
	return string.format("%i.%02i", s1, s2)
end

local function StringChunk(s, ch)
	return s:Read(ch.size)
end

funcs["RIFF"] = function(s, ch)
	local fourcc = s:Read(4)
	if fourcc ~= "sfbk" then errorf("File '%s' is not a soundfont!", fname) end
	SubChunks(s, ch)
	return ch
end
funcs["LIST"] = function(s, ch)
	ch.listname = s:Read(4)
	SubChunks(s, ch)
	return ch
end
funcs["ifil"] = VersionChunk
funcs["isng"] = StringChunk
funcs["irom"] = StringChunk
funcs["iver"] = VersionChunk
funcs["INAM"] = StringChunk
funcs["ICRD"] = StringChunk
funcs["IENG"] = StringChunk
funcs["IPRD"] = StringChunk
funcs["ICOP"] = StringChunk
funcs["ICMT"] = StringChunk
funcs["ISFT"] = StringChunk
funcs["smpl"] = function(s, ch)
	--printf("smpl chunk: %i bytes\n", ch.size)
	return s:Read(ch.size)
end
funcs["sm24"] = function(s, ch)
	printf("sm24 chunk: %i bytes\n", ch.size)
	--return s:Read(ch.size)
end
funcs["phdr"] = function(s, ch)
	local count = ch.size / 38
	while s:Tell() < ch.start + ch.size do
		local h = {}
		h.name = cstr(s:Read(20))
		h.num = s:ReadUInt16LE()
		h.bank = s:ReadUInt16LE()
		h.bagidx = s:ReadUInt16LE()
		h.library = s:ReadUInt32LE()
		h.genre = s:ReadUInt32LE()
		h.morphology = s:ReadUInt32LE()
		table.insert(ch, h)
	end
	return ch
end
funcs["pbag"] = function(s, ch)
	local count = ch.size / 4
	while s:Tell() < ch.start + ch.size do
		local b = {}
		b.genidx = s:ReadUInt16LE()
		b.modidx = s:ReadUInt16LE()
		table.insert(ch, b)
	end
	return ch
end
funcs["pmod"] = function(s, ch) end
funcs["pgen"] = function(s, ch)
	local count = ch.size / 4
	while s:Tell() < ch.start + ch.size do
		local g = {}
		g.oper = s:ReadUInt16LE()
		g.amount = s:ReadSInt16LE()
		table.insert(ch, g)
	end
	return ch
end
funcs["inst"] = function(s, ch)
	local count = ch.size / 22
	while s:Tell() < ch.start + ch.size do
		local i = {}
		i.name = cstr(s:Read(20))
		i.bagidx = s:ReadUInt16LE()
		table.insert(ch, i)
	end
	return ch
end
funcs["ibag"] = funcs["pbag"]
funcs["imod"] = funcs["pmod"]
funcs["igen"] = funcs["pgen"]
funcs["shdr"] = function(s, ch)
	local count = ch.size / 46
	while s:Tell() < ch.start + ch.size do
		local h = {}
		h.name = cstr(s:Read(20)..string.char(0))
		h.start = s:ReadUInt32LE()
		h.finish = s:ReadUInt32LE()
		h.startloop = s:ReadUInt32LE()
		h.endloop = s:ReadUInt32LE()
		h.samplerate = s:ReadUInt32LE()
		h.rootkey = s:ReadUInt8()
		h.pitchcorrection = s:ReadSInt8()
		h.samplelink = s:ReadUInt16LE()
		h.sampletype = s:ReadUInt16LE()
		h.time = (h.finish - h.start) / h.samplerate
		table.insert(ch, h)
	end
	return ch
end

--local sf

SF = SF or {}
SF.__index = SF

function SF:GetPreset(bank, program)
	for i = 1, #self.presets do
		local preset = self.presets[i]
		if preset.bank == bank and preset.num == program then
			return preset
		end
	end
	if bank == 128 then 
		if program ~= 0 then return self:GetPreset(bank, 0) end
	else
		if bank ~= 0 then return self:GetPreset(0, program) end
		if program ~= 0 then return self:GetPreset(bank, 0) end
	end
end

local BAG = {}
BAG.__index = BAG

function BAG:InRange(key, vel)
	if key < self.keylo or key > self.keyhi then return false end
	if vel < self.vello or vel > self.velhi then return false end
	return true
end

local function trimfilename(path)
	local filename = string.match(path, "([^/]*)$")
	local ext = string.match(filename, "%.([^.]+)$")
	if ext == "lua" then return string.match(filename, "(.+)%.[^.]+$") end
	return filename
end

function LoadSF(fname)
	local f = file.Open(fname, "rb", "GAME")
	if not f then
		warnf("%s not found!\n", fname)
		return
	end
	local data = f:Read(f:Size())
	f:Close()
	local s = stream.wrap(data)
	printf("Loading soundfont '%s' with size '%i'\n", fname, s:Size())
	local riff = RIFFChunk(s)
	s:Close()
	
	local name = trimfilename(fname)
	
	sf = setmetatable({}, SF)
	sf.name = name
	sf.sampledata = riff.sdta.smpl
	sf.samples = riff.pdta.shdr
	table.remove(sf.samples)
	for i = 1, #sf.samples do
		local sample = sf.samples[i]
		sample.id = i-1
		-- leading the name with '#' makes the sound ignore dsp effects.
		-- With a soundlevel of 0, it is also affected by the music volume.
		-- Other effects can be found in public/soundchars.h
		sample.enginename = string.lower(string.format("#soundfont/%s/%i.wav", sf.name, sample.id))
		local genfunc = function(pos)
			local idx = sample.start + pos
			local b1 = string.byte(sf.sampledata, idx*2+1) or 0
			local b2 = string.byte(sf.sampledata, idx*2+2) or 0
			if b2 > 127 then b2 = b2 - 256 end
			local ret = (b1 + b2 * 256) / 32768
			--printf("pos: %i sample: %f\n", pos, ret)
			return ret
		end
		local finish = (sample.endloop+1)
		local len = (finish - sample.start) / sample.samplerate
		--printf("Creating sound with name: %s rate: %i length: %f\n", sample.enginename, sample.samplerate, len)
		--sound.Generate(sample.enginename, sample.samplerate, len, genfunc)
	end

	local instruments = {}
	for ii = 1, #riff.pdta.inst-1 do
		local inst_riff = riff.pdta.inst[ii]
		local inst = {}
		inst.name = inst_riff.name
		local bagstart = inst_riff.bagidx+1
		local bagend = riff.pdta.inst[ii+1].bagidx
		local bags = {}
		local gens_global = igens_default;
		for bi = bagstart, bagend do
			local bag_riff = riff.pdta.ibag[bi]
			local bag = setmetatable({}, BAG)
			bag.keylo = 0
			bag.keyhi = 127
			bag.vello = 0
			bag.velhi = 127
			local gens = setmetatable({}, gens_global)
			for gi = bag_riff.genidx+1, riff.pdta.ibag[bi+1].genidx do
				local gen_riff = riff.pdta.igen[gi]
				if gen_riff.oper == GEN.KEYRANGE then
					bag.keylo = bit.band(gen_riff.amount, 0xFF)
					bag.keyhi = bit.rshift(gen_riff.amount, 8)
					continue
				end
				if gen_riff.oper == GEN.VELRANGE then
					bag.vello = bit.band(gen_riff.amount, 0xFF)
					bag.velhi = bit.rshift(gen_riff.amount, 8)
					continue
				end
				gens[gen_riff.oper] = gen_riff.amount
			end
			
			local sampleid = gens[GEN.SAMPLEID]
			if sampleid then bag.sample = sf.samples[sampleid+1] end
			if bi == bagstart and not sampleid then
				gens.__index = gens
				gens_global = gens
			end
			
			bag.gens = gens
			table.insert(bags, bag)
		end
		inst.bags = bags
		instruments[ii] = inst
	end
	sf.instruments = instruments
	
	local presets = {}
	for pi = 1, #riff.pdta.phdr-1 do
		local preset_riff = riff.pdta.phdr[pi]
		local preset = {}
		preset.name = preset_riff.name
		preset.num = preset_riff.num
		preset.bank = preset_riff.bank
		local bagstart = preset_riff.bagidx+1
		local bagend = riff.pdta.phdr[pi+1].bagidx
		local bags = {}
		local gens_global = nil;
		for bi = bagstart, bagend do
			local bag_riff = riff.pdta.pbag[bi]
			local bag = setmetatable({}, BAG)
			bag.keylo = 0
			bag.keyhi = 127
			bag.vello = 0
			bag.velhi = 127
			local gens = setmetatable({}, gens_global)
			for gi = bag_riff.genidx+1, riff.pdta.pbag[bi+1].genidx do
				local gen_riff = riff.pdta.pgen[gi]
				if gen_riff.oper == GEN.KEYRANGE then
					bag.keylo = bit.band(gen_riff.amount, 0xFF)
					bag.keyhi = bit.rshift(gen_riff.amount, 8)
					continue
				end
				if gen_riff.oper == GEN.VELRANGE then
					bag.vello = bit.band(gen_riff.amount, 0xFF)
					bag.velhi = bit.rshift(gen_riff.amount, 8)
					continue
				end
				gens[gen_riff.oper] = gen_riff.amount
			end
			
			local instid = gens[GEN.INSTRUMENT]
			if instid then bag.instrument = sf.instruments[instid+1] end
			if bi == bagstart and not instid then
				gens.__index = gens
				gens_global = gens
			end
			
			bag.gens = gens
			table.insert(bags, bag)
		end
		preset.bags = bags
		
		presets[pi] = preset
	end
	sf.presets = presets
	
	printf("midiplayer: Soundfont %s loaded!\n", sf.name)
end
