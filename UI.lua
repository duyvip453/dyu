local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

local Window = MacLib:Window({
	Title = "Porn hub",
	Subtitle = "duy duy",
	Size = UDim2.fromOffset(868, 650),
	DragStyle = 2,
	DisabledWindowControls = {},
	ShowUserInfo = false,
	Keybind = Enum.KeyCode.RightControl,
	AcrylicBlur = true,
})

local tabGroups = {
	TabGroup1 = Window:TabGroup()
}

local tabs = {
	Farm = tabGroups.TabGroup1:Tab({ Name = "Farm"})
}

local sections = {
	FarmL = tabs.Farm:Section({ Side = "Left" }),
	FarmR = tabs.Farm:Section({ Side = "Left" })
}

sections.FarmL:Toggle({
	Name = "Toggle",
	Default = false,
	Callback = function(value)
		Window:Notify({
			Title = Window.Settings.Title,
			Description = (value and "Enabled " or "Disabled ") .. "Toggle"
		})
	end,
}, "Toggle")

MacLib:SetFolder("Maclib")
tabs.Settings:InsertConfigSection("Left")

Window.onUnloaded(function()
	print("Unloaded!")
end)

tabs.Main:Select()
MacLib:LoadAutoLoadConfig()
