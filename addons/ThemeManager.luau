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
    --// 内置主题：自带配色已清空，按下面格式自行添加即可
    --// 格式：["主题名"] = { 排序序号, { FontColor, MainColor, AccentColor, BackgroundColor, OutlineColor, BackgroundImage?, BackgroundImageTransparency? } }，色值不带 #
    --// BackgroundImage：可省略。填 Roblox 贴图 ID（纯数字）或 http/https 直链（会下载到本地）
    --// BackgroundImageTransparency：可省略，0 = 最清晰 / 1 = 最淡，默认 0.75
    --// 例（樱花）：["樱花"] = { 1, { FontColor = "ffffff", MainColor = "2b1d24", AccentColor = "ff8fb1", BackgroundColor = "1a1216", OutlineColor = "5c3a47", BackgroundImage = "https://raw.githubusercontent.com/你/仓库/main/sakura.png", BackgroundImageTransparency = 0.6 } },
    BuiltInThemes = {
        --// 樱花夜：暗紫粉调，背景图实测平均色 #281820、亮度 0.125，中央空旷适合放控件
        ["樱花夜"] = {
            1,
            {
                FontColor = "ffffff",
                MainColor = "2b1d24",
                AccentColor = "ff8fb1",
                BackgroundColor = "1a1216",
                OutlineColor = "5c3a47",
                BackgroundImage = "https://raw.githubusercontent.com/kuqidexiaohai-ops/4esff4sefe4/refs/heads/main/task-mwqbfag71dple.png",
                BackgroundImageTransparency = 0.5,
            },
        },
    },
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

    if Data.BackgroundImage ~= nil and typeof(Data.BackgroundImage) ~= "string" then
        return false
    end

    return true
end

local function NormalizePath(Path: string): string
    return Path:gsub("\\", "/"):gsub("/+", "/"):gsub("/$", "")
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

    return NormalizePath(string.format("%s/%s.json", ThemesPath, ThemeName))
end

