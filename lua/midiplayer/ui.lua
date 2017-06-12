AddCSLuaFile()

if not CLIENT then return end

local LEFT = LEFT
local RIGHT = RIGHT
local TOP = TOP
local FILL = FILL

local string = string

local hook = hook
local language = language
local spawnmenu = spawnmenu
local vgui = vgui
local timer = timer

module("midi")

language.Add("spawnmenu.utilities.midiplayer", "Midi Player")
language.Add("spawnmenu.utilities.midiplayer.control", "Control")

local icon_play = "icon16/control_play.png"
local icon_pause = "icon16/control_pause.png"
local icon_stop = "icon16/control_stop.png"

local function CPanel(cpanel)
	local function PlayDelay() timer.Simple(0, Play) end
	
	cpanel:Help("Control midi playback from here.")

	local seek = cpanel:NumSlider("Time", nil, 0, 0, 3)
	function seek:OnValueChanged(val) Seek(val) end
	cpanel:AddItem(seek)
	
	local controls = vgui.Create("DSizeToContents", cpanel)
	controls:Dock(TOP)
	controls:DockPadding(10, 10, 10, 0)
	
	local play = vgui.Create("DButton", controls)
	play:SetText("")
	play:SetSize(24, 24)
	play:SetMinimumSize(24, 24)
	play:Dock(LEFT)
	function play:DoClick() if IsPlaying() then Pause() else Play() end end
	
	local stop = vgui.Create("DButton", controls)
	stop:SetText("")
	stop:SetSize(24, 24)
	stop:SetMinimumSize(24, 24)
	stop:Dock(LEFT)
	stop:SetImage(icon_stop)
	function stop:DoClick() Stop() end
	
	local scale = cpanel:NumSlider("Timescale", nil, 0, 2, 3)
	function scale:OnValueChanged(val) SetTimescale(val) end
	
	local loop = cpanel:CheckBox("Loop")
	function loop:OnChange(bool) SetLoop(bool) end
	
	cpanel:Help("Load midi from a file.")
	
	local browser = vgui.Create("DFileBrowser_Midi", cpanel)
	browser:Dock(TOP)
	browser:DockPadding(10, 10, 10, 0)
	browser:SetMinimumSize(100, 200)
	browser:SetPath("GAME")
	browser:SetBaseFolder("")
	browser:SetName("root")
	browser:SetFileTypes( "*.mid" )
	function browser:OnDoubleClick(path, panel)
		LoadMidiFromFile(path)
		--use a timer to fix a problem with the first part of the midi playing too fast.
		PlayDelay()
	end
	
	cpanel:Help("Load midi from a url.")
	
	local urlloader = vgui.Create("DSizeToContents", cpanel)
	urlloader:Dock(TOP)
	urlloader:DockPadding(10, 10, 10, 0)
	
	local url = vgui.Create("DTextEntry", urlloader)
	url:Dock(FILL)
	url:SetText("http://www.midiarchive.co.uk/downloadfile/Games/Doom/Doom - E1M1.mid")
	local buttonurl = vgui.Create("DButton", urlloader)
	buttonurl:Dock(RIGHT)
	buttonurl:SetText("Load")
	function buttonurl:DoClick()
		LoadMidiFromUrl(url:GetText(), PlayDelay)
	end
	
	local function UpdateLength()
		local length = GetLength()
		seek:SetMax(length)
		local enable = length > 0
		play:SetEnabled(enable)
		stop:SetEnabled(enable)
		seek:SetEnabled(enable)
	end
	
	local function UpdatePlayState()
		play:SetImage(IsPlaying() and icon_pause or icon_play)
		seek:SetValue(Tell())
	end
	
	local function UpdatePos()
		seek:SetValue(Tell())
	end
	
	local function UpdateTimescale(val)
		scale:SetValue(val)
	end
	
	local function UpdateLoop(bool)
		loop:SetChecked(bool)
	end
	
	UpdateLength()
	UpdatePlayState()
	UpdatePos()
	UpdateTimescale(GetTimescale())
	UpdateLoop(GetLoop())
	
	hook.Add("MIDI.Load", "MidiPlayerCPanel", UpdateLength)
	hook.Add("MIDI.Play", "MidiPlayerCPanel", UpdatePlayState)
	hook.Add("MIDI.Pause", "MidiPlayerCPanel", UpdatePlayState)
	hook.Add("MIDI.Stop", "MidiPlayerCPanel", UpdatePlayState)
	hook.Add("MIDI.Tick", "MidiPlayerCPanel", UpdatePos)
	hook.Add("MIDI.Timescale", "MidiPlayerCPanel", UpdateTimescale)
	hook.Add("MIDI.Loop", "MidiPlayerCPanel", UpdateLoop)
end

local function AddToolMenuCategories()
	spawnmenu.AddToolCategory("Utilities", "MidiPlayer", "#spawnmenu.utilities.midiplayer")
end

local function PopulateToolMenu()
	spawnmenu.AddToolMenuOption("Utilities", "MidiPlayer", "MidiPlayerControl", "#spawnmenu.utilities.midiplayer.control", nil, nil, CPanel)
end

hook.Add("AddToolMenuCategories", "MidiPlayer", AddToolMenuCategories)
hook.Add("PopulateToolMenu", "MidiPlayer", PopulateToolMenu)

