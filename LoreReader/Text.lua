-- Text clean-up and chunking. Pure Lua with no WoW API calls, so it can be
-- unit-tested outside the game (see tests/test_text.lua).

local _, ns = ...
ns = type(ns) == "table" and ns or {}

local Text = {}
ns.Text = Text

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Strip WoW UI markup (colours, hyperlinks, textures, atlases) so it isn't
-- spoken, and flatten line breaks into sentences.
function Text.Clean(text)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    local s = text

    s = s:gsub("|n", "\n")
    s = s:gsub("\r\n?", "\n")
    s = s:gsub("|H.-|h(.-)|h", "%1")         -- hyperlinks: keep the visible label
    s = s:gsub("|T.-|t", "")                  -- textures
    s = s:gsub("|A.-|a", "")                  -- atlases
    s = s:gsub("|K.-|k", "")                  -- protected strings
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")      -- colour start
    s = s:gsub("|cn[%w_]+:", "")              -- named colour start
    s = s:gsub("|r", "")                      -- colour end
    s = s:gsub("||", " ")
    s = s:gsub("|", " ")
    s = s:gsub("<(.-)>", "%1")                -- <stage directions> are read without brackets
    s = s:gsub("%[(.-)%]", "%1")              -- stray [brackets] from link labels

    -- Each line becomes a sentence so paragraphs don't run together.
    local lines = {}
    for line in (s .. "\n"):gmatch("(.-)\n") do
        line = trim(line:gsub("%s+", " "))
        if line ~= "" then
            if not line:find("[%.!?:;,\"')%-]$") then
                line = line .. "."
            end
            lines[#lines + 1] = line
        end
    end
    return table.concat(lines, " ")
end

-- Split a long piece of text into sentences.
local function splitSentences(text)
    local marked = text:gsub("([%.!?]+[\"')]*)%s+", "%1\0")
    local out = {}
    for part in (marked .. "\0"):gmatch("(.-)%z") do
        part = trim(part)
        if part ~= "" then
            out[#out + 1] = part
        end
    end
    return out
end

-- Break a single over-long sentence on word boundaries.
local function splitWords(sentence, maxLen)
    local out, current = {}, ""
    for word in sentence:gmatch("%S+") do
        while #word > maxLen do
            if current ~= "" then
                out[#out + 1] = current
                current = ""
            end
            out[#out + 1] = word:sub(1, maxLen)
            word = word:sub(maxLen + 1)
        end
        if current == "" then
            current = word
        elseif #current + 1 + #word <= maxLen then
            current = current .. " " .. word
        else
            out[#out + 1] = current
            current = word
        end
    end
    if current ~= "" then
        out[#out + 1] = current
    end
    return out
end

-- Pack sentences into chunks of at most maxLen characters. Sentences are
-- never split unless a single sentence is longer than maxLen.
function Text.Chunk(text, maxLen)
    local chunks, current = {}, ""
    for _, sentence in ipairs(splitSentences(text or "")) do
        local pieces = (#sentence > maxLen) and splitWords(sentence, maxLen) or { sentence }
        for _, piece in ipairs(pieces) do
            if current == "" then
                current = piece
            elseif #current + 1 + #piece <= maxLen then
                current = current .. " " .. piece
            else
                chunks[#chunks + 1] = current
                current = piece
            end
        end
    end
    if current ~= "" then
        chunks[#chunks + 1] = current
    end
    return chunks
end

return Text
