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

------------------------------------------------------------------------------
-- File and Directory
------------------------------------------------------------------------------
M.cursor = {}

-- @param lnum number
function M.cursor.move(lnum)
  vim.fn.cursor(lnum, 1)
end

--@param window number
--@param lnum number
function M.cursor.winmove(window, lnum)
  vim.fn.win_execute(window, ('call cursor(%d, 1)'):format(lnum))
end

------------------------------------------------------------------------------
-- File and Directory
------------------------------------------------------------------------------
M.dir = {}
M.file = {}

if M.is_windows then
  function M.dir.copy(src, dest)
    local command = ('robocopy /e %s %s'):format(
      M.string.shellescape(src),
      M.string.shellescape(dest)
    )
    vim.fn.system(command)
  end

  function M.file.copy(src, dest)
    local command = ('copy /y %s %s'):format(
      M.string.shellescape(src),
      M.string.shellescape(dest)
    )
    vim.fn.system(command)
  end
else
  function M.dir.copy(src, dest)
    local command = ('cp -fR %s %s'):format(
      M.string.shellescape(src),
      M.string.shellescape(dest)
    )
    vim.fn.system(command)
  end

  function M.file.copy(src, dest)
    local command = ('cp -f %s %s'):format(
      M.string.shellescape(src),
      M.string.shellescape(dest)
    )
    vim.fn.system(command)
  end
end

function M.file.execute(path)
  local command
  if M.is_windows then
    command = ('start rundll32 url.dll,FileProtocolHandler %s'):format(
      vim.fn.escape(path, '#%')
    )
  elseif M.is_mac and vim.fn.executable('open') == 1 then
    -- For Mac OS
    command = ('open %s &'):format(vim.fn.shellescape(path))
  elseif M.is_cygwin then
    -- For Cygwin
    command = ('cygstart %s'):format(vim.fn.shellescape(path))
  elseif vim.fn.executable('xdg-open') == 1 then
    -- For Linux
    command = ('xdg-open %s &'):format(vim.fn.shellescape(path))
  elseif
    os.getenv('KDE_FULL_SESSION')
    and os.getenv('KDE_FULL_SESSION') == 'true'
  then
    -- For KDE
    command = ('kioclient exec %s &'):format(vim.fn.shellescape(path))
  elseif os.getenv('GNOME_DESKTOP_SESSION_ID') then
    -- For GNOME
    command = ('gnome-open %s &'):format(vim.fn.shellescape(path))
  elseif vim.fn.executable('exo-open') == 1 then
    -- For Xfce
    command = ('exo-open %s &'):format(vim.fn.shellescape(path))
  else
    M.message.error('Not supported platform.')
    return
  end
  vim.fn.system(command)
end

function M.file.move(src, dest)
  os.rename(src, dest)
end

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------
M.window = {}

local open_layout = {
  edit = 'edit',
  bottom = 'belowright split',
  left = 'aboveleft vertical split',
  right = 'belowright vertical split',
  tab = 'tabnew',
  top = 'aboveleft split',
}

---@param winid number
function M.window.move(winid)
  assert(winid >= 0)
  vim.command(([[noautocmd call win_gotoid(%d)]]):format(winid))
end

---@param layout string
---@vararg string
function M.window.open(layout, ...)
  local dir = open_layout[layout]
  if not dir then
    M.message.error('Illegal "%s" open layout.', layout)
    return
  end

  local command = 'silent! ' .. dir
  if ... then
    command = ('%s %s'):format(command, ...)
  end
  vim.command(command)
end

---@param height number
function M.window.resize_height(winnr, height)
  assert(winnr >= 0)
  vim.command(('silent! %dresize %d'):format(winnr, height))
end

---@param width number
function M.window.resize_width(winnr, width)
  assert(winnr >= 0)
  vim.command(('silent! vertical %dresize %d'):format(winnr, width))
end

------------------------------------------------------------------------------
-- Message
------------------------------------------------------------------------------
M.message = {}

---print error message
function M.message.error(format, ...)
  local msg = format:format(...)
  vim.command(
    ([[echohl ErrorMsg | echomsg '[vfiler]: %s' | echohl None]]):format(msg)
  )
end

---print information message
function M.message.info(format, ...)
  vim.command(([[echo '[vfiler]: %s']]):format(format:format(...)))