local function BuildCurrentThemeData(): {[string]: any}
    local Library = ThemeManager.Library
    local ThemeData = {
        BackgroundImage = Library.Options.BackgroundImage.Value,
        BackgroundImageTransparency = Library.BackgroundImageTransparency or 0.75,
    }

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
    local FontColorElement = Library.Options.FontColor
    local BackgroundElement = Library.Options.BackgroundColor
    local MainColorElement = Library.Options.MainColor

    --// 颜色控件尚未创建时直接返回"通过"，避免索引 nil 报错
    if not (FontColorElement and BackgroundElement and MainColorElement) then
        return { Ratio = math.huge, PairName = "", Passes = true }
    end

    local FontColor = FontColorElement.Value
    local Surfaces = {
        { Name = "背景色", Color = BackgroundElement.Value },
        { Name = "主色", Color = MainColorElement.Value },
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

    --// 原版有这段保护：注册表里没有该 TextLabel 时先注册，否则下面直接索引会报错
    if not Library.Registry[TextLabel] then
        Library:AddToRegistry(TextLabel, {})
    end

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

local function GetFileName(FilePath: string): string?
    local Normalized = NormalizePath(FilePath)
    local FileName = Normalized:match("([^/]+)$")
    if not FileName then return nil end
    local BaseName, Extension = FileName:match("^(.*)%.([^%.]+)$")
    if not BaseName or string.lower(Extension) ~= "json" then return nil end
    return BaseName
end

local function GetThemeFilePath(ThemeName: string): string?
    local ThemesPath = GetThemesPath()
    if not ThemesPath then return nil end

    local ExpectedPath = NormalizePath(string.format("%s/%s.json", ThemesPath, ThemeName))
    if isfile(ExpectedPath) then return ExpectedPath end

    local Success, Files = pcall(listfiles, ThemesPath)
    if not Success or typeof(Files) ~= "table" then return nil end
    for _, FilePath in Files do
        if GetFileName(tostring(FilePath)) == ThemeName then
            local RawPath = tostring(FilePath)
            local NormalizedPath = NormalizePath(RawPath)
            if isfile(RawPath) then return RawPath end
            if isfile(NormalizedPath) then return NormalizedPath end
        end
    end
    return nil
end

function ThemeManager:ReloadCustomThemes(): {string}
    local ThemesPath = EnsureThemesFolder()
    if not ThemesPath then return {} end

    local Success, Files = pcall(listfiles, ThemesPath)
    if not Success or typeof(Files) ~= "table" then return {} end

    local Names = {}
    local Seen = {}
    for _, FilePath in Files do
        local Name = GetFileName(tostring(FilePath))
        if Name then
            --// Windows 文件系统不区分大小写，用小写做去重键，避免同一主题重复出现
            local Key = string.lower(Name)
            if not Seen[Key] then
                Seen[Key] = true
                table.insert(Names, Name)
            end
        end
    end
    table.sort(Names)
    return Names
end

function ThemeManager:GetCustomTheme(ThemeName: string): any
    if IsStringEmpty(ThemeName) or ThemeName:find("[/\\\\]") then return nil end
    local Path = GetThemeFilePath(ThemeName)
    if not Path or not isfile(Path) then return nil end

    local Success, Content = pcall(readfile, Path)
    if not Success or typeof(Content) ~= "string" then return nil end

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
    if not Success or typeof(Name) ~= "string" then
        return "none", false, "未找到默认主题"
    end
    local IsBuiltIn = ThemeManager.BuiltInThemes[Name] ~= nil
    if not IsBuiltIn and not ThemeManager:GetCustomTheme(Name) then
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
    local ThemePath = GetThemeFilePath(ThemeName)
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

        if Index == "BackgroundImage" then
            if typeof(Value) ~= "string" then continue end
            Library:SetBackgroundImage(Value)
            FinalValue = Value
        elseif Index == "BackgroundImageTransparency" then
            if typeof(Value) ~= "number" then continue end

            if Library.Window then
                Library.Window:SetBackgroundImageTransparency(Value)
            end

            --// 回写到界面上的浓度滑块（浓度 = 1 - 透明度）
            local ConcentrationSlider = Library.Options.BackgroundImageTransparency
            if ConcentrationSlider then
                ConcentrationSlider:SetValue(math.floor((1 - Value) * 100 + 0.5))
            end
            continue
        elseif table.find(SchemeIndexes, Index) then
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

    Themesbox:AddInput("BackgroundImage", {
        Text = "背景图片（贴图 ID 或 http/https 直链，会下载到本地）",
        Default = "",
        Finished = true,
        ClearTextOnFocus = false,
        ClearTextOnBlur = false,
    })

    local BackgroundImageOption = Library.Options.BackgroundImage
    BackgroundImageOption:OnChanged(function(Value)
        Library:SetBackgroundImage(Value)
    end)

    Themesbox:AddSlider("BackgroundImageTransparency", {
        Text = "背景图浓度",
        Min = 0,
        Max = 100,
        Default = math.floor((1 - (Library.BackgroundImageTransparency or 0.75)) * 100 + 0.5),
        Rounding = 0,
        Suffix = "%",
        Callback = function(Value)
            --// 滑块是浓度（越大越清晰），内部是透明度（越大越淡），所以反过来
            if Library.Window then
                Library.Window:SetBackgroundImageTransparency(1 - Value / 100)
            end
        end,
    })

    Themesbox:AddDivider()

    --// 前向声明：内置主题的「设为默认」按钮要用到它，稍后才赋值
    local RefreshDefaultThemeLabel

    --// 内置主题列表（BuiltInThemes 现在为空，等你按上面的格式自己加）
    local BuiltInThemesNames = {}
    for Name in ThemeManager.BuiltInThemes do
        table.insert(BuiltInThemesNames, Name)
    end
    table.sort(BuiltInThemesNames, function(IndexA, IndexB)
        local ThemeA = ThemeManager.BuiltInThemes[IndexA]
        local ThemeB = ThemeManager.BuiltInThemes[IndexB]
        local OrderA = (ThemeA and ThemeA[1]) or math.huge
        local OrderB = (ThemeB and ThemeB[1]) or math.huge
        return OrderA < OrderB
    end)

    local ThemeList = Themesbox:AddDropdown("ThemeManager_ThemeList", {
        Text = (#BuiltInThemesNames > 0) and "内置主题列表" or "内置主题列表（暂无，可在 BuiltInThemes 里添加）",
        Values = BuiltInThemesNames,
        AllowNull = true,
        Multi = false,

        FormatDisplayValue = function(Value)
            if Value ~= "Default" and Value == ThemeManager.DefaultThemeName then
                return string.format("%s（默认）", Value)
            end

            return Value
        end,
        FormatListValue = function(Value)
            if Value ~= "Default" and Value == ThemeManager.DefaultThemeName then
                return string.format("%s（默认）", Value)
            end

            return Value
        end,
    })

    Themesbox:AddButton("将内置主题设为默认", function()
        local Name = ThemeList.Value
        if IsStringEmpty(Name) then
            Library:Notify("请先选择一个内置主题")
            return
        end

        local Success, ErrorMessage = ThemeManager:SaveDefault(Name)
        if not Success then
            Library:Notify("设置默认主题失败：" .. tostring(ErrorMessage))
            return
        end

        Library:Notify(string.format("已设为默认主题：%s", Name))
        if RefreshDefaultThemeLabel then RefreshDefaultThemeLabel() end
    end)

    Themesbox:AddDivider()

    local CustomThemeNameInput = Themesbox:AddInput("ThemeManager_CustomThemeName", {
        Text = "自定义主题名称",
        Placeholder = "输入名称后创建主题",
    })
    local CustomThemeList = Themesbox:AddDropdown("ThemeManager_CustomThemeList", {
        Text = "自定义主题列表",
        Values = ThemeManager:ReloadCustomThemes(),
        AllowNull = true,
        Multi = false,

        --// 恢复原版：默认主题在列表里带 "(默认)" 标记
        FormatDisplayValue = function(Value)
            if Value == ThemeManager.DefaultThemeName then
                return string.format("%s（默认）", Value)
            end

            return Value
        end,
        FormatListValue = function(Value)
            if Value == ThemeManager.DefaultThemeName then
                return string.format("%s（默认）", Value)
            end

            return Value
        end,
    })
    local DefaultThemeLabel = Themesbox:AddLabel("当前默认主题：无")

    local function RefreshThemeLists()
        local PreviousValue = CustomThemeList.Value
        local Names = ThemeManager:ReloadCustomThemes()

        CustomThemeList:SetValues(Names)

        --// 刷新后保留原来的选中项；若它已被删除/改名，则清空选中
        local StillExists = false
        if PreviousValue ~= nil then
            for _, Name in Names do
                if Name == PreviousValue then
                    StillExists = true
                    break
                end
            end
        end
        CustomThemeList:SetValue(StillExists and PreviousValue or nil)
    end

    function RefreshDefaultThemeLabel()
        local Name, Success = ThemeManager:GetDefaultTheme()
        DefaultThemeLabel:SetText("当前默认主题：" .. (Success and Name or "无"))
        --// 对齐原版：默认主题变化后顺手刷新一下列表（删除主题后列表不会残留）
        if CustomThemeList then
            RefreshThemeLists()
        end
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

    Themesbox:AddDivider()

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
        if not Success then
            Library:Notify("加载主题失败：" .. tostring(ErrorMessage))
            return
        end
        Library:Notify(string.format("已加载主题 %q", Name))
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

    Themesbox:AddDivider()

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

    --// 内置主题列表：选中即应用（与原版一致）
    ThemeList:OnChanged(function()
        local Name = ThemeList.Value
        if not IsStringEmpty(Name) then
            ThemeManager:ApplyTheme(Name)
        end
    end)

    --// 原版行为：切换自定义主题列表「不」自动应用，必须点下面的「加载自定义主题」按钮
    --// （之前这里绑定了 OnChanged 直接 ApplyTheme，导致一选中就换肤，已移除）

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

    --// 若默认主题存在，刷新后把它同步显示在对应列表里（原版会同步内置列表）
    local DefaultName, HasDefault = ThemeManager:GetDefaultTheme()
    if HasDefault then
        if ThemeManager.BuiltInThemes[DefaultName] then
            ThemeList:SetValue(DefaultName)
        elseif ThemeManager:GetCustomTheme(DefaultName) then
            CustomThemeList:SetValue(DefaultName)
        end
    end

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
