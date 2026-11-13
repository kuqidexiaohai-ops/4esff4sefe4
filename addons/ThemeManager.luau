local HttpService: HttpService = game:GetService("HttpService")

local cloneref = cloneref or clonereference or function(Instance: any)
    return Instance
end

HttpService = cloneref(HttpService)

local clonefunction = clonefunction or copyfunction or function(Function)
    return Function
end

local IsFolderFunction = isfolder
local IsFileFunction = isfile
local ListFilesFunction = listfiles
local IsFolderCopy = clonefunction(IsFolderFunction)
local IsFileCopy = clonefunction(IsFileFunction)
local ListFilesCopy = clonefunction(ListFilesFunction)
local IsFolderWorks, IsFolderResult = pcall(function()
    return IsFolderCopy("test" .. tostring(math.random(1000000, 9999999)))
end)

if not IsFolderWorks or typeof(IsFolderResult) ~= "boolean" then
    isfolder = function(Folder)
        local Success, Result = pcall(IsFolderCopy, Folder)
        return Success and Result or false
    end
    isfile = function(File)
        local Success, Result = pcall(IsFileCopy, File)
        return Success and Result or false
    end
    listfiles = function(Folder)
        local Success, Result = pcall(ListFilesCopy, Folder)
        return Success and typeof(Result) == "table" and Result or {}
    end
end

local ContrastWarnThreshold = 4.5
local SrgbLinearThreshold = 0.03928
local SrgbLinearDivisor = 12.92
local SrgbGammaOffset = 0.055
local SrgbGammaScale = 1.055
local SrgbGammaExponent = 2.4
local LuminanceRedWeight, LuminanceGreenWeight, LuminanceBlueWeight = 0.2126, 0.7152, 0.0722
local ContrastRatioOffset = 0.05

local SchemeIndexes = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }
local DefaultFolder = "ObsidianLibSettings"

