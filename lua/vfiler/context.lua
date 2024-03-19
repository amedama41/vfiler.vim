local core = require('vfiler/libs/core')
local fs = require('vfiler/libs/filesystem')
local vim = require('vfiler/libs/vim')

local Directory = require('vfiler/items/directory')
local Git = require('vfiler/git')
local History = require('vfiler/libs/history')

------------------------------------------------------------------------------
-- ItemAttribute class
------------------------------------------------------------------------------
local ItemAttribute = {}
ItemAttribute.__index = ItemAttribute

function ItemAttribute.copy(attribute)
  local root_attr = ItemAttribute.new(attribute.name)
  for name, attr in pairs(attribute.opened_attributes) do
    root_attr.opened_attributes[name] = ItemAttribute.copy(attr)
  end
  for name, selected in pairs(attribute.selected_names) do
    root_attr.selected_names[name] = selected
  end
  return root_attr
end

function ItemAttribute.parse(root)
  local root_attr = ItemAttribute.new(root.name)
  if not root.children then
    return root_attr
  end
  for _, child in ipairs(root.children) do
    if child.opened then
      root_attr.opened_attributes[child.name] = ItemAttribute.parse(child)
    end
    if child.selected then
      root_attr.selected_names[child.name] = true
    end
  end
  return root_attr
end

function ItemAttribute.new(name)
  return setmetatable({
    name = name,
    opened_attributes = {},
    selected_names = {},
  }, ItemAttribute)
end

------------------------------------------------------------------------------
-- Session class
------------------------------------------------------------------------------
local Session = {}
Session.__index = Session

local shared_attributes = {}
local shared_drives = {}
local shared_history = History.new(100)

function Session.new(type)
  local attributes
  if type == 'buffer' then
    attributes = {}
  elseif type == 'share' then
    attributes = shared_attributes
  end

  local drives
  if type == 'share' then
    drives = shared_drives
  else
    drives = {}
  end

  local history
  if type == 'share' then
    history = shared_history
  else
    history = History.new(100)
  end

  return setmetatable({
    _type = type,
    _attributes = attributes,
    _drives = drives,
    _history = history,
  }, Session)
end

function Session._open(root, attribute)
  for _, child in ipairs(root.children) do
    local opened = attribute.opened_attributes[child.name]
    if opened then
      child:open()
      Session._open(child, opened)
    end

    local selected = attribute.selected_names[child.name]
    if selected then
      child.selected = true
    end
  end
  return root
end

function Session:copy()
  local new = Session.new(self._type)
  if new._type ~= 'share' then
    new._drives = core.table.copy(self._drives)
    new._history = self._history:copy()
  end

  if new._type == 'buffer' then
    for path, attribute in pairs(self._attributes) do
      new._attributes[path] = {
        previus_path = attribute.previus_path,
        object = ItemAttribute.copy(attribute.object),
      }
    end
  end
  return new
end

function Session:save(root, path)
  local drive = core.path.root(root.path)
  self._drives[drive] = root.path
  if self._attributes then
    self._attributes[root.path] = {
      previus_path = path,
      object = ItemAttribute.parse(root),
    }
  end
end

function Session:load(root)
  self._history:save(root.path)
  if not self._attributes then
    return nil
  end
  local attribute = self._attributes[root.path]
  if not attribute then
    return nil
  end
  Session._open(root, attribute.object)
  return attribute.previus_path
end

function Session:get_path_in_drive(drive)
  local dirpath = self._drives[drive]
  if not dirpath then
    return nil
  end
  return dirpath
end

function Session:directory_history()
  return self._history:items()
end

------------------------------------------------------------------------------
-- Context class
------------------------------------------------------------------------------

local function walk_directories(root)
  local function walk(item)
    if item.children then
      for _, child in ipairs(item.children) do
        if child.type == 'directory' then
          walk(child)
          coroutine.yield(child)
        end
      end
    end
  end
  return coroutine.wrap(function()
    walk(root)
  end)
end

local Context = {}
Context.__index = Context

--- Create a context object
---@param configs table
function Context.new(configs)
  local self = setmetatable({}, Context)
  self:_initialize()
  self.options = core.table.copy(configs.options)
  self.events = core.table.copy(configs.events)
  self.mappings = core.table.copy(configs.mappings)
  self.git = Git.new(self.options.git)
  self._session = Session.new(self.options.session)
  return self
end

--- Copy to context
function Context:copy()
  local configs = {
    options = self.options,
    events = self.events,
    mappings = self.mappings,
  }
  local new = Context.new(configs)
  new._session = self._session:copy()
  return new
end

--- Open the tree recursively according to the specified path
---@param path string
function Context:open_tree(path)
  path = core.path.normalize(path)
  local s, e = path:find(self.root.path)
  if not s then
    return nil
  end
  -- extract except for path separator
  local names = vim.fn.split(path:sub(e + 1), '/')
  if #names == 0 then
    return nil
  end
  local directory = self.root
  for i, name in ipairs(names) do
    for _, child in pairs(directory.children) do
      if name == child.name then
        if child.type == 'directory' then
          if i == #names then
            return child
          else
            if not child.opened then
              child:open()
            end
            directory = child
            break
          end
        else
          return child
        end
      end
    end
  end
  return nil
end

--- Save the path in the current context
---@param path string
function Context:save(path)
  if not self.root then
    return
  end
  self._session:save(self.root, path)
end

--- Get the parent directory path of the current context
function Context:parent_path()
  if self.root.parent then
    return self.root.parent.path
  end
  return core.path.parent(self.root.path)
end

-- Rerform auto cd
function Context:perform_auto_cd()
  if self.options.auto_cd then
    vim.fn.execute('lcd ' .. vim.fn.fnameescape(self.root.path), 'silent')
  end
end

-- Reload the current directory path
---@param reload_all_dir boolean
function Context:reload(reload_all_dir)
  local root_path = self.root.path
  if reload_all_dir or vim.fn.getftime(root_path) > self.root.time then
    self:switch(root_path)
    return
  end
  for dir in walk_directories(self.root) do
    if dir.opened then
      if vim.fn.getftime(dir.path) > dir.time then
        dir:update()
        dir:open()
      end
    end
  end
end

--- Switch the context to the specified directory path
---@param dirpath string
function Context:switch(dirpath)
  dirpath = core.path.normalize(dirpath)
  self.root = Directory.new(fs.stat(dirpath))
  self.root:open()

  local path = self._session:load(self.root)
  self:perform_auto_cd()
  return path
end

--- Switch the context to the specified drive path
---@param drive string
function Context:switch_drive(drive)
  local dirpath = self._session:get_path_in_drive(drive)
  if not dirpath then
    dirpath = drive
  end
  return self:switch(dirpath)
end

--- Update from another context
---@param context table
function Context:update(context)
  self.options = core.table.copy(context.options)
  self.mappings = core.table.copy(context.mappings)
  self.events = core.table.copy(context.events)
end

--- Get directory history
function Context:directory_history()
  return self._session:directory_history()
end

function Context:_initialize()
  self.extension = nil
  self.linked = nil
  self.root = nil
  self.in_preview = {
    preview = nil,
    once = false,
  }
end

return Context
