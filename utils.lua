local inspect = require 'inspect'
local utf8 = require 'utf8string'
local ansic = require 'ansicolors'

local exports = {}

------------------------
-- builtin extensions --
------------------------

--[[
    Performs string interpolation on a string

    Parameters:
        s(string): the string to format
        tab(table): the table that contains elements for formatting
    
    Returns:
        the formatted string
    
    Example:
        '{foo} into {bar}':with({
            foo = 7,
            bar = 28
        })

        results in

        '7 into 28'
        
    References:
        http://lua-users.org/wiki/StringInterpolation
]]
function string.with(s, tab)
  return (s:gsub('(%b{})', function(w) return tab[w:sub(2, -2)] or w end))
end

--[[
    Escapes a string literal for use in a pattern
    
    Parameters:
        str(string): the string to escape

    Returns:
        the escaped string
    
    References:
        https://stackoverflow.com/a/20778724
]]
local escape_pattern = '(['..('%^$().[]*+-?'):gsub('(.)', '%%%1')..'])'
function string.pattern_escape(str)
    return str:gsub(escape_pattern, '%%%1')
end

--[[
    Splits a string by a char. No extra empty fields are created, unlike other string split
    functions.
    
    Parameters:
        str(string): the string to split
        sep(string): the char to split the string by, needs to be escaped with % if it is one of the
            following chars: ^$()%.[]*+-?
        
    Returns:
        table containing the input string split by the given separator; the inverse operation of
        `table.concat`
        
    References:
        http://lua-users.org/wiki/SplitJoin
]]
function string.split_char(str, sep)
   local ret={}
   local n=1
   for w in str:gmatch('([^'..sep..']*)') do
      ret[n] = ret[n] or w -- only set once (so the blank after a string is ignored)
      if w == '' then
         n = n + 1
      end -- step forwards on a blank but not a string
   end
   return ret
end

--[[
    Given a table (or an iterator) and function, will return a new table where each key is mapped to
    the result of the function with the key's value (or iterator item) passed as its parameter.
    
    Parameters:
        tab(table|function): the table or iterator function to create a mapping of
        func(function(value,index,table)): the map function, takes three arguments: the value, the
            value's index and the original table.
    
    Returns:
        the new table
    
    Example:
        table.map({1,2,3,4,5}, function(v) return v + 5 end)
        
        results in
        
        {6,7,8,9,10}
]]
function table.map(tab, func)
    local new_array = {}
    if type(tab) == 'table' then
        for i,v in ipairs(tab) do
            new_array[i] = func(v,i,tab)
        end
    else
        local i = 1
        for v in tab do
            new_array[i] = func(v,i,tab)
            i = i + 1
        end
    end
    return new_array
end

--[[
    Given a table and function, will map each key in the existing table to the result of the
    function with the key's value passed as its parameter, then return the table.
    
    Parameters:
        tab(table): the table to create a mapping of
        func(function(value,index,table)): the map function, takes three arguments: the value, the
            value's index and the table.
    
    Returns:
        the existing table
    
    Example:
        local tab = {1,2,3,4,5}
        local res = table.map_in_place(tab, function(v) return v + 5 end)
        
        results in
        
        res==tab=={6,7,8,9,10}
]]
function table.map_in_place(tab, func)
    for i,v in ipairs(tab) do
        tab[i] = func(v,i,tab)
    end
    return tab
end

--[[
    Performs interpolation of ANSI colors on a string

    Parameters:
        s(string): the string to format
        reset_at_end(boolean, optional): whether or not to append `ansic.reset` at the end of the
            string, default false
    
    Returns:
        the string with ANSI color escapes
    
    Example:
        '{#bright,red}this is loud!':ansicolor()

        results in

        '[ansi bright escape sequence][ansi red escape sequence]this is loud!'
]]
local ansi_color_token = string.byte('#')
function string.ansicolor(s, reset_at_end)
    s = s:gsub('(%b{})',
        function(w)
            if w:byte(2) ~= ansi_color_token then return w end -- check # in {#value}
            
            local values = w:sub(3, -2) -- strip {#value} into value
            -- if it's just an empty {#} then just return it verbatim
            if not values then return w end
            
            -- match strings between commas or other delimiters, replace colors in each of them
            return table.concat(
                table.map(values:gmatch('%w+'), 
                    function(v) 
                        local color = ansic[v]
                        -- if the color wasn't found, put the text verbatim in the output array
                        return color and color.value or v
                    end))
        end)
    if reset_at_end then s = s .. ansic.reset end
    return s
end

----------------
-- path utils --
----------------

-- return parent path for specified entry (either file or directory)
function exports.pathname(path)
    local prefix = ''
    local i = path:find('[\\/:][^\\/:]*$')
    if i then
        prefix = path:sub(1, i-1)
    end
    return prefix
end

-- Navigates up one level
local function up_one_level(path)
    if path == nil or path == '.' then path = clink.get_cwd() end
    return exports.pathname(path)
end

-- Checks if provided directory contains directory
function exports.has_specified_dir(path, specified_dir)
    if path == nil then path = '.' end
    return clink.is_dir(path..'/'..specified_dir)
end

---
 -- Resolves closest directory location for specified directory.
 -- Navigates subsequently up one level and tries to find specified directory
 -- @param  {string} path    Path to directory will be checked. If not provided
 --                          current directory will be used
 -- @param  {string} dirname Directory name to search for
 -- @return {string} Path to specified directory or nil if such dir not found
function exports.get_dir_contains(path, dirname)

    -- Set default path to current directory
    if path == nil then path = '.' end

    -- If we're already have .git directory here, then return current path
    if exports.has_specified_dir(path, dirname) then
        return path..'/'..dirname
    else
        -- Otherwise go up one level and make a recursive call
        local parent_path = up_one_level(path)
        if parent_path == path then
            return nil
        else
            return exports.get_dir_contains(parent_path, dirname)
        end
    end
end

--[[
    Reads the first line of a file.
    
    Parameters:
        file(string): the file path to read
    
    Returns:
        the file's first line's contents, or nil if the file does not exist or `file` is nil
]]
function exports.read_first_line(file)
    local handle = file and io.open(file, 'r')
    if not handle then return nil end

    local line = handle:read()
    handle:close()
    
    return line
end

--[[
    Reads the each line of a file into an element in a table.
    
    Parameters:
        file(string): the file path to read
    
    Returns:
        table containing the file's contents, or nil if the file does not exist or `file` is nil
]]
function exports.read_all_lines(file)
    local handle = file and io.open(file, 'r')
    if not handle then return nil end
    
    local file_lines = {}
    
    local i = 1
    while true do
      local line = handle:read()
      if line == nil then break end
      
      file_lines[i] = line
      i = i + 1
    end

    handle:close()
    
    return file_lines
end

-----------------
-- other stuff --
-----------------

function exports.printi(obj)
    print(inspect(obj))
end

local function u(c)
    return utf8.char(tonumber(c, 16))
end

-- symbols
exports.symbols = {
    divider = u'e0b0', -- l>r divider
    branch = u'e725', -- git branch icon
    detached_head = u'e729', -- git detached head icon
    no_branch_found = u'e009', -- branch could not be resolved icon
    merging = u'e727', -- is merge in process icon
    unpushed_commits = u'f176', -- unpushed local commits icon
    unpulled_commits = u'f175', -- unpulled remote commits icon
    staged_changes = '*',
    is_admin = u'e00a', -- running prompt as admin icon
}


return exports