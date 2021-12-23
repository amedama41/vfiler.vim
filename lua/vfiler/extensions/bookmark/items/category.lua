local core = require('vfiler/core')
local vim = require('vfiler/vim')

local Item = require('vfiler/extensions/bookmark/items/item')

local Category = {}
Category.__index = Category
Category.__eq = function(a, b)
  return a.name == b.name
end

function Category.new(name)
  return setmetatable({
    children = {},
    name = name,
    iscategory = true,
    level = 1,
    opened = true,
    parent = nil,
  }, Category)
end

function Category.from_json(json)
  local document = vim.fn.json_decode(json)
  if not document.bookmarks then
    return nil
  end
  local root = Category.new('root')
  for _, category_dict in ipairs(document.bookmarks) do
    local category = Category.new(category_dict.name)
    for _, item_dict in ipairs(category_dict.items) do
      local item = Item.new(item_dict.name, item_dict.path)
      category:add(item)
    end
    root:add(category)
  end
  return root
end

function Category:add(item)
  item.parent = self
  table.insert(self.children, item)
end

function Category:delete()
  local parent = self.parent
  if not parent then
    return
  end
  for i, child in ipairs(parent.children) do
    if child.iscategory and child.name == self.name then
      table.remove(parent.children, i)
      return
    end
  end
end

function Category:find_category(name)
  for _, child in ipairs(self.children) do
    if child.iscategory and child.name == name then
      return child
    end
  end
  return nil
end

function Category:open()
  self.opened = true
end

function Category:close()
  self.opened = false
end

function Category:to_json(path)
  local document = vim.to_vimdict({
    bookmarks = vim.to_vimlist(),
  })
  for _, category in ipairs(self.children) do
    local category_dict = vim.to_vimdict({
      name = category.name,
    })
    local items = vim.to_vimlist()
    for _, item in ipairs(category.children) do
      local item_dict = vim.to_vimdict({
        name = item.name,
        path = item.path,
      })
      table.insert(items, item_dict)
    end
    if #items > 0 then
      category_dict.items = items
    end
    table.insert(document.bookmarks, category_dict)
  end
  return vim.fn.json_encode(document)
end

return Category