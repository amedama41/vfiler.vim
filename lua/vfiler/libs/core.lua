local vim = require('vfiler/libs/vim')

local M = {}

------------------------------------------------------------------------------
-- Core
------------------------------------------------------------------------------
M.is_cygwin = vim.fn.has('win32unix') == 1
M.is_windows = vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1
M.is_mac = not M.is_windows
  and not M.is_cygwin
  and (
    (vim.fn.has('mac') == 1)
    or (vim.fn.has('macunix') == 1)
    or (vim.fn.has('gui_macvim') == 1)
    or (vim.fn.isdirectory('/proc') ~= 1)
      and (vim.fn.executable('sw_vers') == 1)
  )
M.is_nvim = vim.fn.has('nvim') == 1

function M.inherit(class, super, ...)
  local self = super and super.new(...) or nil
  if not self then
    return nil
  end
  setmetatable(self, { __index = class })
  setmetatable(class, { __index = super })
  return self
end

function M.try(block)
  local try = block[1]
  assert(try)
  local catch = block.catch
  local finally = block.finally

  local ok, errors = pcall(try)
  if not ok and catch then
    catch(errors)
  end
  if finally then
    finally()
  end
end

function M.system(expr)
  local result
  local shell = vim.get_option('shell')
  M.try({
    function()
      if M.is_windows then
        vim.set_option('shell', 'cmd.exe')
      end
      result = vim.fn.system(expr)
    end,
    finally = function()
      vim.set_option('shell', shell)
    end,
  })
  return result
end

------------------------------------------------------------------------------
-- Cursor
------------------------------------------------------------------------------
M.cursor = {}

-- @param lnum number
function M.cursor.move(lnum)
  vim.fn.cursor(lnum, 1)
end

--@param window number
--@param lnum number
function M.cursor.winmove(window, lnum)
  vim.fn.win_execute(window, ('call cursor(%d, 1)'):format(lnum), 'silent')
end

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------
M.window = {}

local open_layout_commands = {
  edit = 'edit',
  none = 'edit',
  bottom = 'belowright split',
  left = 'aboveleft vertical split',
  right = 'belowright vertical split',
  tab = 'tabnew',
  top = 'aboveleft split',
}

---@param winid number
function M.window.move(winid, autocmd)
  assert(winid >= 0)
  local command = ('call win_gotoid(%d)'):format(winid)
  if not autocmd then
    command = 'noautocmd ' .. command
  end
  vim.command(command)
end

---@param layout string
---@param file? string
function M.window.open(layout, file)
  local command = open_layout_commands[layout]
  if not command then
    M.message.error('Illegal "%s" open layout.', layout)
    return false
  end

  if file then
    command = command .. ' ' .. vim.fn.fnameescape(file)
  end
  local ok = pcall(vim.command, command)
  return ok
end

---@param height number
function M.window.resize_height(winnr, height)
  assert(winnr >= 0)
  vim.fn.execute(('%dresize %d'):format(winnr, height), 'silent!')
end

---@param width number
function M.window.resize_width(winnr, width)
  assert(winnr >= 0)
  vim.fn.execute(('vertical %dresize %d'):format(winnr, width), 'silent!')
end

------------------------------------------------------------------------------
-- Message
------------------------------------------------------------------------------
M.message = {}

