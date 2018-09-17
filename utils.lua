local inspect = require 'inspect'
local utf8 = require 'utf8'
local ansic = require 'ansicolors'

local exports = {}

------------------------
-- builtin extensions --
------------------------

--[[
    Performs string interpolation on a string
    
    Parameters:
        str(string): the string to format
        args(any): the element to format with, or the table that contains elements for formatting
            (see Example section for more details)
    
    Returns(string):
        the formatted string
    
    Example:
        Indexed parameters
        print("Hello %s, the value of key %s is %s" % {name, k, v})
    
        Named parameters
        print("{name} is {value}" % {name = "foo", value = "bar"})

        Format strings
        print("%5.2f" % math.pi)
        
        Indexed format strings
        print("%-10.10s %04d" % { "test", 123 })
        
        TODO: named parameters with format strings
        
    References:
        http://lua-users.org/wiki/StringInterpolation "Ruby- and Python-like string formatting with
            % operator"
]]
getmetatable('').__mod = function(str, args)
    if not args then
        return str
    elseif type(args) == 'table' then
        if args[1] then -- array
            return str:format(unpack(args))
        else -- not array, likely key-value map, delegate to our string.with extension
            return str:with(args)
        end
    else
        return str:format(args)
    end
end

--[[
    Performs string interpolation on a string

    Parameters:
        s(string): the string to format
        tab(table): the table that contains elements for formatting
    
    Returns(string):
        the formatted string
    
    Example:
        '{foo} into {bar}':with({
            foo = 7,
            bar = 28
        })

        results in

        '7 into 28'
        
    References:
        http://lua-users.org/wiki/StringInterpolation "Named Parameters in Table"
]]
function string.with(s, tab)
  return (s:gsub('(%b{})', function(w) return tab[w:sub(2, -2)] or w end))
end

--[[
    Escapes a string literal for use in a pattern
    
    Parameters:
        str(string): the string to escape

    Returns(string):
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
        
    Returns(table):
        table containing the input string split by the given separator; the inverse operation of
        `table.concat`
        
    References:
        http://lua-users.org/wiki/SplitJoin ('local function csplit')
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
    Strips a string of any ANSI escape sequences.
    
    Parameters:
        text(string): the string to remove ANSI sequences from
        
    Returns(string):
        the string without ANSI sequences
        
    References:
        https://stackoverflow.com/a/49209650
]]
function string.strip_ansi(text)
    -- could maybe use utf8.gsub if there are encoding problems (none so far)
    return text:gsub('[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]', '')
end

--[[
    Gets a string's length without counting any ANSI escape sequences. This function makes a version
    of the string without ANSI sequences, and returns the length of that.
    
    Parameters:
        text(string): the string to get the length of
        
    Returns(number):
        the amount of characters in the string, not counting any characters belonging to any ANSI
        escape sequences
]]
function string.ansi_len(text)
    return utf8.len(text:strip_ansi())
end

--[[
    Given a table (or an iterator) and function, will return a new table where each key is mapped to
    the result of the function with the key's value (or iterator item) passed as its parameter.
    
    Parameters:
        tab(table|function): the table or iterator function to create a mapping of
        func(function(value,index,table)): the map function, takes three arguments: the value, the
            value's index and the original table.
    
    Returns(table):
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
    
    Returns(table):
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
    
    Returns(string):
        the string with ANSI color escapes
    
    Example:
        '{#bright_red}this is loud!':ansicolor()

        results in

        '[ansi bright red escape sequence]this is loud!'
        
    References:
        http://lua-users.org/wiki/StringInterpolation "Named Parameters in Table"
        
    Remarks:
        See ansicolors.lua for the list of allowed colors.
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

local function file_exists(name)
    local f = name and io.open(name, 'r')
    if f ~= nil then
        f:close()
        return true
    else
        return false
    end
end

function exports.has_specified_file(path, specified_file)
    if path == nil then path = '.' end
    return file_exists(path..'/'..specified_file)
end

function exports.get_file_contains(path, dirname)

    -- Set default path to current directory
    if path == nil then path = '.' end

    -- If we're already have .git directory here, then return current path
    if exports.has_specified_file(path, dirname) then
        return path..'/'..dirname
    else
        -- Otherwise go up one level and make a recursive call
        local parent_path = up_one_level(path)
        if parent_path == path then
            return nil
        else
            return exports.get_file_contains(parent_path, dirname)
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

--[[
    Reads the entire text content of a file into a string.
    
    Parameters:
        file(string): the file path to read
    
    Returns:
        string containing the file's contents, or nil if the file does not exist or `file` is nil
]]
function exports.read_all_text(file)
    local handle = file and io.open(file, 'r')
    if not handle then return nil end

    local line = handle:read('*a')
    handle:close()
    
    return line
end

--[[
    Loads an INI file into an object indexed by INI section and parameter key.
    
    Parameters:
        fileName(string): the file to load
        
    Returns:
        table indexing INI file, based on result[section][param] = value
        
    References:
        https://github.com/Dynodzzo/Lua_INI_Parser/blob/master/LIP.lua
]]
function exports.load_ini(fileName)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.')
    local file = io.open(fileName, 'r')
    if not file then return nil end

    local data = {};
    local section;
    for line in file:lines() do
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if tempSection then
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            data[section] = data[section] or {}
        end

        local param, value = line:match('^%s-([%w|_]+)%s-=%s+(.+)$')
        if(param and value ~= nil)then
            if(tonumber(value))then
                value = tonumber(value);
            elseif(value == 'true')then
                value = true;
            elseif(value == 'false')then
                value = false;
            end
            if(tonumber(param))then
                param = tonumber(param);
            end
            data[section][param] = value
        end
    end
    file:close();
    return data;
end

--[[
    Gets a config item from a table previously loaded by using load_ini.
    
    Parameters:
        ini(table): the ini table
        section(string): the ini section in which the key being looked up is located
        key(string): the key whose value is being looked up
        
    Returns:
        the value of ini[section][key] or nil if either the key or section aren't present
]]
function exports.get_config(ini, section, key)
    local l = ini[section]
    return l and l[key] or nil
end

-----------------
-- other stuff --
-----------------

--[[
    Prints an object as a string after running it through inspect.lua
    
    Parameters:
        obj(any): the object to print
        
    Returns(void)
    
    References:
        https://github.com/kikito/inspect.lua
]]
function exports.printi(obj)
    print(inspect(obj))
end

-- get utf8 char with hex code, u'XXXX' is analagous to '\uXXXX' in javascript (for BMP characters
-- at least)
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
    right_arrow = u'fc32', -- arrow pointing right, git remote target icon
}


return exports
