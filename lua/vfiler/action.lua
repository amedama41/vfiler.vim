local core = require 'vfiler/core'
local vim = require 'vfiler/vim'

local actions = {}

local M = {}

function M.do_action(name, context, view, args)
  if not actions[name] then
    core.error(string.format('Action "%s" is not defined', name))
    return
  end
  actions[name](context, view, args)
end

function M.define(name, func)
  actions[name] = func
end

function M.undefine(name, func)
  actions[name] = nil
end

function actions.change_directory(context, view, args)
  -- special path
  local path = args[1]
  if path == '..' then
    -- change parent directory
    path = vim.fn.fnamemodify(context.path, ':h')
  end
  context:switch(path)
  view.draw(context)
end

function actions.move_cursor(context, view, lnum)
end

function actions.open(context, view, args)
  local lnum = args[1] or vim.fn.line('.')
  local item = context:get_item(lnum)
  if not item then
    core.warning('Item does not exist.')
    return
  end

  if item.isdirectory then
    actions.change_directory(context, view, {item.path})
  else
    vim.command('edit ' .. item.path)
  end
end

function actions.open_tree(context, view, args)
  local lnum = args[1] or vim.fn.line('.')
  context:open_directory(lnum)
  view.draw(context)
end

function actions.start(context, view, args)
  actions.change_directory(context, view, args)
  vim.fn['vfiler#define_keymap']()
end

return M
