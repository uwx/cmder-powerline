local utils = require 'utils'
local symbols = utils.symbols

local JSON = require 'clink-completions.modules.JSON'

return function(old_prompt)
    local package_file = utils.get_file_contains(nil, 'package.json')
    if not package_file then return nil end

    local package_data = utils.read_all_text(package_file)
    if not package_data then return nil end

    local pkg = JSON:decode(package_data)
    -- Bail out if package.json is malformed
    if not pkg then return nil end
    -- Don't print package info when both version and name are missing
    if not pkg.name and not pkg.version then return nil end

    local package_name = pkg.name or '<no name>'
    local package_version = pkg.version and '@' .. pkg.version or ''
    
    return {
        fg = 'bright_white',
        bg = 'cyan',
        value = package_name .. package_version
    }
end