local ThemeManager = {
    Library = nil,
    Folder = DefaultFolder,
    AppliedToTab = false,
    DefaultThemeName = nil,
    ContrastLabel = nil,
    ContrastWasPoor = false,
    BuiltInThemes = {
        ["Default"] = { 1, { FontColor = "ffffff", MainColor = "191919", AccentColor = "7d55ff", BackgroundColor = "0f0f0f", OutlineColor = "282828" } },
        ["BBot"] = { 2, { FontColor = "ffffff", MainColor = "1e1e1e", AccentColor = "7e48a3", BackgroundColor = "232323", OutlineColor = "141414" } },
        ["Fatality"] = { 3, { FontColor = "ffffff", MainColor = "1e1842", AccentColor = "c50754", BackgroundColor = "191335", OutlineColor = "3c355d" } },
        ["Jester"] = { 4, { FontColor = "ffffff", MainColor = "242424", AccentColor = "db4467", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
        ["Mint"] = { 5, { FontColor = "ffffff", MainColor = "242424", AccentColor = "3db488", BackgroundColor = "1c1c1c", OutlineColor = "373737" } },
        ["Tokyo Night"] = { 6, { FontColor = "ffffff", MainColor = "191925", AccentColor = "6759b3", BackgroundColor = "16161f", OutlineColor = "323232" } },
        ["Ubuntu"] = { 7, { FontColor = "ffffff", MainColor = "3e3e3e", AccentColor = "e2581e", BackgroundColor = "323232", OutlineColor = "191919" } },
        ["Quartz"] = { 8, { FontColor = "ffffff", MainColor = "232330", AccentColor = "426e87", BackgroundColor = "1d1b26", OutlineColor = "27232f" } },
        ["Nord"] = { 9, { FontColor = "eceff4", MainColor = "3b4252", AccentColor = "88c0d0", BackgroundColor = "2e3440", OutlineColor = "4c566a" } },
        ["Dracula"] = { 10, { FontColor = "f8f8f2", MainColor = "44475a", AccentColor = "ff79c6", BackgroundColor = "282a36", OutlineColor = "6272a4" } },
        ["Monokai"] = { 11, { FontColor = "f8f8f2", MainColor = "272822", AccentColor = "f92672", BackgroundColor = "1e1f1c", OutlineColor = "49483e" } },
        ["Gruvbox"] = { 12, { FontColor = "ebdbb2", MainColor = "3c3836", AccentColor = "fb4934", BackgroundColor = "282828", OutlineColor = "504945" } },
        ["Solarized"] = { 13, { FontColor = "839496", MainColor = "073642", AccentColor = "cb4b16", BackgroundColor = "002b36", OutlineColor = "586e75" } },
        ["Catppuccin"] = { 14, { FontColor = "d9e0ee", MainColor = "302d41", AccentColor = "f5c2e7", BackgroundColor = "1e1e2e", OutlineColor = "575268" } },
        ["One Dark"] = { 15, { FontColor = "abb2bf", MainColor = "282c34", AccentColor = "c678dd", BackgroundColor = "21252b", OutlineColor = "5c6370" } },
        ["Cyberpunk"] = { 16, { FontColor = "f9f9f9", MainColor = "262335", AccentColor = "00ff9f", BackgroundColor = "1a1a2e", OutlineColor = "413c5e" } },
        ["Oceanic Next"] = { 17, { FontColor = "d8dee9", MainColor = "1b2b34", AccentColor = "6699cc", BackgroundColor = "16232a", OutlineColor = "343d46" } },
        ["Material"] = { 18, { FontColor = "eeffff", MainColor = "212121", AccentColor = "82aaff", BackgroundColor = "151515", OutlineColor = "424242" } },
    }
}

function ThemeManager:SetLibrary(Library)
    ThemeManager.Library = Library
end

local function Trim(Text: string)
    return Text:match("^%s*(.-)%s*$")
end

local function IsStringEmpty(String: string): boolean
    return if typeof(String) == "string" then Trim(String) == "" else true
end

local function IsValidFolderPath(Name: string): boolean
    return typeof(Name) == "string" and Trim(Name) ~= "" and not Name:find('[<>:"|%?%*%z]')
end

local function GetThemesPath(): string?
    if IsStringEmpty(ThemeManager.Folder) then
        return nil
    end
    return string.format("%s/themes", ThemeManager.Folder)
end

local function GetDefaultThemePath(): string?
    local Path = GetThemesPath()
    return Path and string.format("%s/default.txt", Path) or nil
end

local function IsValidThemeData(Data: any): boolean
    if typeof(Data) ~= "table" then
        return false
    end

    for _, SchemeIndex in SchemeIndexes do
        if typeof(Data[SchemeIndex]) ~= "string" then
            return false
        end
    end

    return true
end

local function EnsureThemesFolder(): string?
    local ThemesPath = GetThemesPath()
    if not ThemesPath then
        return nil
    end

    local CurrentPath = ""
    for Part in string.gmatch(ThemeManager.Folder, "[^/]+") do
        CurrentPath = if CurrentPath == "" then Part else CurrentPath .. "/" .. Part
        if not isfolder(CurrentPath) then
            pcall(makefolder, CurrentPath)
        end
    end
    if not isfolder(ThemesPath) then
        pcall(makefolder, ThemesPath)
    end

    return ThemesPath
end

local function GetThemePath(ThemeName: string): string?
    local ThemesPath = EnsureThemesFolder()
    if not ThemesPath then
        return nil
    end

    return string.format("%s/%s.json", ThemesPath, ThemeName)
end

local function BuildCurrentThemeData(): {[string]: any}
    local Library = ThemeManager.Library
    local ThemeData = {}

    for _, SchemeIndex in SchemeIndexes do
        ThemeData[SchemeIndex] = Library.Options[SchemeIndex].Value:ToHex()
    end

    return ThemeData
end

local function LinearizeChannel(Channel: number): number
    if Channel <= SrgbLinearThreshold then
        return Channel / SrgbLinearDivisor
    end
    return ((Channel + SrgbGammaOffset) / SrgbGammaScale) ^ SrgbGammaExponent
end

local function GetRelativeLuminance(Color: Color3): number
    return LuminanceRedWeight * LinearizeChannel(Color.R)
        + LuminanceGreenWeight * LinearizeChannel(Color.G)
        + LuminanceBlueWeight * LinearizeChannel(Color.B)
end

function ThemeManager:GetContrastReport(): { Ratio: number, PairName: string, Passes: boolean }
    local Library = ThemeManager.Library
    local FontColor = Library.Options.FontColor.Value
    local Surfaces = {
        { Name = "背景色", Color = Library.Options.BackgroundColor.Value },
        { Name = "主色", Color = Library.Options.MainColor.Value },
    }
    local WorstRatio, WorstName = math.huge, ""
    for _, Surface in Surfaces do
        local A, B = GetRelativeLuminance(FontColor), GetRelativeLuminance(Surface.Color)
        local Ratio = (math.max(A, B) + ContrastRatioOffset) / (math.min(A, B) + ContrastRatioOffset)
        if Ratio < WorstRatio then WorstRatio, WorstName = Ratio, Surface.Name end
    end
    return { Ratio = WorstRatio, PairName = WorstName, Passes = WorstRatio >= ContrastWarnThreshold }
end

function ThemeManager:UpdateContrastWarning()
    local Label = ThemeManager.ContrastLabel
    if not Label or Label.Destroyed then return end
    local Library = ThemeManager.Library
    local Report = ThemeManager:GetContrastReport()
    local TextLabel = Label.TextLabel
    if Report.Passes then
        Label:SetText(string.format("对比度检查：良好（%.1f:1）", Report.Ratio))
        TextLabel.TextColor3 = Library.Scheme.FontColor
        Library.Registry[TextLabel].TextColor3 = "FontColor"
    else
        Label:SetText(string.format("%s对比度偏低（%.1f:1），建议至少 %.1f:1。", Report.PairName, Report.Ratio, ContrastWarnThreshold))
        TextLabel.TextColor3 = Library.Scheme.RedColor
        Library.Registry[TextLabel].TextColor3 = "RedColor"
        if not ThemeManager.ContrastWasPoor then
            Library:Notify({ Title = "主题对比度偏低", Description = "当前文字可能不易辨认，请调整字体色或背景色。", Time = 10 })
        end
    end
    ThemeManager.ContrastWasPoor = not Report.Passes
end

function ThemeManager:ThemeUpdate()
    local Library = ThemeManager.Library
    for _, SchemeIndex in SchemeIndexes do
        local Element = Library.Options[SchemeIndex]
        if Element then Library.Scheme[SchemeIndex] = Element.Value end
    end
    Library:UpdateColorsUsingRegistry()
    ThemeManager:UpdateContrastWarning()
end

function ThemeManager:SetFolder(Folder: string)
    assert(IsValidFolderPath(Folder), "主题文件夹路径无效")
    ThemeManager.Folder = Folder
    EnsureThemesFolder()
end

function ThemeManager:ReloadCustomThemes(): {string}
    local ThemesPath = EnsureThemesFolder()
    if not ThemesPath then
        return {}
    end

    local Success, Files = pcall(listfiles, ThemesPath)
    if not Success or typeof(Files) ~= "table" then
        return {}
    end

    local Names = {}
    for _, FilePath in Files do
        local Name = tostring(FilePath):gsub("\\\\", "/"):match("([^/]+)%.json$")
        if Name then
            table.insert(Names, Name)
        end
    end
    table.sort(Names)
    return Names
end

function ThemeManager:GetCustomTheme(ThemeName: string): any
    local Path = GetThemePath(ThemeName)
    if not Path or not isfile(Path) then
        return nil
    end

    local Success, Content = pcall(readfile, Path)
    if not Success then
        return nil
    end

    local DecodedSuccess, Data = pcall(HttpService.JSONDecode, HttpService, Content)
    return DecodedSuccess and IsValidThemeData(Data) and Data or nil
end

function ThemeManager:SaveCustomTheme(ThemeName: string): (boolean, string?)
    if IsStringEmpty(ThemeName) or ThemeName:find("[/\\\\]") or string.lower(ThemeName) == "default" then
        return false, "主题名称无效"
    end

    local Path = GetThemePath(ThemeName)
    if not Path then
        return false, "主题目录无效"
    end

    local Content, Success, ErrorMessage = ThemeManager:SaveJSON()
    if not Success then
        return false, ErrorMessage
    end

    local WriteSuccess, WriteError = pcall(writefile, Path, Content)
    if not WriteSuccess then
        return false, tostring(WriteError)
    end

    return true
end

function ThemeManager:ApplyTheme(ThemeName: string): (boolean, string?)
    if IsStringEmpty(ThemeName) then
        return false, "未选择主题"
    end

    local CustomData = ThemeManager:GetCustomTheme(ThemeName)
    local BuiltInData = ThemeManager.BuiltInThemes[ThemeName]
    local Data = CustomData or (BuiltInData and BuiltInData[2])
    if not Data then
        return false, "找不到该主题配置"
    end
    return ThemeManager:ApplyThemeData(Data)
end

function ThemeManager:GetDefaultTheme(): (string, boolean, string?)
    local Path = GetDefaultThemePath()
    if not Path then
        return "none", false, "主题目录无效"
    end
    if not isfile(Path) then
        return "none", false, "未设置默认主题"
    end

    local Success, Name = pcall(readfile, Path)
    if not Success or typeof(Name) ~= "string" or not ThemeManager:GetCustomTheme(Name) then
        return "none", false, "未找到默认主题"
    end
    ThemeManager.DefaultThemeName = Name
    return Name, true
end

function ThemeManager:SaveDefault(ThemeName: string): (boolean, string?)
    if IsStringEmpty(ThemeName) or not (ThemeManager.BuiltInThemes[ThemeName] or ThemeManager:GetCustomTheme(ThemeName)) then
        return false, "主题不存在"
    end

    local Path = GetDefaultThemePath()
    if not Path then
        return false, "主题目录无效"
    end
    local Success, ErrorMessage = pcall(writefile, Path, ThemeName)
    if not Success then
        return false, tostring(ErrorMessage)
    end
    ThemeManager.DefaultThemeName = ThemeName
    return true
end

function ThemeManager:Delete(ThemeName: string): (boolean, string?)
    if IsStringEmpty(ThemeName) then return false, "未选择主题" end
    local Path = GetThemesPath()
    local ThemePath = Path and string.format("%s/%s.json", Path, ThemeName)
    if not ThemePath or not isfile(ThemePath) then return false, "主题文件不存在" end
    local Success, ErrorMessage = pcall(delfile, ThemePath)
    if not Success then return false, tostring(ErrorMessage) end
    if ThemeName == ThemeManager.DefaultThemeName then ThemeManager:DeleteDefaultTheme() end
    return true
end

function ThemeManager:DeleteDefaultTheme(): (boolean, string?)
    local Path = GetDefaultThemePath()
    if not Path or not isfile(Path) then
        return false, "未设置默认主题"
    end
    local Success, ErrorMessage = pcall(delfile, Path)
    if not Success then
        return false, tostring(ErrorMessage)
    end
    ThemeManager.DefaultThemeName = nil
    return true
end

function ThemeManager:LoadDefault()
    local Name, Success, ErrorMessage = ThemeManager:GetDefaultTheme()
    if not Success then
        if ErrorMessage ~= "未设置默认主题" then
            ThemeManager.Library:Notify("加载默认主题失败：" .. tostring(ErrorMessage))
        end
        return
    end
    local Applied, ApplyError = ThemeManager:ApplyTheme(Name)
    if not Applied then
        ThemeManager.Library:Notify("加载默认主题失败：" .. tostring(ApplyError))
    end
end

function ThemeManager:ApplyThemeData(ThemeData: any): (boolean, string?)
    if typeof(ThemeData) ~= "table" then
        return false, "主题数据无效"
    end

    local Library = ThemeManager.Library

    for Index, Value in ThemeData do
        if Index == "VideoLink" then
            continue
        end

        local Element = Library.Options[Index]
        local FinalValue = Value

        if table.find(SchemeIndexes, Index) then
            local SuccessColor, Color = pcall(Color3.fromHex, Value)
            if not SuccessColor then continue end

            FinalValue = Color
            Library.Scheme[Index] = FinalValue

        else
            continue
        end

        if Element then
            Element:SetValue(FinalValue)
        end
    end

    ThemeManager:ThemeUpdate()
    return true
end

function ThemeManager:SaveJSON(): (string, boolean, string?)
    local ThemeData = BuildCurrentThemeData()

    local SuccessEncode, EncodedData = pcall(HttpService.JSONEncode, HttpService, ThemeData)
    if not SuccessEncode then
        return "", false, "数据编码失败"
    end

    return EncodedData, true
end

function ThemeManager:LoadJSON(Content: string): (boolean, string?)
    if IsStringEmpty(Content) then
        return false, "未提供 JSON"
    end

    local SuccessDecode, Decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not SuccessDecode or not IsValidThemeData(Decoded) then
        return false, "主题数据解析失败"
    end

    return ThemeManager:ApplyThemeData(Decoded)
end

local function ShowDialog(Condition, Index, Title, Description, ActionText, Action)
    if not Condition() then
        return Action()
    end
    return ThemeManager.Library.Window:AddDialog(Index, {
        Title = Title,
        Description = Description,
        AutoDismiss = false,
        FooterButtons = {
            Cancel = {
                Title = "取消",
                Variant = "Ghost",
                Order = 1,
                Callback = function(Dialog) Dialog:Dismiss() end,
            },
            DestructiveAction = {
                Title = ActionText,
                Variant = "Destructive",
                Order = 2,
                Callback = function(Dialog)
                    Dialog:Dismiss()
                    Action()
                end,
            },
        },
    })
end

function ThemeManager:CreateThemeManager(Themesbox: any)
    assert(ThemeManager.Library, "Library is not set, call ThemeManager:SetLibrary(Library) first.")

    local Library = ThemeManager.Library
    local function CreateColorOption(Text, SchemeIndex)
        Themesbox:AddLabel(Text):AddColorPicker(SchemeIndex, {
            Default = Library.Scheme[SchemeIndex],
            Animation = false,
        })
        return Library.Options[SchemeIndex]
    end

    ThemeManager.ContrastLabel = Themesbox:AddLabel({ Text = "对比度检查：...", DoesWrap = true })

    local BackgroundColor = CreateColorOption("背景色", "BackgroundColor")
    local MainColor = CreateColorOption("主色", "MainColor")
    local AccentColor = CreateColorOption("强调色", "AccentColor")
    local OutlineColor = CreateColorOption("描边色", "OutlineColor")
    local FontColor = CreateColorOption("字体颜色", "FontColor")

    local TransparencyOption = Themesbox:AddToggle("ThemeManager_BackgroundTransparent", {
        Text = "背景透明",
        Default = false,
    })

    local CustomThemeNameInput = Themesbox:AddInput("ThemeManager_CustomThemeName", {
        Text = "自定义主题名称",
        Placeholder = "输入名称后创建主题",
    })
    local CustomThemeList = Themesbox:AddDropdown("ThemeManager_CustomThemeList", {
        Text = "自定义主题列表",
        Values = ThemeManager:ReloadCustomThemes(),
        AllowNull = true,
        Multi = false,
    })
    local DefaultThemeLabel = Themesbox:AddLabel("当前默认主题：无")

    local function RefreshThemeLists()
        CustomThemeList:SetValues(ThemeManager:ReloadCustomThemes())
        CustomThemeList:SetValue(nil)
    end

    local function RefreshDefaultThemeLabel()
    local Name, Success = ThemeManager:GetDefaultTheme()
    DefaultThemeLabel:SetText("当前默认主题：" .. (Success and Name or "无"))
    end

    local function SaveThemeWithContrastCheck(Name, SuccessText, AfterSave)
        local function Save()
            local Success, ErrorMessage = ThemeManager:SaveCustomTheme(Name)
            if not Success then
                Library:Notify(string.format("保存主题失败：%s", tostring(ErrorMessage)))
                return
            end
            Library:Notify(string.format(SuccessText, Name))
            if AfterSave then AfterSave() end
        end
        local Report = ThemeManager:GetContrastReport()
        if Report.Passes then
            Save()
            return
        end
        ShowDialog(function() return true end, "ThemeManager_LowContrastSave", "低对比度主题",
            string.format("主题对比度为 %.1f:1（%s），低于建议值 %.1f:1。仍要保存吗？", Report.Ratio, Report.PairName, ContrastWarnThreshold),
            "仍然保存", Save)
    end

    Themesbox:AddButton("创建主题", function()
        local Name = CustomThemeNameInput.Value
        if IsStringEmpty(Name) or Name:find("[/\\\\]") or string.lower(Name) == "default" then
            Library:Notify("主题名称无效")
            return
        end
        ShowDialog(function() return ThemeManager:GetCustomTheme(Name) ~= nil end, "ThemeManager_CreateTheme", "主题已存在",
            string.format("自定义主题 %q 已存在，覆盖后将替换为当前配色。", Name), "覆盖",
            function() SaveThemeWithContrastCheck(Name, "主题 %q 创建成功", RefreshThemeLists) end)
    end)
    Themesbox:AddButton("刷新主题列表", RefreshThemeLists)

    local function GetSelectedCustomTheme()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then
            Library:Notify("请先选择一个自定义主题")
            return nil
        end
        return Name
    end

    Themesbox:AddButton("加载自定义主题", function()
        local Name = GetSelectedCustomTheme()
        if not Name then return end
        local Success, ErrorMessage = ThemeManager:ApplyTheme(Name)
        if not Success then Library:Notify("加载主题失败：" .. tostring(ErrorMessage)) end
    end)
    Themesbox:AddButton("覆盖自定义主题", function()
        local Name = GetSelectedCustomTheme()
        if not Name then return end
        ShowDialog(function() return true end, "ThemeManager_OverwriteTheme", "覆盖主题",
            string.format("确定用当前配色覆盖 %q 吗？", Name), "覆盖",
            function() SaveThemeWithContrastCheck(Name, "主题 %q 已覆盖") end)
    end)
    Themesbox:AddButton("删除自定义主题", function()
        local Name = GetSelectedCustomTheme()
        if not Name then return end
        ShowDialog(function() return true end, "ThemeManager_DeleteTheme", "删除主题",
            string.format("确定删除 %q 吗？", Name), "删除", function()
                local Success, ErrorMessage = ThemeManager:Delete(Name)
                if not Success then Library:Notify("删除主题失败：" .. tostring(ErrorMessage)) return end
                Library:Notify("主题已删除：" .. Name)
                RefreshDefaultThemeLabel()
            end)
    end)
    Themesbox:AddButton("设当前主题为默认", function()
        local Name = CustomThemeList.Value
        if IsStringEmpty(Name) then
            Library:Notify("请先从自定义主题列表中选择")
            return
        end
        local Success, ErrorMessage = ThemeManager:SaveDefault(Name)
        if not Success then Library:Notify("设置默认主题失败：" .. tostring(ErrorMessage)) return end
        Library:Notify("已设为默认主题：" .. Name)
        RefreshDefaultThemeLabel()
    end)
    Themesbox:AddButton("重置默认主题", function()
        ShowDialog(function() return true end, "ThemeManager_ResetDefault", "重置默认主题",
            "确定清除已保存的默认主题吗？", "重置", function()
                local Success, ErrorMessage = ThemeManager:DeleteDefaultTheme()
                if not Success then Library:Notify("重置默认主题失败：" .. tostring(ErrorMessage)) return end
                Library:Notify("默认主题已重置")
                RefreshDefaultThemeLabel()
            end)
    end)

    local ThemeJSONInput = Themesbox:AddInput("ThemeManager_ThemeJSON", { Text = "主题 JSON" })
    Themesbox:AddButton("导入主题", function()
        local Content = ThemeJSONInput.Value
        if IsStringEmpty(Content) then Library:Notify("主题 JSON 不能为空") return end
        ShowDialog(function() return true end, "ThemeManager_ImportTheme", "导入主题",
            "导入后将覆盖当前配色和主题外观设置。", "导入", function()
                local Success, ErrorMessage = ThemeManager:LoadJSON(Content)
                if not Success then Library:Notify("导入主题失败：" .. tostring(ErrorMessage)) return end
                Library:Notify("主题导入成功")
            end)
    end)
    Themesbox:AddButton("导出当前主题", function()
        local Content, Success, ErrorMessage = ThemeManager:SaveJSON()
        if not Success then Library:Notify(tostring(ErrorMessage)) return end
        ThemeJSONInput:SetValue(Content)
        if setclipboard then
            local Copied = pcall(setclipboard, Content)
            Library:Notify(Copied and "主题 JSON 已复制" or "主题 JSON 已导出，请手动复制")
        end
    end)

    local function ApplyBackgroundTransparency(Enabled)
        if Library.Window then
            Library.Window:SetTransparency(Enabled and 0.5 or 1)
        end
    end
    TransparencyOption:OnChanged(ApplyBackgroundTransparency)
    task.defer(function()
        if Library.Window then ApplyBackgroundTransparency(TransparencyOption.Value) end
    end)

    CustomThemeList:OnChanged(function(Name)
        if not IsStringEmpty(Name) then
            local Success, ErrorMessage = ThemeManager:ApplyTheme(Name)
            if not Success then Library:Notify("加载主题失败：" .. tostring(ErrorMessage)) end
        end
    end)

    local function UpdateTheme()
        ThemeManager:ThemeUpdate()
    end
    BackgroundColor:OnChanged(UpdateTheme)
    MainColor:OnChanged(UpdateTheme)
    AccentColor:OnChanged(UpdateTheme)
    OutlineColor:OnChanged(UpdateTheme)
    FontColor:OnChanged(UpdateTheme)
    ThemeManager:LoadDefault()
    ThemeManager:UpdateContrastWarning()
    ThemeManager.AppliedToTab = true
    RefreshDefaultThemeLabel()
    return Themesbox
end

function ThemeManager:CreateGroupBox(Tab: any)
    return Tab:AddGroupbox({
        Side = "Left",
        Name = "主题",
    })
end

function ThemeManager:ApplyToTab(Tab: any)
    local Groupbox = ThemeManager:CreateGroupBox(Tab)
    return ThemeManager:CreateThemeManager(Groupbox)
end

function ThemeManager:ApplyToGroupbox(Groupbox: any)
    return ThemeManager:CreateThemeManager(Groupbox)
end

getgenv().ObsidianThemeManager = ThemeManager
return ThemeManager
