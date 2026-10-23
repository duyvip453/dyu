local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt""))()

local Window = MacLib:Window({
	Title = "Porn hub",
	Subtitle = "by duy duy",
	Size = UDim2.fromOffset(868, 650),
	DragStyle = 1,
	DisabledWindowControls = {},
	ShowUserInfo = false,
	Keybind = Enum.KeyCode.RightControl,
	AcrylicBlur = true,
})
local tabGroups = {
	TabGroup1 = Window:TabGroup()
}

local tabs = {
	Farm = tabGroups.TabGroup1:Tab({ Name = "Farm"}
	Settings = tabGroups.TabGroup1:Tab({ Name = "Settings"}))
}

local sections = {
	FarmL = tabs.Farm:Section({ Side = "Left" }),
	FarmR = tabs.Farm:Section({ Side = "Right" })
}

sections.FarmL:Toggle({
	Name = "inf pet speed",
	Default = false,
	Callback = function(value)
    Scripts.infpetspeed(value)
end
		}, "infpetspeed")

MacLib:SetFolder("Maclib")
Window.onUnloaded(function()
	print("Unloaded!")
end)
MacLib:LoadAutoLoadConfig()
