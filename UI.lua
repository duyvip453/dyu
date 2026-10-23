local MacLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/event/refs/heads/main/maclib.lua"))()

local Window = Maclib:Window({
    Title = "porn hub",
    Subtitle = "duyduy",
    Size = UDim2.fromOffset(600, 400),
    DragStyle = 1,
    ShowUserInfo = false,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
    DisabledWindowControls = ("Exit", "Minimize")
})

local TabGroup = Window:TabGroup()

local Farm = TabGroup:Tab({
  Name = "Farm"
})
local FarmL = Farm:Section({
    Side = "Left"
})
local FarmR = Farm:Section({
    Side = "Right"
})

local scripts = loadstring(game:HttpGet("https://raw.githubusercontent.com/duyvip453/event/refs/heads/main/farm.lua"))()
FarmL:Toggle({
    Name = "inf pet speed",
    Default = false,
    Callback = scripts.infpetspeed
})
FarmL:Toggle({
    Name = "Auto tap",
    Default = false,
    Callback = scripts.autotap
})
FarmL:Toggle({
    Name = "Fast farm",
    Default = false,
    Callback = scripts.fastfarn
})
FarmL:Toggle({
    Name = "auto ultimate",
    Default = false,
    Callback = scripts.autoultimate
})
FarmR:Toggle({
    Name = "update pet slot",
    Default = false,
    Callback = scripts.petslot
})
FarmR:Toggle({
    Name = "update egg slot",
    Default = false,
    Callback = scripts.eggslot
})
