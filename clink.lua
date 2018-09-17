----------------------
-- package requires --
----------------------

-- https://stackoverflow.com/a/11869077
-- https://stackoverflow.com/a/5761649
package.path = package.path .. ';' .. clink.get_env('ClinkLuaPath') .. '/?.lua'

local inspect = require 'inspect'
local ansic = require 'ansicolors'
local utils = require 'utils'
local config = require 'config'
local make_section_hg = require 'section_hg'
local make_section_git = require 'section_git'
local make_section_npm = require 'section_npm'

local date_time_enabled = config.date_time_enabled
local date_time_format = config.date_time_format

---- attributes
--local reset      = ansic.reset      -- = 0
--local clear      = ansic.clear      -- = 0
--local default    = ansic.default    -- = 0
--local bright     = ansic.bright     -- = 1
--local dim        = ansic.dim        -- = 2
--local underscore = ansic.underscore -- = 4
--local blink      = ansic.blink      -- = 5
--local reverse    = ansic.reverse    -- = 7
--local hidden     = ansic.hidden     -- = 8
--
---- foreground
--local black   = ansic.black   -- = 30
--local red     = ansic.red     -- = 31
--local green   = ansic.green   -- = 32
--local yellow  = ansic.yellow  -- = 33
--local blue    = ansic.blue    -- = 34
--local magenta = ansic.magenta -- = 35
--local cyan    = ansic.cyan    -- = 36
--local white   = ansic.white   -- = 37
--
---- background
--local onblack   = ansic.onblack   -- = 40
--local onred     = ansic.onred     -- = 41
--local ongreen   = ansic.ongreen   -- = 42
--local onyellow  = ansic.onyellow  -- = 43
--local onblue    = ansic.onblue    -- = 44
--local onmagenta = ansic.onmagenta -- = 45
--local oncyan    = ansic.oncyan    -- = 46
--local onwhite   = ansic.onwhite   -- = 47

-- C:\Users\XXX\a\b\c => ~\a\b\c
local user_profile = clink.get_env('USERPROFILE'):pattern_escape()
local is_admin = clink.get_env('ConEmuIsAdmin') == 'ADMIN'

-- symbols
local symbols = utils.symbols

-- this gets assigned after function declarations
local prompt_sections

local function color_fg(section)
    return ansic[section.fg] or error('no color ansic.' .. section.fg .. '!')
end

local function color_bg(section)
    return ansic['on' .. section.bg] or error('no color ansic.on' .. section.bg .. '!')
end

local function color_bg_as_fg(section)
    return ansic[section.bg] or error('no color ansic.' .. section.bg .. '!')
end

local function pad1(str)
    return str and ' ' .. str .. ' ' or error('value is nil: [[' .. str .. ']]!')
end

local function gen_spaces(count)
    return string.rep(' ', count)
end

--[[
    Places a string at the right side of the terminal screen. This operation can only be done once
    in a line, and you may not draw to the same line afterwards. ANSI escapes are accounted for.
    
    Parameters:
        source(string): the string occupying the left side of the terminal
        target(string): the string to place at the right side of the terminal
        
    Returns(string):
        string consisting of source + spaces + target at the right side
]]
local function place_right_side(source, target)
    local screen_info = clink.get_screen_info()
    
    return source .. gen_spaces(screen_info.buffer_width - target:ansi_len() - source:ansi_len()) .. target
end

function master_prompt_filter()
    local old_prompt = clink.prompt.value
    local sections = {}
    local i = 1
    for _, make_section in ipairs(prompt_sections) do
        local prompt = make_section(old_prompt)
        if prompt then
            sections[i] = prompt
            i = i + 1
        end
    end
    
    local f = sections[1]
    -- put the first value
    local prompt = color_fg(f) .. color_bg(f) .. pad1(f.value)
    local num_sections = #sections
    -- merge rest of sections if there are any
    if num_sections ~= 1 then
        for i=2,num_sections do
            local prev = sections[i-1]
            local cur = sections[i]
            -- reset colors, then color the foreground with the previous section's color, which is
            -- used as the divider's color; the background is set to the current background so it
            -- shows up behind the divider, then the foreground is set after the divider is printed.
            -- then, we put the value in.
            prompt = prompt .. ansic.reset .. color_bg_as_fg(prev) .. color_bg(cur) .. symbols.divider .. color_fg(cur) .. pad1(cur.value)
        end
    end
    
    -- append the trailing divider for the last section
    local l = sections[num_sections]
    prompt = prompt .. ansic.reset .. color_bg_as_fg(l) .. ansic.onblack .. symbols.divider
    
    -- environment systems like pythons virtualenv change the PROMPT and usually
    -- set some variable. But the variables are differently named and we would never
    -- get them all, so try to parse the env name out of the PROMPT.
    -- envs are usually put in round or square parentheses and before the old prompt
    local env = old_prompt:match('.*%(([^%)]+)%).+:')
    -- also check for square brackets
    if env == nil then env = old_prompt:match('.*%[([^%]]+)%].+:') end
    
    if date_time_enabled then
        local date_time = (ansic.bright_black .. os.date(date_time_format))
        
        prompt = place_right_side(prompt, date_time)
    end
    
    -- TODO append dim date to end of first prompt line like https://cloud.githubusercontent.com/assets/53660/16141569/ee2bbe4a-3411-11e6-85dc-3d9b0226e833.png
    clink.prompt.value = (prompt .. '\n{#bright_black,onblack}{lambda} {#reset}')
        :ansicolor()
        :with({
            lambda = env == nil and 'λ' or '('..env..') λ'
        })
end

function user_prompt_section(old_prompt)
    if not is_admin then return nil end
    return {
        fg = 'bright_white',
        bg = 'magenta',
        value = symbols.is_admin .. ' Admin'
    }
end

---
 -- Setting the prompt in clink means that commands which rewrite the prompt do
 -- not destroy our own prompt. It also means that started cmds (or batch files
 -- which echo) don't get the ugly '{lamb}' shown.
---
function cwd_prompt_section(old_prompt)
    -- get_cwd() is differently encoded than the clink.prompt.value, so everything other than
    -- pure ASCII will get garbled. So try to parse the current directory from the original prompt
    -- and only if that doesn't work, use get_cwd() directly.
    -- The matching relies on the default prompt which ends in X:\PATH\PATH>
    -- (no network path possible here!)
    local cwd = clink.prompt.value:match('.*(.:[^>]*)>') or clink.get_cwd()
    --local cwd = clink.get_cwd()
    
    -- build our own prompt
    return {
        fg = 'bright_white',
        bg = 'blue',
        value = cwd:gsub(user_profile, '~')
    }
end

-- create prompt sections
prompt_sections = {
    user_prompt_section,
    cwd_prompt_section,
    make_section_npm,
    make_section_hg,
    make_section_git,
}

-- insert the set_prompt at the very beginning so that it runs first
clink.prompt.register_filter(master_prompt_filter, 1)

require 'clink-completions.!init'
require 'clink-completions.angular-cli'
require 'clink-completions.chocolatey'
require 'clink-completions.coho'
require 'clink-completions.cordova'
require 'clink-completions.git'
require 'clink-completions.net'
require 'clink-completions.npm'
require 'clink-completions.nvm'
require 'clink-completions.ssh'
require 'clink-completions.vagrant'
require 'clink-completions.yarn'