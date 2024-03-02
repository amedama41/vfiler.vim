<!-- panvimdoc-ignore-start -->
# Table of contents

- [Usage](#usage)
  - [Command usage](#command-usage)
  - [Lua function usage](#lua-function-usage)
  - [2-window filer usage](#2-window-filer-usage)
- [Customization](#customization)
  - [Introduction](#introduction)
  - [Default configurations](#default-configurations)
  - [Options](#options)
  - [Mappings](#mappings)
  - [Column customization](#column-customization)
  - [Actions](#actions)
- [Action Configuration](#action-configuration)
  - [Action Default configurations](#action-default-configurations)
  - [Action Options](#action-options)
- [About](#about)

<!-- panvimdoc-ignore-end -->

# Usage
There are two ways to start `vfiler.vim`: starting from a command and starting from a Lua function.

## Command usage
```
:VFiler [{options}...] [{path}]
```
If `{path}` is not specified, it will start in the current directory.<br>
`{options}` are options for the behavior of `vfiler.vim`.

### Command options
Command options are in the form starting with `-`.<br>
For flag options, prefixing them with `-no-{option-name}` disables the option.

> NOTE: If you use both `{option-name}` and `-no-{option-name}` in the same `vfiler.vim` buffer, it is undefined.

Please see the [Options](#options) for details.

### Examples
```
:VFiler -auto-cd -keep -layout=left -width=30 -columns=indent,icon,name
:VFiler -no-git-enabled
```

### Command and configuration options
The names of the command options and the configuration options by `require'vfiler/config'.setup()` are very similar. <br>
Also, the meaning is exactly the same.<br>
The setting by `require'vfiler/config'.setup()` is the default setting, and the command option is different in that it overrides the default setting and starts `vfiler.vim`.

### Examples
| Configuration option | Command option |
| ---- | ---- |
| name = 'buffer-name' | -name=buffer-name |
| auto_cd = true | -auto-cd |
| auto_cd = false | -no-auto-cd |
| git.ignored = true | -git-ignored |
| git.ignored = false | -no-git-ignored |

## Lua function usage
Starting vfiler.vim by Lua function:
```lua
require'vfiler'.start(path, configs)
```
Here `path` is any directory path string. If omitted or an empty string, it will be started as the current directory.<br>
The `configs` is a configuration table with the same configuration as `require'vfiler/config'.setup()`. If you omit `configs`, the default settings will be applied. <br>
It is possible to change the behavior according to the situation by specifying it when you want to start with a setting different from the default setting.

see: [Customization](#customization) for details on the customization.

### Example
```lua
-- Start by partially changing the configurations from the default.
local action = require'vfiler/action'
local configs = {
  options = {
    name = 'myfiler',
    preview = {
      layout = 'right',
    },
  },

  mappings = {
    ['<C-l>'] = action.open_tree,
    ['<C-h>'] = action.close_tree_or_cd,
  },
}

-- Start vfiler.vim
require'vfiler'.start(dirpath, configs)
```

## 2-window filer usage
`vfiler.vim` is a 2-window filer that allows you to conveniently copy and move files between two different directories.

### How to start
The default keymap is `<TAB>` (`switch_to_filer` action), which will activate the 2-window filer.<br>
You can then use <TAB> to switch focus between the filer windows.

### Actions for the 2-window filer
|Default key|Action|
|-|-|
|`<TAB>`|switch_to_filer|
|`cc`|copy_to_filer|
|`mm`|move_to_filer|
|`<C-r>`|sync_with_current_filer|

see: [switch_to_filer](#switch_to_filer), [copy_to_filer](#copy_to_filer), [move_to_filer](#move_to_filer), [sync_with_current_filer](#sync_with_current_filer)

# Customization

## Introduction
As a basis for configuration, you need to run `require'vfiler/config'.setup()` in your personal settings.<br>
There are two main types of configurations, `options` and `mappings`.

### `vfiler.vim` setup structure
``` lua
local action = require('vfiler/action')
require('vfiler/config').setup {
  options = {
    -- Default configuration for vfiler.vim goes here:
    -- option_key = value,
  },

  mappings = {
    -- Associate the action with the key mapping.
    -- Set the key string and action as a key-value pair.

    -- map actions.change_to_parent to <C-h> (default: <BS>)
    ['<C-h>'] = action.change_to_parent
  },
}
```

## Default configurations
```lua
-- following options are the default
require'vfiler/config'.setup {
  options = {
    auto_cd = false,
    auto_resize = false,
    columns = 'indent,icon,name,mode,size,time',
    find_file = false,
    header = true,
    keep = false,
    listed = true,
    name = '',
    session = 'buffer',
    show_hidden_files = false,
    sort = 'name',
    layout = 'none',
    width = 90,
    height = 30,
    new = false,
    quit = true,
    toggle = false,
    row = 0,
    col = 0,
    blend = 0,
    border = 'rounded',
    zindex = 200,
    git = {
      enabled = true,
      ignored = true,
      untracked = true,
    },
    preview = {
      layout = 'floating',
      width = 0,
      height = 0,
    },
  },

  mappings = {
    ['.'] = action.toggle_show_hidden,
    ['<BS>'] = action.change_to_parent,
    ['<C-l>'] = action.reload,
    ['<C-p>'] = action.toggle_auto_preview,
    ['<C-r>'] = action.sync_with_current_filer,
    ['<C-s>'] = action.toggle_sort,
    ['<CR>'] = action.open,
    ['<S-Space>'] = function(vfiler, context, view)
      action.toggle_select(vfiler, context, view)
      action.move_cursor_up(vfiler, context, view)
    end,
    ['<Space>'] = function(vfiler, context, view)
      action.toggle_select(vfiler, context, view)
      action.move_cursor_down(vfiler, context, view)
    end,
    ['<Tab>'] = action.switch_to_filer,
    ['~'] = action.jump_to_home,
    ['*'] = action.toggle_select_all,
    ['\\'] = action.jump_to_root,
    ['cc'] = action.copy_to_filer,
    ['dd'] = action.delete,
    ['gg'] = action.move_cursor_top,
    ['b'] = action.list_bookmark,
    ['h'] = action.close_tree_or_cd,
    ['j'] = action.loop_cursor_down,
    ['k'] = action.loop_cursor_up,
    ['l'] = action.open_tree,
    ['mm'] = action.move_to_filer,
    ['p'] = action.toggle_preview,
    ['q'] = action.quit,
    ['r'] = action.rename,
    ['s'] = action.open_by_split,
    ['t'] = action.open_by_tabpage,
    ['v'] = action.open_by_vsplit,
    ['x'] = action.execute_file,
    ['yy'] = action.yank_path,
    ['B'] = action.add_bookmark,
    ['C'] = action.copy,
    ['D'] = action.delete,
    ['G'] = action.move_cursor_bottom,
    ['J'] = action.jump_to_directory,
    ['K'] = action.new_directory,
    ['L'] = action.switch_to_drive,
    ['M'] = action.move,
    ['N'] = action.new_file,
    ['P'] = action.paste,
    ['S'] = action.change_sort,
    ['U'] = action.clear_selected_all,
    ['YY'] = action.yank_name,
  },
}
```

## Options

#### auto_cd
Change the working directory while navigating with `vfiler.vim`.

- Type: `boolean`
- Default: `false`
- Command option format: `-auto-cd`

#### auto_resize
Enabled, it will automatically resize to the size specified by `width` and `height` options.

- Type: `boolean`
- Default: `false`
- Command option format: `-auto-resize`

#### columns
Specify the `vfiler.vim` columns.<br>
see: [Column customization](#column-customization)

- Type: `string`
- Default: `indent,icon,name,mode,size,time`
- Command option format: `-columns={column1,column2,...}`

#### find_file
If this option is enabled, the cursor in the tree is changed to the current `bufname`. <br>
It also recursively opens the leaf of the tree leading to the file in the buffer.

- Type: `boolean`
- Default: `false`
- Command option format: `-find-file`

#### git.enabled
Handles Git information.

- Type: `boolean`
- Defalt: `true`
- Command option format: `-git-enabled`

#### git.ignored
Include Git ignored files.

- Type: `boolean`
- Defalt: `true`
- Command option format: `-git-ignored`

#### git.untracked
Include Git untracked files.

- Type: `boolean`
- Defalt: `true`
- Command option format: `-git-untracked`

#### header
Display the header line.

- Type: `boolean`
- Default: `true`
- Command option format: `-header`

#### keep
Keep the `vfiler.vim` window with the open action.

- Type: `boolean`
- Default: `false`
- Command option format: `-keep`

#### listed
Display the `vfiler.vim` buffer in the buffer list.

- Type: `boolean`
- Default: `true`
- Command option format: `-listed`

#### name
Specifies a buffer name. <br>

>NOTE: Buffer name must contain spaces.

- Type: `string`
- Default: `""`
- Command option format: `-name={buffer-name}`

#### new
Create new `vfiler.vim` buffer.

- Type: `boolean`
- Default: `false`
- Command option format: `-new`

#### preview.layout
Specify the layout of the preview window.

- Layouts:
  - `left`: Split to the left.
  - `right`: Split to the right.
  - `top`: Split to the top.
  - `bottom`: Split to the bottom.
  - `floating`: Floating window.
- Type: `string`
- Defualt: `"floating"`
- Command option format: `-preview-layout={type}`

#### preview.height
The window height of the buffer whose layout is `top`, `bottom`, `floating`.<br>
If you specify `0`, the height will be calculated automatically.

- Type: `number`
- Default: `0`
- Command option format: `-prepreview-height={window-height}`

#### preview.width
The window width of the buffer whose layout is `left`, `right`, `floating`.<br>
If you specify `0`, the width will be calculated automatically.

- Type: `number`
- Default: `0`
- Command option format: `-preview-width={window-width}`

#### toggle
If enabled, Close the `vfiler.vim` window if this `vfiler.vim` window exists.<br>

- Type: `boolean`
- Default: `false`
- Command option format: `-toggle`

#### session
Specifies how to save the session.

- Types:
  - `none`: Does not save the session.
  - `buffer`: Sessions are saved each `vfiler.vim` buffer.
  - `share`: Session are shared.
- Type: `string`
- Default: `"buffer"`
- Command option format: `-session={type}`

#### show_hidden_files
If enabled, Make hidden files visible by default.

- Type: `boolean`
- Default: `false`
- Command option format: `-show-hidden-files`

#### layout
Specify the layout of the window.

- Layouts:
  - `left`: Split to the left.
  - `right`: Split to the right.
  - `top`: Split to the top.
  - `bottom`: Split to the bottom.
  - `tab`: Create the new tabpage.
  - `floating`: Floating window.
  - `none`: No split or floating.
- Type: `string`
- Default: `"none"`
- Command option format: `-layout={type}`

#### height
Set the height of the window.<br>
It is a valid value when the window is splitted or floating by the `layout` option etc.

- Type: `number`
- Default: `0`
- Command option format: `-height={window-height}`

#### width
Set the width of the window.<br>
It is a valid value when the window is splitted or floating by the `layout` option etc.

- Type: `number`
- Default: `0`
- Command option format: `-width={window-width}`

#### row
Set the row position to display the floating window.<br>
If `0`, it will be set automatically according to the current window size.

> NOTE: This option is valid only when the `layout` option is `floating`.

- Type: `number`
- Default: `0`
- Command option format: `-row={window-row}`

#### col
Set the column position to display the floating window.<br>
If `0`, it will be set automatically according to the current window size.

> NOTE: This option is valid only when the `layout` option is `floating`.

- Type: `number`
- Default: `0`
- Command option format: `-col={window-column}`

#### blend
Enables pseudo-transparency for a floating window.<br>
Valid values are in the range of `0` for fully opaque window (disabled) to `100` for fully transparent background.<br>
Values between `0-30` are typically most useful.

> NOTE: This option is valid only when the `layout` option is `floating`.

- Type: `number`
- Default: `0`
- Command option format: `-blend={value}`

#### border
Style of window border.

> NOTE: This option is valid only when the `layout` option is `floating`.

- Type: `string`
- Default: `"rounded"`
- Command option format: `-border={type}`

#### zindex
Stacking order.<br>
floats with higher `zindex` go on top on floats with lower indices. <br>
Must be larger than zero.

> NOTE: This option is valid only when the `layout` option is `floating`.

- Type: `number`
- Default: `200`
- Command option format: `-zindex={value}`

## Mappings
`vfiler.vim` also gives you the flexibility to customize your keymap.

### Change keymaps
If you don't like the default keymap, you can specify any `key string` and the `require'vfiler/action'` functions for it in the mappings table.<br>
If there is no default keymap, it will be added.
```lua
local action = require('vfiler/action')
require('vfiler/config').setup {
  options = {
    -- Default configuration for vfiler.vim goes here:
  },

  mappings = {
    -- Associate the action with the key mapping.
    -- Set the key string and action as a key-value pair.
    ['<C-h>'] = action.change_to_parent,
    ['<C-l>'] = action.open_tree,
    ['<C-c>'] = action.open_by_choose,
  },
}
```
Please see the [Actions](#actions) for details.

### Unmap
You can unmap the extra keymap.
```lua
-- Specify the key string you want to unmap. (e.g. '<CR>', 'h')
require'vfiler/config'.unmap(key)
```

### Clear keymaps
If you want to reassign the default keymap, you can unmap all the default keymaps.
```lua
require'vfiler/config'.clear_mappings()
```
> NOTE: However, please call the function before specifying the keymap.

## Column customization
`vfiler.vim` supports several columns.<br>
You can change each column to show or hide, and also change the display order.

### How to specify.
List the column names separated by commas.<br>
The display order is from the left side of the description.

### Column types
| Name | Description |
| ---- | ---- |
| `name` | File name. |
| `indent` | Tree indentaion. |
| `icon` | Icon such as directory, and marks. |
| `mode` | File mode. |
| `size` | File size. |
| `time` | File modified time. |
| `type` | File type. |
| `git` | Git status. |
| `space` | Space column for padding. |

<!-- panvimdoc-ignore-start -->

### Example
#### Default
`columns = 'indent,icon,name,mode,size,time'`

![column-configurations-default](https://github.com/obaland/contents/blob/main/vfiler.vim/image-configurations-column-default.png?raw=true)

#### Reduce the columns
`columns = 'indent,name,size'`

![column-configurations-reduce](https://github.com/obaland/contents/blob/main/vfiler.vim/image-configurations-column-reduce.png?raw=true)

#### Change the order
`columns = 'indent,icon,name,time,mode,size'`

![column-configurations-order](https://github.com/obaland/contents/blob/main/vfiler.vim/image-configurations-column-order.png?raw=true)

<!-- panvimdoc-ignore-end -->

## Actions

---

### Action to cursor

#### loop_cursor_down
Move the cursor down with loop.

#### loop_cursor_up
Move the cursor up with loop.

#### loop_cursor_down_sibling
Move the cursor to the next sibling with loop.

#### loop_cursor_up_sibling
Move the cursor to the previous sibling with loop.

#### move_cursor_down
Move the cursor down.

#### move_cursor_up
Move the cursor up.

#### move_cursor_bottom
Moves the cursor to the bottom of the `vfiler.vim` buffer.

#### move_cursor_top
Moves the cursor to the top of the `vfiler.vim` buffer.

#### move_cursor_down_sibling
Move the cursor to the next sibling.

#### move_cursor_up_sibling
Move the cursor to the previous sibling.

#### move_cursor_bottom_sibling
Move the cursor to the last sibling.

#### move_cursor_top_sibling
Move the cursor to the first sibling.

---

###  Action to directory

#### open_tree
Expand the directory on the cursor.

#### open_tree_recursive
Recursively expand the directory on the cursor.

#### close_tree_or_cd
Close cursor directory tree or change to parent directory.

#### change_to_parent
Change to parent directory.

#### jump_to_home
Jump to home directory.

#### jump_to_root
Jump to root directory.

#### jump_to_directory
Jump to specified directory.

#### jump_to_history_directory
Jump to specified history directory.

---

### Action to select

#### toggle_select
Toggle the item on the current cursor.

#### toggle_select_all
Toggles marks in all lines.

#### clear_selected_all
Clears marks in all lines.

---

### Action to open

#### open
Change cursor directory or open cursor file.

#### open_by_split
Open cursor file by split.

#### open_by_vsplit
Open cursor file by vsplit.

#### open_by_tabpage
Open cursor file by tabpage.

---

### Action to file operation

#### execute_file
Execute the file with an external program.

#### new_file
Creates new files. If directory tree is opened, create new files in directory tree.

#### new_directory
Make the directories.

#### delete
Delete the files.

#### rename
Rename the files.

#### copy
Copies selected files to `vfiler.vim` clipboard.<br>
If no selected files, copies the file on the cursor to `vfiler.vim` clipboard.

#### copy_to_filer
If it is in the 2-window-filer state,<br>
it will be copied under the directory where the other `vfiler.vim` buffer is open.<br>
If not, it will be saved to the clipboard.

#### move
Moves selected files to `vfiler.vim` clipboard.<br>
If no selected files, moves the file on the cursor to `vfiler.vim` clipboard.

#### move_to_filer
If it is in the 2-window-filer state,<br>
it will be moved under the directory where the other `vfiler.vim` buffer is open.<br>
If not, it will be saved to the clipboard.

#### paste
Paste files saved in the clipboard.

---

### Action to yank

#### yank_path
Yanks full path to clipboard register and unnamed register.

#### yank_name
Yanks filename to clipboard register and unnamed register.

---

### Action to preview

#### toggle_auto_preview
Toggle the automatic preview window.

#### toggle_preview
Toggle the preview window for the item in the current cursor.

#### scroll_down_preview
Scroll down in preview window.

#### scroll_up_preview
Scroll up in preview window.

---

### Action to view

#### toggle_show_hidden
Toggles visible hidden files.

#### toggle_sort
Toggle the ascending/descending order of the current sort method.

#### change_sort
Change the sort method.

---

### Action to buffer

#### switch_to_filer
Switch the filer buffer in the tab page. If there is no buffer to switch, create it.

> NOTE: It does not work in floating windows.

#### sync_with_current_filer
Synchronizes another `vfiler.vim` buffer current directory with current `vfiler.vim` buffer.

> NOTE: It does not work in floating windows.

#### switch_to_drive
Switches to other drive(Windows) or mount point(Mac/Linux).

#### reload
Reload the `vfiler.vim` buffer.

#### reload_all_dir
Reload the `vfiler.vim` buffer.<br>
The difference between `reload` and `reload_all_dir`is the former reload only the items in directories that have been updated,<br>
while the latter reload also the items in all directories.

#### quit
Quit the `vfiler.vim` buffer.

---

### Action to bookmark

#### add_bookmark
Add the item in the current line to the bookmark.

#### list_bookmark
List the bookmarks.

# Action Configuration
As a action module for configuration, you need to run `require'vfiler/action'.setup()` in your personal settings.

## Action Default configurations
```lua
-- following options are the default
require'vfiler/action'.setup {
  hook = {
    filter_choose_window = function(winids)
      return winids
    end,
  },
}
```

## Action Options

#### hook.filter_choose_window
Sets the function to be hooked when opening a file or other object in the choose window.</br>
This hook function is used to filter specific windows.

- Type: `function`

##### Example
```lua
require('vfiler/action').setup {
  hook = {
    -- Filter windows for specific file types.
    filter_choose_window = function(winids)
      return vim.tbl_filter(function(winid)
        local buffer = vim.api.nvim_win_get_buf(winid)
        return vim.api.nvim_buf_get_option(buffer, 'filetype') ~= 'incline'
      end, winids)
    end,
  },
}
```

#### hook.read_preview_file
Sets the function to be hooked when reading a preview file.</br>
This hook function is used to customize preview contents.</br>
This function shall return lines of preview content and the content filetype.</br>
If the returned filetype is `nil`, actual filetype is detected from the content.

- Type: `function`

##### Example

```lua
require('vfiler/action').setup {
  hook = {
    -- Read contents for specific preview file.
    read_preview_file = function(path, default_read_func)
      local ext = vim.fn.fnamemodify(path, ":e")
      if ext == 'zip' and vim.fn.executable('unzip') then
        -- For zip files, show archived path list
        local lines = vim.fn.systemlist('unzip -l ' .. vim.fn.shellescape(path))
        return lines, 'text'
      else
        -- For other files, show contents as is
        return default_read_func(path)
      end
    end,
  }
}
```

# About

`vfiler.vim` is developed by obaland and licensed under the MIT License.<br>
Visit the project page for the latest information:

<https://github.com/obaland/vfiler.vim>

==============================================================================
