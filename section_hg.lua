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
    for line in io.popen('hg branch'):lines() do
        local m = line:match('(.+)$')
        if m then
            return m
        end
    end

    return false
end

return function(old_prompt)

    -- Colors for mercurial status
    local colors = {
        clean = 'green',
        dirty = 'yellow',
        critical = 'red',
    }

    if get_hg_dir(nil) then
        -- if we're inside of mercurial repo then try to detect current branch
        local branch = get_hg_branch()
        if branch then
            return {
                fg = 'bright_white',
                bg = colors.clean,
                value = symbols.branch .. ' ' .. branch
            }
        else
            return {
                fg = 'bright_white',
                bg = colors.critical,
                value = symbols.no_branch_found .. ' branch n/a'
            }
        end
    end

    -- No mercurial present or not in mercurial file
    return nil
end