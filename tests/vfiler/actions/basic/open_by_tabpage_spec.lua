local core = require('vfiler/libs/core')
local basic = require('vfiler/actions/basic')
local u = require('tests/utility')

local configs = {
  options = u.vfiler.generate_options(),
}

local function desc(action_name, vfiler)
  return ('%s root:%s'):format(action_name, vfiler._context.root.path)
end

describe('basic actions', function()
  local vfiler = u.vfiler.start(configs)
  it(desc('open by tabpage', vfiler), function()
    local view = vfiler._view
    core.cursor.move(u.int.random(2, view:num_lines()))
    u.vfiler.do_action(vfiler, basic.open_by_tabpage)
  end)
  vfiler:quit(true)
end)