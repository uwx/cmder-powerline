local utils = require 'utils'
local symbols = utils.symbols

local function git_file(dir)
    local contents = utils.read_first_line(dir..'/.git')
    if not contents then return false end

    local git_dir = contents:match('gitdir: (.*)')
    return git_dir and dir..'/'..git_dir
end

-- adapted from from clink-completions' git.lua
local function get_git_dir(path)

    -- Set default path to current directory
    if not path or path == '.' then path = clink.get_cwd() end

    -- Calculate parent path now otherwise we won't be
    -- able to do that inside of logical operator
    local parent_path = utils.pathname(path)

    return
        -- Check for GIT_DIR containing the location of the .git folder.
        clink.get_env('GIT_DIR')
        -- Checks if provided directory contains git directory
        or (utils.has_specified_dir(path, '.git') and path..'/.git' or nil) 
        -- Checks for a submodule git file pointing to a git folder
        or git_file(path)
        -- Otherwise go up one level and make a recursive call
        or (parent_path ~= path and get_git_dir(parent_path) or nil)
end

---
 -- Find out current branch
 -- @return {nil|git branch name}
---
local function get_git_branch(git_dir)
    git_dir = git_dir or get_git_dir()

    -- If git directory not found then we're probably outside of repo
    -- or something went wrong. The same is when head_file is nil
    local HEAD = utils.read_first_line(git_dir..'/HEAD')
    if not HEAD then return end

    -- if HEAD matches branch expression, then we're on named branch
    -- otherwise it is a detached commit
    local branch_name = HEAD:match('ref: refs/heads/(.+)')
    return branch_name and (symbols.branch .. ' ' .. branch_name) or (symbols.detached_head .. ' ' .. HEAD:sub(1, 7))
end

--[[local function get_merge_orig(git_dir)
    git_dir = git_dir or get_git_dir()
    
    local ORIG_HEAD = utils.read_first_line(git_dir..'/ORIG_HEAD')
    if not ORIG_HEAD then return end

end]]

local function get_merge_head(git_dir)
    git_dir = git_dir or get_git_dir()
    
    local MERGE_HEAD = utils.read_all_lines(git_dir..'/MERGE_HEAD')
    if not MERGE_HEAD or #MERGE_HEAD == 0 then return end
    
    return table.concat(table.map_in_place(MERGE_HEAD, function(w) return w:sub(1, 7) end), ', ')
end

local function get_merge_targets(git_dir)
    git_dir = git_dir or get_git_dir()
    
    local MERGE_MSG = utils.read_first_line(git_dir..'/MERGE_MSG')
    if not MERGE_MSG then return end
    
    local targets = {}
    
    -- Merge commit 'c75d0e0'; branch 'nuts'
    for w in MERGE_MSG:gmatch("'(%w+)'") do
      targets[#targets+1] = w
    end
    
    return table.concat(targets, ', ')
end

local function is_index_dirty(git_dir)
    git_dir = git_dir or get_git_dir()
    
    return io.popen('git diff-index --quiet HEAD --'):close() ~= 0
end

local function make_section(old_prompt)

    -- Colors for git status
    local colors = {
        clean = 'green',
        dirty = 'yellow',
        critical = 'red',
    }
    
    local git_dir = get_git_dir()
    if git_dir then
        -- if we're inside of git repo then try to detect current branch
        local branch = get_git_branch(git_dir)
        local merge_targets = get_merge_targets(git_dir) or get_merge_head(git_dir)
        local git_config = utils.load_ini(git_dir .. '/config')
        local dirty = is_index_dirty(git_dir)
        
        local value = branch or (symbols.no_branch_found .. ' branch n/a')
        
        if dirty then
            value = value .. ' ' .. symbols.staged_changes
        end
        
        -- show 'branch -> origin/other_branch' or 'branch -> origin' for same branch
        if branch and git_config then
            local remote = utils.get_config(git_config, 'branch "%s"' % branch, 'remote')
            local remote_branch = utils.get_config(git_config, 'remote "%s"' % remote, 'push') 
                                  or utils.get_config(git_config, 'push', 'default')
            
            if remote_branch and remote_branch ~= branch then
                value = value .. ' ' .. symbols.right_arrow .. ' ' .. (remote or 'remote') .. '/' .. remote_branch
            elseif remote then
                value = value .. ' ' .. symbols.right_arrow .. ' ' .. remote
            end
        end
        
        -- detect merge targets
        if merge_targets then
            value = value .. ' ' .. symbols.merging .. ' ' .. merge_targets
        end
        
        if branch then
            if dirty then
                return {
                    bright = true,
                    fg = 'bright_white',
                    bg = colors.dirty,
                    value = value
                }
            else
                return {
                    bright = true,
                    fg = 'bright_white',
                    bg = colors.clean,
                    value = value
                }
            end
        else
            return {
                bright = false,
                fg = 'bright_white',
                bg = colors.critical,
                value = value
            }
        end
    end

    -- No git present or not in git file
    return nil
end

return make_section