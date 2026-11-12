local HttpService: HttpService = game:GetService("HttpService")

local SchemeIndexes = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }
local DefaultFolder = "ObsidianLibSettings"

local ThemeManager = {
    Library = nil,
    Folder = DefaultFolder,
    AppliedToTab = false
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

local function GetThemesPath(): string?
    if IsStringEmpty(ThemeManager.Folder) then
        return nil
    end

    return string.format("%s/themes", ThemeManager.Folder)
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

function ThemeManager:ThemeUpdate()
    local Library = ThemeManager.Library

    for _, SchemeIndex in SchemeIndexes do
        local Element = Library.Options[SchemeIndex]
        if not Element then continue end

        Library.Scheme[SchemeIndex] = Element.Value
    end

    Library:UpdateColorsUsingRegistry()
end

function ThemeManager:SetFolder(Folder: string)
    assert(typeof(Folder) == "string" and not IsStringEmpty(Folder), "主题文件夹路径无效")
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
    if IsStringEmpty(ThemeName) or ThemeName:find("[/\\\\]") then
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
    local Data = ThemeManager:GetCustomTheme(ThemeName)
    if not Data then
        return false, "找不到该主题配置"
    end
    return ThemeManager:ApplyThemeData(Data)
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

function ThemeManager:CreateThemeManager(Themesbox: any)
    assert(ThemeManager.Library, "Library is not set, call ThemeManager:SetLibrary(Library) first.")

    local function CreateColorOption(Text, SchemeIndex)
        Themesbox:AddLabel(Text):AddColorPicker(SchemeIndex, {
            Default = ThemeManager.Library.Scheme[SchemeIndex]
        })

        return ThemeManager.Library.Options[SchemeIndex]
    end

    local BackgroundColor = CreateColorOption("背景色", "BackgroundColor")
    local MainColor = CreateColorOption("主色", "MainColor")
    local AccentColor = CreateColorOption("强调色", "AccentColor")
    local OutlineColor = CreateColorOption("描边色", "OutlineColor")
    local FontColor = CreateColorOption("字体颜色", "FontColor")

    local TransparencyOption = Themesbox:AddToggle("ThemeManager_BackgroundTransparent", {
        Text = "背景透明",
        Default = false,
    })

    Themesbox:AddDivider()
    Themesbox:AddInput("ThemeManager_CustomThemeName", { Text = "主题配置名称" })
    local CustomThemeNameInput = ThemeManager.Library.Options.ThemeManager_CustomThemeName
    local CustomThemeList = Themesbox:AddDropdown("ThemeManager_CustomThemeList", {
        Text = "主题列表选择",
        Values = ThemeManager:ReloadCustomThemes(),
        AllowNull = true,
        Multi = false,
    })

    local function RefreshThemeList()
        CustomThemeList:SetValues(ThemeManager:ReloadCustomThemes())
        CustomThemeList:SetValue(nil)
    end

    Themesbox:AddButton("创建主题配置", function()
        local Name = CustomThemeNameInput.Value
        if IsStringEmpty(Name) or Name:find("[/\\\\]") then
            ThemeManager.Library:Notify("主题配置名称无效")
            return
        end

        local Success, ErrorMessage = ThemeManager:SaveCustomTheme(Name)
        if not Success then
            ThemeManager.Library:Notify(string.format("创建主题配置失败：%s", tostring(ErrorMessage)))
            return
        end

        ThemeManager.Library:Notify("主题配置已创建：" .. Name)
        RefreshThemeList()
    end)

    CustomThemeList:OnChanged(function(Name)
        if not IsStringEmpty(Name) then
            local Success, ErrorMessage = ThemeManager:ApplyTheme(Name)
            if not Success then
                ThemeManager.Library:Notify(string.format("加载主题失败：%s", tostring(ErrorMessage)))
            end
        end
    end)

    Themesbox:AddButton("刷新主题列表", RefreshThemeList)
    Themesbox:AddDivider()
    Themesbox:AddInput("ThemeManager_ThemeJSON", { Text = "主题 JSON" })

    local ThemeJSONInput = ThemeManager.Library.Options.ThemeManager_ThemeJSON
    Themesbox:AddButton("导入主题", function()
        local ThemeJSON = ThemeJSONInput.Value
        if IsStringEmpty(ThemeJSON) then
            ThemeManager.Library:Notify("主题 JSON 不能为空")
            return
        end

        local Success, ErrorMessage = ThemeManager:LoadJSON(ThemeJSON)
        if not Success then
            ThemeManager.Library:Notify(string.format("导入主题失败：%s", ErrorMessage))
            return
        end

        ThemeManager.Library:Notify("主题导入成功")
    end)

    Themesbox:AddButton("导出当前主题", function()
        local EncodedData, Success, ErrorMessage = ThemeManager:SaveJSON()
        if not Success then
            ThemeManager.Library:Notify(ErrorMessage)
            return
        end

        ThemeJSONInput:SetValue(EncodedData)
        if setclipboard then
            local Copied = pcall(setclipboard, EncodedData)
            ThemeManager.Library:Notify(Copied and "主题已复制到剪贴板" or "主题已导出，请手动复制 JSON")
        end
    end)

    local function UpdateTheme()
        ThemeManager:ThemeUpdate()
    end

    local function ApplyBackgroundTransparency(Enabled)
        if ThemeManager.Library.Window then
            ThemeManager.Library.Window:SetTransparency(Enabled and 0.5 or 1)
        end
    end

    TransparencyOption:OnChanged(ApplyBackgroundTransparency)
    task.defer(function()
        if ThemeManager.Library.Window then
            ApplyBackgroundTransparency(TransparencyOption.Value)
        end
    end)

    BackgroundColor:OnChanged(UpdateTheme)
    MainColor:OnChanged(UpdateTheme)
    AccentColor:OnChanged(UpdateTheme)
    OutlineColor:OnChanged(UpdateTheme)
    FontColor:OnChanged(UpdateTheme)

    ThemeManager.AppliedToTab = true
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
