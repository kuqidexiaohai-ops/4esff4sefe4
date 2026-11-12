local HttpService: HttpService = game:GetService("HttpService")

local SchemeIndexes = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }

local ThemeManager = {
    Library = nil,
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

    return Data.BackgroundImage == nil or typeof(Data.BackgroundImage) == "string"
end

local function BuildCurrentThemeData(): {[string]: any}
    local Library = ThemeManager.Library
    local ThemeData = {
        BackgroundImage = Library.Options.BackgroundImage.Value
    }

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
            ThemeManager.Library:SetBackgroundImage(Value)

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

    Themesbox:AddInput("BackgroundImage", {
        Text = "背景图片",
        Default = "",
        Finished = true,
        ClearTextOnFocus = false,
        ClearTextOnBlur = false
    })

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

    BackgroundColor:OnChanged(UpdateTheme)
    MainColor:OnChanged(UpdateTheme)
    AccentColor:OnChanged(UpdateTheme)
    OutlineColor:OnChanged(UpdateTheme)
    FontColor:OnChanged(UpdateTheme)
    ThemeManager.Library.Options.BackgroundImage:OnChanged(function(Value)
        ThemeManager.Library:SetBackgroundImage(Value)
    end)

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
