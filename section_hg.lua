local utils = require 'utils'
local symbols = utils.symbols

local function get_hg_dir(path)
    return utils.get_dir_contains(path, '.hg')
end

---
 -- Find out current branch
 -- @return {false|mercurial branch name}
---
local function get_hg_branch() -- TODO uncommand this
    for line in io.popen('hg identify -b 2>nul'):lines() do
        local m = line:match('(.+)$')
        if m then
            return m
        end
    end

    return false
end

local function make_section(old_prompt)

    -- Colors for mercurial status
    local colors = {
        clean = 'green',
        dirty = 'yellow',
    }

    if get_hg_dir() then
        -- if we're inside of mercurial repo then try to detect current branch
        local branch = get_hg_branch()
        if branch then
            return {
                bright = true,
                fg = 'bright_white',
                bg = colors.clean,
                value = symbols.branch .. ' ' .. branch
            }
        else
            return {
                bright = true,
                fg = 'bright_white',
                bg = colors.dirty,
                value = '? branch n/a'
            }
        end
    end

    -- No mercurial present or not in mercurial file
    return nil
end

return make_section