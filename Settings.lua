-- Options panel under Game Menu -> Options -> AddOns -> LoreReader.
-- Settings are account-wide (LoreReaderDB).

local ADDON_NAME, ns = ...
local L = ns.L

local Options = { settings = {} }
ns.Options = Options

ns.DEFAULTS = {
    voice = "",  -- voice name; "" = the voice picked in WoW's own Text to Speech options
    rate = 0,    -- -10 .. 10
    volume = 100, -- 0 .. 100
}

local SAMPLE = L["Greetings, traveler. The Defias Brotherhood has been raiding the farms of Westfall."]

function Options:PlaySample()
    ns.Speech:Play("sample", SAMPLE)
end

-- Change a setting from code (slash commands) so the panel stays in sync.
function Options:Set(key, value)
    local setting = self.settings[key]
    if setting then
        setting:SetValue(value)
    else
        ns.db[key] = value
    end
end

local function voiceOptions()
    local container = Settings.CreateControlTextContainer()
    container:Add("", L["WoW default voice"])
    local found = false
    for _, voice in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
        container:Add(voice.name, voice.name)
        if voice.name == ns.db.voice then
            found = true
        end
    end
    if ns.db.voice ~= "" and not found then
        container:Add(ns.db.voice, ns.db.voice .. " " .. L["(missing)"])
    end
    return container:GetData()
end

local function build()
    local category = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)

    local function register(key, varType, label)
        local setting = Settings.RegisterAddOnSetting(category, "LoreReader_" .. key, key, ns.db, varType, label, ns.DEFAULTS[key])
        Options.settings[key] = setting
        return setting
    end

    Settings.CreateDropdown(category, register("voice", Settings.VarType.String, L["Voice"]), voiceOptions,
        L["Voices installed on your computer. See the addon page for getting better voices."])

    local rateOptions = Settings.CreateSliderOptions(-10, 10, 1)
    rateOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(category, register("rate", Settings.VarType.Number, L["Speed"]), rateOptions,
        L["Reading speed. 0 is normal."])

    local volumeOptions = Settings.CreateSliderOptions(0, 100, 5)
    volumeOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(category, register("volume", Settings.VarType.Number, L["Volume"]), volumeOptions)

    local layout = SettingsPanel:GetLayout(category)
    layout:AddInitializer(CreateSettingsButtonInitializer(L["Test voice"], L["Play sample"], function()
        Options:PlaySample()
    end, L["Reads a short sample with the settings above."], true))

    Settings.RegisterAddOnCategory(category)
    Options.category = category
end

function Options:Init()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then
        ns.Print(L["The options panel isn't available in this client; use /lore help for slash commands."])
        return
    end
    local ok, err = pcall(build)
    if not ok then
        ns.Print(L["Couldn't build the options panel (%s); use /lore help for slash commands."]:format(tostring(err)))
    end
end

function Options:Open()
    if self.category and Settings.OpenToCategory then
        Settings.OpenToCategory(self.category:GetID())
    else
        ns.Print(L["Options panel unavailable; use /lore help."])
    end
end
