local config = require('vfiler/config')
local core = require('vfiler/libs/core')
local event = require('vfiler/event')
local vim = require('vfiler/libs/vim')

local VFiler = require('vfiler/vfiler')

local M = {}

local function open(configs, dirpath)
  local options = configs.options

  -- Find a file in the active buffer
  local filepath
  if options.find_file then
    filepath = vim.fn.expand('%:p')
  end

  local Context = require('vfiler/context')
  local context = Context.new(configs)
  local vfiler = VFiler.find_visible(options.name)
  if not options.new and vfiler then
    vfiler:focus()
    vfiler:update(context)
  else
    vfiler = VFiler.find_hidden(options.name)
    if options.new or not vfiler then
      vfiler = VFiler.new(context)
    else
      vfiler:update(context)
    end
    vfiler:open(options.layout)
  end
  vfiler:start(dirpath, filepath)
  return true
end

local function toggle(configs, dirpath)
  local vfilers = VFiler.get_visible_in_tabpage(0)
  if #vfilers > 0 then
    for _, vfiler in ipairs(vfilers) do
      vfiler:quit()
    end
    return true
  end
  return open(configs, dirpath)
end

--- Start vfiler from command line arguments
---@param args string: command line argumets
---@return boolean
function M.start_command(args)
  local options, dirpath = config.parse_options(args)
  if not options then
    return false
  end
  return M.start(dirpath, { options = options })
end

--- Start vfiler
---@param dirpath? string
---@param configs? table
---@return boolean
function M.start(dirpath, configs)
  if not dirpath or #dirpath <= 0 then
    dirpath = vim.fn.getcwd()
  end
  dirpath = vim.fn.fnamemodify(dirpath, ':p')
  if not core.path.is_directory(dirpath) then
    core.message.error('Does not exist "%s".', dirpath)
    return false
  end
  local merged_configs = core.table.copy(config.configs)
  core.table.merge(merged_configs, configs or {})

  -- Preparation before starting
  VFiler.cleanup()
  event.start()

  -- Correction of option values
  local options = merged_configs.options
  if not core.is_nvim then
    if options.layout == 'floating' then
      core.message.warning('Vim does not support floating windows.')
      options.layout = 'none'
    end
  end

  if options.toggle then
    return toggle(merged_configs, dirpath)
  end
  return open(merged_configs, dirpath)
end

--- Get current status
---@param bufnr number: buffer number.
--     If `0` is specified, status on the current buffer is returned.
---@return table
function M.status(bufnr)
  local number = (not bufnr or bufnr == 0) and vim.fn.bufnr() or bufnr
  local current = VFiler.get(number)
  if not current then
    return vim.dict({})
  end
  return current:status()
end

return M
