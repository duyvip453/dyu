local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()

local Window = Maclib:Window({
    Title = "porn hub",
    Subtitle = "duyduy",
    Size = UDim2.fromOffset(600, 400),
    DragStyle = 1,
    ShowUserInfo = false,
    Keybind = Enum.KeyCode.RightControl,
    AcrylicBlur = true
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

local 