---@param msg string
---@return string
local function escape_quote(msg)
  local result, _ = msg:gsub([[']], [['']])
  return result
end

---print error message
function M.message.error(format, ...)
  local msg = format:format(...)
  vim.command(
    ([[echohl ErrorMsg | echomsg '[vfiler]: %s' | echohl None]]):format(
      escape_quote(msg)
    )
  )
end

---print information message
function M.message.info(format, ...)
  vim.command(
    ([[echo '[vfiler]: %s']]):format(escape_quote(format:format(...)))
  )
end

---print warning message
function M.message.warning(format, ...)
  local msg = format:format(...)
  vim.command(
    ([[echohl WarningMsg | echomsg '[vfiler]: %s' | echohl None]]):format(
      escape_quote(msg)
    )
  )
end

---print question message
function M.message.question(format, ...)
  local msg = format:format(...)
  vim.command(
    ([[echohl Question | echo '[vfiler]: %s' | echohl None]]):format(
      escape_quote(msg)
    )
  )
end

------------------------------------------------------------------------------
-- Path utilities
------------------------------------------------------------------------------
M.path = {}

function M.path.escape(path)
  return path:gsub('\\', '/')
end

function M.path.exists(path)
  return M.path.filereadable(path) or M.path.is_directory(path)
end

function M.path.extension(path)
  return vim.fn.fnamemodify(path, ':e')
end

function M.path.filereadable(path)
  return vim.fn.filereadable(path) == 1
end

function M.path.is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

function M.path.is_unc(path)
  return (path:match('^//') or path:match('^\\\\')) and true or false
end

function M.path.join(path, name)
  path = M.path.escape(path)
  if path:sub(#path, #path) ~= '/' then
    path = path .. '/'
  end

  name = M.path.escape(name)
  if name:sub(1, 1) == '/' then
    name = name:sub(2)
  end
  return path .. name
end

function M.path.name(path)
  local mods = path:sub(-1) == '/' and ':h:t' or ':t'
  return vim.fn.fnamemodify(path, mods)
end

function M.path.normalize(path)
  if path == '/' then
    return '/'
  end
  path = M.path.escape(vim.fn.fnamemodify(path, ':p'))
  if M.path.is_unc(path) then
    -- for UNC path
    return '//' .. path:sub(3):gsub('/+', '/')
  end
  return path:gsub('/+', '/')
end

function M.path.parent(path)
  if M.path.is_unc(path) then
    -- for UNC path
    local seps = M.string.count_char(path:sub(3), '/')
    if seps < 2 then
      return M.path.normalize(path)
    elseif seps == 2 then
      -- example: //unc/foo/
      return M.path.normalize(vim.fn.fnamemodify(path, ':h'))
    end
  end
  local mods = path:sub(-1) == '/' and ':h:h' or ':h'
  return M.path.normalize(vim.fn.fnamemodify(path, mods))
end

function M.path.root(path)
  local root = ''
  if M.is_windows then
    path = M.path.normalize(path)
    if M.path.is_unc(path) then
      -- for UNC path
      root = path:match('^//%a+')
    else
      root = path:match('^%a+:')
    end
  end
  return root .. '/'
end

------------------------------------------------------------------------------
-- Syntax and Highlight command utilities
------------------------------------------------------------------------------
M.syntax = {}
M.highlight = {}

local function get_syntax_option_string(options)
  if not options then
    return ''
  end

  local option_strings = {}
  for key, value in pairs(options) do
    local option
    if type(value) == 'boolean' then
      option = key
    elseif type(value) == 'table' then
      option = ('%s=%s'):format(key, table.concat(value, ','))
    else
      option = ('%s=%s'):format(key, value)
    end
    table.insert(option_strings, option)
  end
  return table.concat(option_strings, ' ')
end

function M.syntax.clear(group)
  if type(group) == 'table' then
    group = table.concat(group, ' ')
  end
  return 'silent! syntax clear ' .. group
end

function M.syntax.create(group, pattern, options)
  local cmd = 'syntax '
  if pattern.match then
    cmd = cmd .. ('match %s "%s"'):format(group, pattern.match)
  elseif pattern.keyword then
    cmd = cmd .. ('keyword %s %s'):format(group, pattern.keyword)
  elseif pattern.region then
    local region = pattern.region
    cmd = cmd .. 'region ' .. group .. ' '
    if region.matchgroup then
      cmd = cmd .. 'matchgroup=' .. region.matchgroup .. ' '
    end
    cmd = cmd
      .. ('start="%s" end="%s"'):format(
        region.start_pattern,
        region.end_pattern
      )
  end
  if options then
    cmd = cmd .. ' ' .. get_syntax_option_string(options)
  end
  return cmd
end

---Generate highlight command string
---@param name string
---@param args table
function M.highlight.create(name, args)
  if not args then
    return ''
  end
  local command = ('highlight! default %s'):format(name)
  for key, value in pairs(args) do
    command = command .. (' %s=%s'):format(key, value)
  end
  return command
end

---Generate highlight command string
---@param from string
---@param to string
---@return string
function M.highlight.link(from, to)
  return ('highlight! default link %s %s'):format(from, to)
end

------------------------------------------------------------------------------
-- autocmd command utilities
------------------------------------------------------------------------------
M.autocmd = {}

--- Generate a command to define a group name for "autocmd".
---@param name string
---@return string
function M.autocmd.start_group(name)
  return 'augroup ' .. name
end

--- Generate group name definition end command for "autocmd".
---@return string
function M.autocmd.end_group()
  return 'augroup END'
end

--- Generate commands for delete "autocmd".
---@param name string
---@return string
function M.autocmd.delete_group(name)
  return 'augroup! ' .. name
end

--- Generate commands that define automatic commands.
---@param event string or list
---@param cmd string
---@param options table
function M.autocmd.create(event, cmd, options)
  if type(event) == 'table' then
    event = table.concat(event, ',')
  end
  local commands = { 'autocmd! ' .. event }

  -- Options
  if options then
    if options.buffer ~= nil then
      local buffer = options.buffer
      if buffer == 0 then
        table.insert(commands, '<buffer>')
      elseif type(buffer) == 'number' then
        table.insert(commands, '<buffer=' .. buffer .. '>')
      elseif type(buffer) == 'string' and buffer == 'abuf' then
        table.insert(commands, '<buffer=abuf>')
      else
        M.message.error('Unknown "buffer" option.')
        return nil
      end
    elseif options.pattern then
      table.insert(commands, options.pattern)
    else
      table.insert(commands, '*')
    end

    if options.once then
      table.insert(commands, '++once')
    end
    if options.nested then
      table.insert(commands, '++nested')
    end
  else
    table.insert(commands, '*')
  end

  table.insert(commands, cmd)
  return table.concat(commands, ' ')
end

--- Generate commands delete automatic commands.
function M.autocmd.delete(name)
  return 'autocmd! ' .. name
end

------------------------------------------------------------------------------
-- String utilities
------------------------------------------------------------------------------
M.string = {}

-- truncate string
local function strwidthpart(str, width)
  local vcol = width + 2
  return vim.fn.matchstr(str, '.*\\%<' .. vcol .. 'v')
end

local function strwidthpart_reverse(str, strwidth, width)
  local vcol = strwidth - width
  return vim.fn.matchstr(str, '\\%>' .. vcol .. 'v.*')
end

local function truncate(str, width)
  local bytes = { str:byte(1, #str) }
  for _, byte in ipairs(bytes) do
    if (0 > byte) or (byte > 127) then
      return strwidthpart(str, width)
    end
  end
  return str:sub(1, width)
end

function M.string.compare(str1, str2)
  local length = math.min(#str1, #str2)
  for i = 1, length do
    local word1 = (str1:sub(i, i)):lower()
    local word2 = (str2:sub(i, i)):lower()

    if word1 < word2 then
      return true
    elseif word1 > word2 then
      return false
    end
  end
  return (#str1 - #str2) < 0
end

function M.string.count_char(s, c)
  return #vim.fn.split(s, c, 1) - 1
end

function M.string.is_keycode(s)
  return s:match('^<.+>$') ~= nil
end

-- Lua pettern escape
function M.string.pesc(s)
  local replaced = s:gsub('([%^%(%)%[%]%*%+%-%?%.%%])', '%%%1')
  return replaced
end

--- Replace keycode (<CR>, <Esc>, ...)
M.string.replace_keycode = vim.fn['vfiler#core#replace_keycode']

function M.string.split(str, pattern)
  return vim.list.from(vim.fn.split(str, pattern))
end

function M.string.truncate(str, width, sep, footer_width)
  local strwidth = vim.fn.strwidth(str)
  if strwidth <= width then
    return str
  end
  footer_width = footer_width or 0
  local header_width = width - vim.fn.strwidth(sep) - footer_width
  local replaced = str:gsub('\t', '')
  local result = strwidthpart(replaced, header_width)
    .. sep
    .. strwidthpart_reverse(replaced, strwidth, footer_width)
  return truncate(result, width)
end

-- Escape because of the vim pattern
function M.string.vesc(s)
  return s:gsub('([%[%]\\^*$.~])', '\\%1')
end

------------------------------------------------------------------------------
-- Table and List
------------------------------------------------------------------------------
M.list = {}
M.table = {}

function M.list.indexof(list, value)
  for i, v in ipairs(list) do
    if v == value then
      return i
    end
  end
  return -1
end

function M.list.extend(dest, src)
  local pos = #dest
  for i = 1, #src do
    table.insert(dest, pos + i, src[i])
  end
  return dest
end

function M.list.unique(src)
  local unique = {}
  for _, v1 in ipairs(src) do
    local exists = false
    for _, v2 in ipairs(unique) do
      if v1 == v2 then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(unique, v1)
    end
  end
  return unique
end

function M.table.copy(src)
  local copied
  if type(src) == 'table' then
    copied = {}
    for key, value in next, src, nil do
      copied[M.table.copy(key)] = M.table.copy(value)
    end
    setmetatable(copied, M.table.copy(getmetatable(src)))
  else -- number, string, boolean, etc
    copied = src
  end
  return copied
end

function M.table.inspect(t, level, indent)
  indent = indent or 0
  for key, value in pairs(t) do
    local info = ('%s %s : %s'):format(('-'):rep(indent), key, value)
    print(info)
    if type(value) == 'table' and level > 0 then
      M.table.inspect(value, level - 1, indent + 1)
    end
  end
end

function M.table.merge(dest, src)
  if not src then
    return dest
  end
  for key, value in pairs(src) do
    if type(value) == 'table' then
      if not dest[key] then
        dest[key] = {}
      end
      M.table.merge(dest[key], value)
    else
      dest[key] = value
    end
  end
  return dest
end

------------------------------------------------------------------------------
-- Math utilities
------------------------------------------------------------------------------
M.math = {}

-- Within the max and min between
function M.math.within(v, min, max)
  return math.max(math.min(v, max), min)
end

--- Returns "integer" if the argument is an integer,
--- "float" if it is a floating point number,
--- and nil if the argument is not a number.
function M.math.type(x)
  if type(x) ~= 'number' then
    return nil
  end
  return tostring(x):match('%d+%.%d+') and 'float' or 'integer'
end

------------------------------------------------------------------------------
-- Icon
------------------------------------------------------------------------------
M.icon = {}

-- stylua: ignore
local frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏', }

function M.icon.frame(sec)
  local index = (math.floor(sec * 10) % #frames) + 1
  return frames[index]
end

return M