end

---print warning message
function M.message.warning(format, ...)
  local msg = format:format(...)
  vim.command(
    ([[echohl WarningMsg | echomsg '[vfiler]: %s' | echohl None]]):format(msg)
  )
end

---print question message
function M.message.question(format, ...)
  local msg = format:format(...)
  vim.command(
    ([[echohl Question | echo '[vfiler]: %s' | echohl None]]):format(msg)
  )
end

------------------------------------------------------------------------------
-- Path utilities
------------------------------------------------------------------------------
M.path = {}

function M.path.escape(path)
  local replaced = path:gsub('\\', '/')
  return replaced
end

function M.path.exists(path)
  return M.path.filereadable(path) or M.path.isdirectory(path)
end

function M.path.filereadable(path)
  return vim.fn.filereadable(path) == 1
end

function M.path.isdirectory(path)
  return vim.fn.isdirectory(path) == 1
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
  return M.path.escape(vim.fn.fnamemodify(path, ':p'))
end

function M.path.parent(path)
  local mods = path:sub(-1) == '/' and ':h:h' or ':h'
  local parent = vim.fn.fnamemodify(path, mods)
  return M.path.normalize(parent)
end

function M.path.root(path)
  local root = ''
  if M.is_windows then
    if path:match('^//') then
      -- for UNC path
      root = path:match('^//[^/]*/[^/]*')
    else
      root = (M.path.normalize(path)):match('^%a+:')
    end
  end
  return root .. '/'
end

------------------------------------------------------------------------------
-- syntax and highlight command utilities
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
    if type(value) ~= 'boolean' then
      option = ('%s=%s'):format(key, value)
    else
      option = key
    end
    table.insert(option_strings, option)
  end
  return table.concat(option_strings, ' ')
end

function M.syntax.clear_command(names)
  return ('silent! syntax clear %s'):format(table.concat(names, ' '))
end

function M.syntax.match_command(name, pattern, options)
  local command = ('syntax match %s /%s/'):format(name, pattern)
  local option = get_syntax_option_string(options or {})
  if #option > 0 then
    command = command .. ' ' .. option
  end
  return command
end

function M.syntax.region_command(name, startp, endp, matchgroup, options)
  local command = 'syntax region ' .. name
  if matchgroup and #matchgroup > 0 then
    command = command .. ' matchgroup=' .. matchgroup
  end
  command = command .. (' start=/%s/ end=/%s/'):format(startp, endp)
  local option = get_syntax_option_string(options or {})
  if #option > 0 then
    command = command .. ' ' .. option
  end
  return command
end

---Generate highlight command string
---@param name string
---@param args table
function M.highlight.command(name, args)
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
function M.highlight.link_command(from, to)
  return ('highlight! default link %s %s'):format(from, to)
end

------------------------------------------------------------------------------
-- String utilities
------------------------------------------------------------------------------
M.string = {}

local function trim_end(str, char)
  if str:sub(#str, #str) == char then
    return str:sub(1, #str - 1)
  end
  return str
end

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

-- Lua pettern escape
function M.string.pesc(s)
  local replaced = s:gsub('([%^%(%)%[%]%*%+%-%?%.%%])', '%%%1')
  return replaced
end

if M.is_windows then
  function M.string.shellescape(str)
    return ('"%s"'):format(trim_end(vim.fn.escape(str:gsub('/', [[\]])), '/'))
  end
else
  function M.string.shellescape(str)
    return vim.fn.shellescape(trim_end(str))
  end
end

function M.string.split(str, pattern)
  return vim.from_vimlist(vim.fn.split(str, pattern))
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
  return s:gsub('([\\^*$.~])', '\\%1')
end

------------------------------------------------------------------------------
-- Table and List
------------------------------------------------------------------------------
M.list = {}
M.table = {}

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
  return math.min(math.max(v, min), max)
end

------------------------------------------------------------------------------
-- Icon
------------------------------------------------------------------------------
M.icon = {}

local frames = {
  '⠋',
  '⠙',
  '⠹',
  '⠸',
  '⠼',
  '⠴',
  '⠦',
  '⠧',
  '⠇',
  '⠏',
}

function M.icon.frame(sec)
  local index = (math.floor(sec * 10) % #frames) + 1
  return frames[index]
end

return M