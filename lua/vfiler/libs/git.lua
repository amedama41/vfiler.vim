local core = require('vfiler/libs/core')
local vim = require('vfiler/libs/vim')

local Job = require('vfiler/libs/async/job')

local M = {}

local function create_status_commands(rootpath, path, options)
  local commands = {
    'git',
    '-C',
    rootpath,
    '--no-optional-locks',
    'status',
    '--porcelain=v1',
  }

  -- Options
  if options.untracked then
    table.insert(commands, '-u')
  end
  if options.ignored then
    table.insert(commands, '--ignored=matching')
  else
    table.insert(commands, '--ignored=no')
  end

  -- path
  if path then
    table.insert(commands, path)
  end
  return commands
end

local function create_toplevel_commands(dirpath)
  return {
    'git',
    '-C',
    dirpath,
    'rev-parse',
    '--show-toplevel',
  }
end

local function parse_git_status(rootpath, result)
  local status = result:sub(1, 2)
  local rpath = result:sub(4, -1)
  -- for renamed
  local splitted = vim.list.from(vim.fn.split(rpath, ' -> '))
  rpath = splitted[#splitted]
  -- Removing: extra characters
  rpath = rpath:gsub('^"', ''):gsub('"$', '')
  return core.path.join(rootpath, rpath),
    { us = status:sub(1, 1), them = status:sub(2, 2) }
end

local function parse_toplevel_path(result)
  if (not result or #result == 0) or result:match('fatal:%s') then
    return nil
  end
  return core.path.normalize(result:sub(0, -1))
end

local function update_directory_statuses(rootpath, statuses)
  local function update(dirstatus, status)
    if status.us == '!' then
      return
    end
    if status.us ~= ' ' and status.us ~= '?' then
      dirstatus.us = '*'
    end
    if status.them ~= ' ' then
      dirstatus.them = '*'
    end
  end

  local dirs = {}
  for path, status in pairs(statuses) do
    local modified = core.path.parent(path)
    local dirstatus = dirs[modified]
    if not dirstatus then
      dirstatus = {
        us = ' ',
        them = ' ',
      }
      dirs[modified] = dirstatus
    end
    update(dirstatus, status)
  end

  for path, status in pairs(dirs) do
    while rootpath ~= path do
      local dirstatus = statuses[path]
      if dirstatus then
        update(dirstatus, status)
      else
        statuses[path] = {
          us = status.us,
          them = status.them,
        }
      end
      path = core.path.parent(path)
    end
  end
  return statuses
end

function M.get_toplevel(dirpath)
  local commands = create_toplevel_commands('"' .. dirpath .. '"')
  local result = core.system(table.concat(commands, ' '))
  return parse_toplevel_path(vim.fn.trim(result, ''))
end

function M.get_toplevel_async(dirpath, on_completed)
  local commands = create_toplevel_commands(dirpath)
  local toplevel_path
  local job = Job.new()
  job:start(commands, {
    on_received = function(_, result)
      toplevel_path = parse_toplevel_path(result)
    end,

    on_completed = function(_, code)
      on_completed(toplevel_path)
    end,
  })
  return job
end

function M.reload_status_async(rootpath, options, on_completed)
  local commands = create_status_commands(rootpath, nil, options)
  local gitstatus = {}
  local job = Job.new()
  job:start(commands, {
    on_received = function(_, result)
      local path, status = parse_git_status(rootpath, result)
      gitstatus[path] = status
    end,

    on_completed = function(_, code)
      update_directory_statuses(rootpath, gitstatus)
      on_completed(gitstatus)
    end,
  })
  return job
end

function M.reload_status_file(rootpath, path, options)
  local commands = create_status_commands(
    '"' .. rootpath .. '"',
    '"' .. path .. '"',
    options
  )
  local result = core.system(table.concat(commands, ' '))
  if #result == 0 then
    return nil
  end

  local gitstatus = {}
  local _, status = parse_git_status(rootpath, result)
  gitstatus[path] = status
  update_directory_statuses(rootpath, gitstatus)
  return gitstatus
end

return M
