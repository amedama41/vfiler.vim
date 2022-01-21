local core = require('vfiler/libs/core')
local vim = require('vfiler/libs/vim')

local Floating = {}

function Floating.new()
  local Base = require('vfiler/views/base')
  local self = core.inherit(Floating, Base)
  self._configs = {}
  return self
end

function Floating:set_config(key, value)
  self._configs[key] = value
end

function Floating:_create_title(title, win_options)
  local options, title_name = self:_get_title_options(title, win_options)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local winid = vim.api.nvim_open_win(bufnr, false, options)

  -- set options
  vim.api.nvim_win_set_option(
    winid,
    'winhighlight',
    'Normal:vfilerFloatingWindowTitle'
  )
  vim.api.nvim_win_set_option(winid, 'cursorline', false)

  -- set title name
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, { title_name })

  self._title = {
    bufnr = bufnr,
    winid = winid,
  }
end

function Floating:_get_title_options(title, win_options)
  local title_name = ' ' .. title .. ' '
  local title_options = {
    col = win_options.col + 1,
    focusable = false,
    height = 1,
    noautocmd = false,
    relative = win_options.relative,
    row = win_options.row,
    zindex = win_options.zindex + 1,
    width = #title_name,
  }
  if title_options.relative == 'win' then
    title_options.win = self.src_winid
  end
  return title_options, title_name
end

function Floating:_get_win_options(options)
  local win_options = {
    border = 'rounded',
    col = options.col,
    focusable = true,
    height = options.height,
    noautocmd = false,
    relative = 'editor',
    row = options.row,
    width = options.width,
    zindex = 200,
  }
  for key, value in pairs(self._configs) do
    win_options[key] = value
  end
  return win_options
end

function Floating:_on_close(winid, buffer)
  if winid > 0 then
    vim.api.nvim_win_close(winid, true)
  end
  if self._title then
    vim.api.nvim_win_close(self._title.winid, true)
    self._title = nil
  end
end

function Floating:_on_open(buffer, options)
  local win_options = self:_get_win_options(options)
  local winid = vim.api.nvim_open_win(buffer.number, true, win_options)

  -- set options
  vim.api.nvim_win_set_option(winid, 'winhighlight', 'Normal:Normal')
  vim.api.nvim_win_set_option(winid, 'number', false)

  -- open title window
  if options.title then
    self:_create_title(options.title, win_options)
  end
  return winid
end

function Floating:_on_update(winid, buffer, options)
  if buffer.number ~= vim.api.nvim_win_get_buf(winid) then
    vim.api.nvim_win_set_buf(winid, buffer.number)
  end
  local win_options = self:_get_win_options(options)
  win_options.noautocmd = nil
  vim.api.nvim_win_set_config(winid, win_options)
  self:_update_title(options.title, win_options)
  return winid
end

function Floating:_update_title(title, win_options)
  local options, title_name = self:_get_title_options(title, win_options)
  options.noautocmd = nil
  vim.api.nvim_win_set_config(self._title.winid, options)
  vim.api.nvim_buf_set_lines(self._title.bufnr, 0, -1, true, { title_name })
end

return Floating
