local util = require("easycomplete.util")
local pum = require("easycomplete.pum")
local console = util.console
-- cmdline_start_cmdpos 是不带偏移量的，偏移量只给 pum 定位用
local cmdline_start_cmdpos = 0
local old_cmdline = ""
local pum_noselect = vim.g.easycomplete_pum_noselect
-- 把 firstcomplete 匹配到的单词列表缓存起来
local search_cmp_cache = {}
local redraw_queued = false
local last_redraw = false
local this = {}

function this.pum_complete(start_col, menu_items)
  vim.g.easycomplete_pum_noselect = 1
  vim.fn["easycomplete#pum#complete"](start_col, menu_items)
end

function this.get_path_cmp_items()
  return pum.get_path_cmp_items()
end

function this.pum_close()
  vim.fn["easycomplete#pum#close"]()
  vim.g.easycomplete_pum_noselect = pum_noselect
end

function this.pum_bufid()
  return pum.bufid()
end

function this.pum_winid()
  return pum.winid()
end

function this.get_typing_word()
  return util.get_typing_word()
end

function this.menu_filter(menu_list, word, max_word)
  return util.menu_filter(menu_list, word, max_word)
end

function this.get_buf_keywords(typing_word)
  return util.get_buf_keywords(typing_word)
end

-- 计算 sign 和 number 列的宽度
function this.calculate_sign_and_linenr_width()
  local width = 0
  -- 检查是否有 sign 列
  local signcolumn = vim.api.nvim_win_get_option(0, "signcolumn")
  if signcolumn == "yes" or signcolumn == "auto" or signcolumn == "number" then
    width = width + 2 -- sign 列通常占据 2 个字符宽度
  end
  -- 检查是否显示行号
  if vim.wo.number or vim.wo.relativenumber then
    -- 计算行号的最大宽度
    local max_num_width = #tostring(vim.fn.line("$"))
    local realwidth = 3
    if max_num_width <= 3 then
      -- do nothing
    else
      realwidth = realwidth + (max_num_width - 3)
    end
    width = width + realwidth
  end
  return width
end

-- 计算当前窗口距离window左边距的距离
function this.window_offset_horizontal()
  local offset = vim.fn.win_screenpos(vim.fn.win_getid())
  local offset_horizontal = offset[2]
  return offset_horizontal - 1
end

function this.safe_redraw()
  if vim.fn.has('nvim-0.10') then
    vim.api.nvim__redraw({
        win = this.pum_winid(),
        flush = true
      })
  else
    vim.cmd("redraw")
  end
end

function this.pum_redraw()
  if util.zizzing() then return end
  util.zizz()
  if redraw_queued then return end
  if this.insearch() then
    redraw_queued = true
    -- 首次insearch匹配<s-tab>会导致匹配高亮渲染消失，这里做一下区分
    local first_insearch_match = false
    if last_redraw == false then
      first_insearch_match = true
    else
      first_insearch_match = false
    end
    last_redraw = true
    -- cmdline 中模拟 redraw：
    -- 问题现象：cmdline动作不会直接redraw主屏，会慢一拍，需要手动触发 redraw 才
    -- 能正确的渲染出 PUM，否则 PUM 中的内容是上一次匹配的结果。
    --  1. ":" 命令模式下，主界面没有变更，直接 redraw 即可
    --  2. "/" 搜索模式下，会导致不断刷新匹配词，导致不断闪烁，不能直接 redraw
    --     而要用cmdline按键来模拟，常用的是 " <bs>"/"<c-]>"/"<c-a><c-h>" 等，但
    --     这些指令会导致在大文件中光标闪烁，虽然功能没问题，但明显不流畅
    --     这里用了一个 hack，默认选中第一项，然后执行一次<s-tab>，可以避免光标
    --     闪烁的问题。
    local command_str = ""
    if first_insearch_match then
      command_str = "<c-]>"
    else
      command_str = "<s-tab>"
    end
    local termcode = vim.api.nvim_replace_termcodes(command_str, true, true, true)
    vim.schedule(function()
      vim.api.nvim_win_call(this.pum_winid(), function()
        if vim.o.incsearch then
          if first_insearch_match then
            -- do nothing
          else
            this.pum_select(1)
          end
          vim.api.nvim_feedkeys(termcode, 't', true)
        end
      end)
      redraw_queued = false
    end)
  else
    if not vim.api.nvim_win_is_valid(this.pum_winid()) then
      vim.schedule(function()
        this.safe_redraw()
      end)
    else
      vim.cmd("redraw")
    end
  end
end

function this.flush()
  vim.g.easycomplete_cmdline_pattern = ""
  vim.g.easycomplete_cmdline_typing = 0
  cmdline_start_cmdpos = 0
  last_redraw = false
  search_cmp_cache = {}
  this.pum_close()
end

function this.insearch()
  if vim.g.easycomplete_cmdline_pattern == "/" or vim.g.easycomplete_cmdline_pattern == "?" then
    return true
  else
    return false
  end
end

function this.pum_visible()
  return pum.visible()
end

function this.pum_selected()
  return pum.selected()
end

function this.pum_selected_item()
  return pum.selected_item()
end

function this.pum_select(index)
  return pum.select(index)
end

function this.pum_select_next()
  pum.select_next()
  if this.insearch() then
    return ""
  end
  util.zizz()
  local new_whole_word = this.get_tab_returing_opword()
  return new_whole_word
end

function this.pum_select_prev()
  pum.select_prev()
  if this.insearch() then
    return ""
  end
  util.zizz()
  local new_whole_word = this.get_tab_returing_opword()
  return new_whole_word
end

-- :cmd 模式下Tab 切换 pum 选项的动作
function this.get_tab_returing_opword()
  local backing_count = vim.fn.getcmdpos() - cmdline_start_cmdpos
  local oprator_str = string.rep("\b", backing_count)
  local new_whole_word = ""
  if this.pum_selected() then
    local item = this.pum_selected_item()
    local word = item.word
    new_whole_word = oprator_str .. word
  else
    new_whole_word = oprator_str
  end
  return new_whole_word
end

function this.bind_cmdline_event()
  if util.check_noice() then
    return
  end
  local augroup = vim.api.nvim_create_augroup('CustomCmdlineComplete', { clear = true })

  vim.api.nvim_create_autocmd("CmdlineEnter", {
      group = augroup,
      pattern = ":",
      callback = function()
        if vim.fn.getcmdtype() == ":" then
          vim.g.easycomplete_cmdline_pattern = ":"
        end
      end,
    })

  vim.api.nvim_create_autocmd("CmdlineEnter", {
      group = augroup,
      pattern = "/",
      callback = function()
        if vim.fn.getcmdtype() == "/" then
          vim.g.easycomplete_cmdline_pattern = "/"
        end
      end,
    })

  vim.api.nvim_create_autocmd("CmdlineEnter", {
      group = augroup,
      pattern = "?",
      callback = function()
        if vim.fn.getcmdtype() == "?" then
          vim.g.easycomplete_cmdline_pattern = "?"
        end
      end,
    })

  vim.api.nvim_create_autocmd("CmdlineLeave", {
      group = augroup,
      callback = function()
        this.flush()
        vim.g.easycomplete_pum_noselect = pum_noselect
      end
    })

  vim.keymap.set("c", "<Tab>", function()
    return this.pum_select_next()
  end, { expr = true, noremap = true })

  vim.keymap.set("c", "<S-Tab>", function()
    return this.pum_select_prev()
  end, { expr = true, noremap = true })

  vim.on_key(function(keys, _)
    if vim.api.nvim_get_mode().mode ~= "c" then
      return
    end
    if vim.bo.filetype == 'help' then return end
    vim.g.easycomplete_cmdline_typing = 1
    local key_str = vim.api.nvim_replace_termcodes(keys, true, false, true)
    if this.insearch() and key_str ~= '\r' then
      -- jayli 先关掉，继续调试
      -- do return end
      if util.zizzing() then
        return
      end
    end
    vim.defer_fn(function()
      vim.schedule(function()
        local ok, ret = pcall(this.cmdline_handler, keys, key_str)
        if not ok then
          print(ret)
        end
      end)
    end, 10)
    if key_str == '\r' then
      if this.cr_handler() then
        return -- 执行回车
      else
        return "" -- 阻止回车
      end
    end
  end)
end

function this.normalize_list(arr, word)
  if #arr == 0 then return arr end
  local ret = {}
  for index, value in ipairs(arr) do
    if type(value) == "table" then
      table.insert(ret, {
          word = value["word"],
          abbr = value["abbr"],
          kind = value["kind"],
          menu = value["menu"],
        })
    else
      table.insert(ret, {
          word = arr[index],
          abbr = arr[index],
          kind = vim.g.easycomplete_kindflag_cmdline,
          menu = vim.g.easycomplete_menuflag_cmdline,
        })
    end
  end
  local filtered_items = this.menu_filter(ret, word, 800)
  return filtered_items
end

-- cmdline 处理器
function this.cmdline_handler(keys, key_str)
  if vim.g.easycomplete_cmdline_pattern == "" then
    return
  end
  if util.zizzing() then return end
  local should_redraw = false
  local cmdline = vim.fn.getcmdline()
  cmdline_start_cmdpos = 0
  -- console(string.byte(key_str), vim.g.easycomplete_cmdline_pattern)
  if string.byte(key_str) == 9 then
    -- console("Tab 键")
  elseif string.byte(key_str) == 32 then
    -- console("空格键")
    -- this.pum_close()
    should_redraw = this.do_complete()
  elseif string.byte(key_str) == 128 and #cmdline == #old_cmdline then
    -- 方向键
    this.pum_close()
  elseif string.byte(key_str) == 128 and #cmdline == #old_cmdline - 1 then
    -- 退格键
    should_redraw = this.do_complete()
  elseif string.byte(key_str) == 8 then
    -- console("退格")
    should_redraw = this.do_complete()
  elseif string.byte(key_str) == 13 then
    -- console("回车")
  elseif string.byte(key_str) == 58 then
    -- console("冒号:")
    should_redraw = this.do_complete()
  elseif string.byte(key_str) == 95 or string.byte(key_str) == 35 then
    -- console("下划线_或者#")
    should_redraw = this.do_complete()
  else
    -- console("其他键: " .. keys)
    should_redraw = this.do_complete()
  end
  old_cmdline = cmdline
  if should_redraw then
    this.pum_redraw()
  else
    last_redraw = false
  end
end

-- 回车处理器
function this.cr_handler()
  if this.pum_visible() and this.pum_selected() then
    if vim.g.easycomplete_cmdline_pattern == ":" then
      this.pum_close()
      vim.defer_fn(function()
        if this.char_before_cursor() == "/" then
          this.do_path_complete()
        end
      end, 30)
    elseif this.insearch() then
      local opr = this.get_tab_returing_opword()
      this.pum_close()
      vim.defer_fn(function()
        vim.api.nvim_feedkeys(opr, 'ni', true)
        util.zizz()
      end, 30)
    end
    return false -- 阻止回车
  else
    return true -- 执行回车
  end
end

-- 获得搜索模式下的匹配词列表
function this.get_normal_search_cmp()
  local typing_word = this.get_typing_word()
  local word_list = {}
  if #typing_word >=2 and #search_cmp_cache >= 1 then
    word_list = search_cmp_cache
  elseif #typing_word == 1 then
    word_list = this.get_buf_keywords(typing_word)
    search_cmp_cache = word_list
  end
  if #word_list > 200 then
    word_list = util.filter(word_list, function(item)
      local lower_sub_word = string.lower(string.sub(item, 1, 5))
      if string.find(lower_sub_word, string.lower(string.sub(typing_word, 1, 1))) then
        return true
      else
        return false
      end
    end)
  end
  return word_list
end

-- MAIN ROUTER, 主路由
this.REG_CMP_HANDLER = {
  {
    -- cmdline 是空
    pattern = "^%s*$",
    get_cmp_items = function()
      return {}
    end
  },
  {
    -- 正在输入第一个命令
    pattern = "^[a-zA-Z0-9_]+$",
    get_cmp_items = function()
      if this.insearch() then
        local ret = this.get_normal_search_cmp()
        return ret
      elseif vim.g.easycomplete_cmdline_pattern == ":" then
        -- command 共有 670 多个，返回全部
        return this.get_all_commands()
      end
    end
  },
  {
    -- help
    pattern = {
      "^h%s[%w_]+$",
      "^help%s[%w_]+$"
    },
    get_cmp_items = function()
      if this.insearch() then
        return this.get_normal_search_cmp()
      else
        local all_tags = this.get_help_completions()
        local typing_word = this.get_typing_word()
        local guide_char = string.sub(typing_word, 1, 1)
        local result = util.filter(all_tags, function(item)
          if string.find(string.lower(string.sub(item, 1, 2)), string.lower(guide_char)) and
             not string.find(item, "[%s<>%+%-]") then
            return true
          else
            return false
          end
        end)
        return result
      end
    end
  },
  {
    -- highlight attr names
    pattern = {
      "^hi%s.*gui=%w*$",
      "^hi%s.*cterm=%w*$",
      "^highlight%s.*gui=%w*$",
      "^highlight%s.*cterm=%w*$",
    },
    get_cmp_items = function()
      if this.insearch() then
        return this.get_normal_search_cmp()
      else
        local colors = this.HL_ATTRS
        return colors
      end
    end
  },
  {
    -- highlight colors name
    pattern = {
      "^hi%s.*gui[fb]g=%w*$",
      "^hi%s.*cterm[fb]g=%w*$",
      "^highlight%s.*gui[fb]g=%w*$",
      "^highlight%s.*cterm[fb]g=%w*$",
    },
    get_cmp_items = function()
      if this.insearch() then
        return this.get_normal_search_cmp()
      else
        local colors = this.NATIVE_COLORS
        return colors
      end
    end
  },
  {
    -- highlight color groups
    pattern = {
      "^hi%s+[%w@]+$",
      "^highlight%s+[%w@]+$", -- 几个常见的属性 TODO
      "^hi%s+link%s+$",
      "^hi%s+link%s+[%w@]+$",
      "^hi%s+link%s+[%w@]+%s+$",
      "^hi%s+link%s+[%w@]+%s+[%w@]+$"
    },
    get_cmp_items = function()
      if this.insearch() then
        return this.get_normal_search_cmp()
      else
        local typing_word = this.get_typing_word()
        local guide_str = string.sub(typing_word, 1, 1)
        local result = vim.fn.getcompletion(guide_str, "highlight")
        return result
      end
    end
  },
  {
    -- 输入 highlight 的 属性
    -- hi Normal |
    -- hi Normal g|
    -- hi Normal guifg=red |
    -- hi Normal guifg=red gui|
    pattern = {
      "^hi%s+[%w@]+%s$",
      "^hi%s+[%w@]+%s.*%s$",
      "^hi%s+[%w@]+%s+%w+$",
      "^hi%s+[%w@]+%s.*%s%w+$",
    },
    get_cmp_items = function()
      if this.insearch() then
        return this.get_normal_search_cmp()
      else
        return this.HL_ARGS
      end
    end
  },
  {
    -- 输入 options
    pattern = {
      '^[a-zA-Z0-9_]+%s&$', -- 输入命令完毕后，空格&匹配option: `echo &|`
      '^[a-zA-Z0-9_]+%s+&%w+$', -- 匹配 options 过程中: `echo &e|`
      '^[a-zA-Z0-9_]+%s+.+&$', -- 匹配 options 过程中:`echo &filetype . &|`
      '^[a-zA-Z0-9_]+%s+.+&%w+$' -- 匹配 options 过程中:`echo &filetype . &file|`
    },
    get_cmp_items = function()
      if this.insearch() then
        return this.get_normal_search_cmp()
      else
        local options = this.NATIVE_OPTIONS
        return options
      end
    end
  },
  {
    pattern = {
      "^[a-zA-Z0-9_]+%s$", -- 命令输入完毕，并敲击空格
      "^[a-zA-Z0-9_]+%s+[_%w#]+$", -- 命令输入完毕，敲击空格后直接输入正常单词
      "^[a-zA-Z0-9_]+%s+[glbwtvas]:%w-$", -- 命令输入完毕，输入 x:y 变量
    },
    get_cmp_items = function()
      if this.insearch() then
        return {}
      end
      local cmd_name = this.get_guide_cmd()
      local cmp_type = this.get_complition_type(cmd_name)
      local typing_word = this.get_typing_word()
      if cmp_type == "" then
        if typing_word == "" then
          return {}
        else -- 如果不是预设的命令，直接从buf取词，也做前两个字符的过滤
          local ret = this.get_buf_keywords(string.sub(typing_word, 1, 2))
          return ret
        end
      elseif typing_word == "" and (cmp_type == "expression" or cmp_type == "function") then
        -- expression 和 function 的返回结果太多了，太卡了，这里做一个限制，不做空匹配取全部了
        -- 这俩都有1800+个匹配项
        return {}
      else -- 最多情况的匹配
        local guide_str = ""
        if (cmp_type == "expression" or cmp_type == "function") then
          -- 带搜索词的匹配，根据第一个字符做一遍过滤
          guide_str = string.sub(typing_word, 1, 1)
        end
        local result = vim.fn.getcompletion(guide_str, cmp_type)
        -- user 的返回结果里有重复的
        if cmp_type == "user" then
          result = util.distinct(result)
        end
        -- Hack for file and file_in_path
        -- getcompletion 的路径结果中，给所有的当前目录加上./前缀
        -- 便于连续回车匹配
        if cmp_type == "file" or cmp_type == "file_in_path" then
          for i, item in ipairs(result) do
            if string.find(item, "^[^/]+/$") ~= nil then
              result[i] = "./" .. item
            end
          end
        end
        return result
      end
    end
  },
  {
    -- 输入路径
    pattern = {
      "^[a-zA-Z0-9_]+%s+.*/$",
      "^[a-zA-Z0-9_]+%s+.*/[a-zA-Z0-9_]+$",
      "^[a-zA-Z0-9_]+%s+/$"
    },
    get_cmp_items = function()
      if this.insearch() then
        return {}
      else
        return this.get_path_cmp_items()
      end
    end
  },
  {
    -- 输入引号里的文本
    pattern = {
      "^[a-zA-Z0-9_]+%s+.*%\"[^\"]-$",
      "^[a-zA-Z0-9_]+%s+.*%\'[^\']-$",
    },
    get_cmp_items = function()
      if this.insearch() then
        return {}
      end
      local typing_word = this.get_typing_word()
      if typing_word == "" then
        return {}
      else
        local ret = this.get_buf_keywords(string.sub(typing_word, 1, 1))
        return ret
      end
    end
  }
}

-- 执行路径匹配
function this.do_path_complete()
  this.cmp_regex_handler(function()
    return this.get_path_cmp_items()
  end, this.get_typing_word())
  vim.defer_fn(function()
    this.pum_redraw()
  end, 10)
end

-- 根据 cmd_name 获得命令的类型
function this.get_complition_type(cmd_name)
  local cmd_type = ""
  for key, item in pairs(this.CMD_TYPES) do
    if util.has_item(item, cmd_name) then
      cmd_type = key
      break
    end
  end
  return cmd_type
end

-- 执行匹配
function this.do_complete()
  local word = this.get_typing_word()
  local should_redraw = false
  local matched_pattern = false
  for index, item in ipairs(this.REG_CMP_HANDLER) do
    if type(item.pattern) == "table" then
      for jndex, jtem in ipairs(item.pattern) do
        if this.cmd_match(jtem) then
          should_redraw = this.cmp_regex_handler(item.get_cmp_items, word)
          matched_pattern = true
          break
        end
      end
    else
      if this.cmd_match(item.pattern) then
        should_redraw = this.cmp_regex_handler(item.get_cmp_items, word)
        matched_pattern = true
      end
    end
    if matched_pattern == true then
      break
    end
  end
  if matched_pattern == false then
    should_redraw = false
    this.pum_close()
  end
  return should_redraw
end

-- 根据某个正则表达式是否匹配，来调用既定的get_cmp_items，并执行complete()
function this.cmp_regex_handler(get_cmp_items, word)
  local should_redraw = false
  -- 光标所在行的 tab 的数量会影响 pum 的位置，感觉应该是 nvim 的bug
  local start_col = vim.fn.getcmdpos()
                    - this.calculate_sign_and_linenr_width()
                    - #word
                    - this.window_offset_horizontal()
                    - this.tabs_number() * (vim.bo.tabstop - 1)
  cmdline_start_cmdpos = vim.fn.getcmdpos() - #word
  local ok, menu_items = pcall(get_cmp_items)
  if not ok then
    print("[jayli debug] ".. menu_items)
    should_redraw = false
    this.pum_close()
  elseif menu_items == nil or #menu_items == 0 then
    should_redraw = false
    this.pum_close()
  else
    local filtered_items = this.normalize_list(menu_items, word)
    if #filtered_items == 0 then
      should_redraw = false
    else
      should_redraw = true
    end
    local final_result = util.sub_table(filtered_items, 1, vim.g.easycomplete_maxlength)
    this.pum_complete(start_col, final_result)
  end
  return should_redraw
end

-- 计算当前行李tab的数量
function this.tabs_number()
  local line = vim.fn.getline('.')
  local res, no = string.gsub(line, "\t", "")
  return no
end

-- 获得所有command list
function this.get_all_commands()
  local all_commands = {}
  local tmp_items = vim.fn.getcompletion("", "command")
  for index, value in ipairs(tmp_items) do
    if string.match(value, "^[_a-zA-Z0-9]") then
      table.insert(all_commands, value)
    end
  end
  return all_commands
end

-- 计算光标之前的字符串
function this.cmdline_before_cursor()
  local cmdline_all = vim.fn.getcmdline()
  local cmdline_typed = util.trim_before(string.sub(cmdline_all, 1, vim.fn.getcmdpos() - 1))
  return cmdline_typed
end

-- 计算光标之前的单个字符
function this.char_before_cursor()
  local cmdline_all = vim.fn.getcmdline()
  local char = string.sub(cmdline_all, vim.fn.getcmdpos() - 1, vim.fn.getcmdpos() - 1)
  return char
end

-- 获得 cmdline 中的命令
-- 不管有没有输入完整，都返回
function this.get_guide_cmd()
  local cmdline_typed = this.cmdline_before_cursor()
  local cmdline_tb = vim.split(cmdline_typed, "%s+")
  if #cmdline_tb == 0 then
    return ""
  else
    return cmdline_tb[1]
  end
end

-- 判断当前输入命令字符串是否完全匹配rgx
-- 只获取光标前的字符串
function this.cmd_match(rgx)
  local cmdline_typed = this.cmdline_before_cursor()
  local ret = string.find(cmdline_typed, rgx)
  if ret == nil then -- 不匹配
    return false
  elseif ret == 1 then -- 从头匹配
    return true
  else -- 不从头匹配
    return false
  end
end

-- 得到所有的文档中的tags
local help_all_tags = nil
function this.get_help_completions()
  if help_all_tags ~= nil then
    return help_all_tags
  else
    local help_files = vim.api.nvim_get_runtime_file('doc/tags', true)
    local all_tags = {}
    for _, filename in ipairs(help_files) do
      local tags = util.get_file_tags(filename)
      for _, v in ipairs(tags) do table.insert(all_tags, v) end
    end
    help_all_tags = all_tags
    return all_tags
  end
end

-- 命令类型
this.CMD_TYPES = {
  -- File completion
  file = {
    'edit', 'read', 'write','saveas',
    'source','split', 'vsplit', 'tabedit',
    'diffsplit', 'diffpatch', 'explore',
    'lexplore', 'sexplore', 'vexplore',
    'argadd', 'argdelete', 'argdo'
  },
  file_in_path = { 'find', 'sfind', 'tabfind' },
  -- Directory completion
  dir = { 'cd', 'lcd', 'tcd', 'chdir' },
  -- Buffer completion
  buffer = {
    'buffer', 'bdelete', 'bwipeout', 'b',
    'bnext', 'bprevious', 'bfirst', 'buf',
    'blast', 'sbuffer', 'sball',
  },
  diff_buffer = { 'diffthis', 'diffoff', 'diffupdate' },
  command = { 'command', 'delcommand' },
  option = { 'set', 'setlocal', 'setglobal' },
  -- help = { 'help' },
  expression = {
    'substitute', 'global', 'vglobal', 'let',
    'echo', 'echom', 'echon',
  },
  tag = {
    'tag', 'stag', 'tselect', 'tjump',
    'tlast', 'tnext', 'tprev', 'tunmenu',
  },
  arglist = { 'args' },
  ['function'] = { 'function', 'delfunction', 'call'},
  mapping = {
    'map', 'noremap', 'unmap',
    'nmap', 'vmap', 'imap', 'cmap',
    'nunmap', 'vunmap', 'iunmap', 'cunmap',
  },
  event     = { 'autocmd', 'doautocmd', 'doautoall' },
  augroup   = { 'augroup' },
  shellcmd  = { 'terminal' },
  color     = { 'colorscheme' },
  compiler  = { 'compiler' },
  filetype  = { 'filetype' },
  highlight = { 'highlight', 'hi' },
  history   = { 'history' },
  lua       = { 'lua' },
  messages  = { 'messages' },
  packadd   = { 'packadd' },
  register  = { 'register' },
  runtime   = { 'runtime' },
  sign      = { 'sign' },
  syntax    = { 'syntax' },
  user      = { 'user' }
}

this.NATIVE_COLORS = {
  "black","dimgray","dimgrey","gray","grey","darkgray","darkgrey","silver",
  "lightgray","lightgrey","gainsboro","whitesmoke","white","snow","rosybrown",
  "lightcoral","indianred","brown","firebrick","maroon","darkred","red",
  "mistyrose","salmon","tomato","darksalmon","coral","orangered","lightsalmon",
  "sienna","seashell","chocolate","saddlebrown","sandybrown","peachpuff","peru",
  "linen","bisque","darkorange","burlywood","antiquewhite","tan","navajowhite",
  "blanchedalmond","papayawhip","moccasin","orange","wheat","oldlace","floralwhite",
  "darkgoldenrod","goldenrod","cornsilk","gold","lemonchiffon","khaki","palegoldenrod",
  "darkkhaki","ivory","beige","lightyellow","lightgoldenrodyellow","olive","yellow",
  "olivedrab","yellowgreen","darkolivegreen","greenyellow","chartreuse","lawngreen",
  "honeydew","darkseagreen","palegreen","lightgreen","forestgreen","limegreen",
  "darkgreen","green","lime","seagreen","mediumseagreen","springgreen","mintcream",
  "mediumspringgreen","mediumaquamarine","aquamarine","turquoise","lightseagreen",
  "mediumturquoise","azure","lightcyan","aqua","cyan","darkturquoise","cadetblue",
  "powderblue","lightblue","deepskyblue","skyblue","lightskyblue","steelblue",
  "aliceblue","dodgerblue","lightslategray","lightslategrey","slategray","slategrey",
  "lightsteelblue","cornflowerblue","royalblue","ghostwhite","lavender","midnightblue",
  "navy","darkblue","mediumblue","blue","slateblue","darkslateblue","mediumslateblue",
  "mediumpurple","rebeccapurple","blueviolet","indigo","darkorchid","darkviolet",
  "mediumorchid","thistle","plum","violet","purple","darkmagenta","fuchsia","magenta",
  "orchid","mediumvioletred","deeppink","hotpink","lavenderblush","palevioletred",
  "crimson","pink","lightpink","NONE"
}

this.NATIVE_OPTIONS = {
  'aleph','concealcursor','filetype','key','operatorfunc','selectmode','tabline','varsofttabstop',
  'noarabic','conceallevel','fixendofline','keymap','nopaste','shell','tabpagemax','vartabstop',
  'arabicshape','completefunc','foldclose','keymodel','pastetoggle','shellcmdflag','tabstop','verbose',
  'foldcolumn','keywordprg','patchexpr','shellquote','tagbsearch','verbosefile','ambiwidth','noconfirm',
  'langmap','patchmode','shelltemp','tagcase','viminfofile','noautochdir','nocopyindent','foldexpr',
  'shellxquote','tagfunc','virtualedit','noautoshelldir','cpoptions','foldignore','nolangnoremap',
  'previewheight','shellxescape','taglength','novisualbell','noautoindent','cscopepathcomp',
  'foldlevel','langremap','previewpopup','noshiftround','tagrelative','warn','noautoread','cscopeprg',
  'foldlevelstart','laststatus','nopreviewwindow','shiftwidth','tags','noweirdinvert','noautowrite',
  'cscopequickfix','foldmethod','nolazyredraw','printdevice','noshortname','tagstack','whichwrap',
  'noautowriteall','nocscoperelative','foldminlines','nolinebreak','printencoding','showbreak',
  'notermbidi','wildchar','background','nocscopetag','foldnestmax','lines','printfont','noshowcmd',
  'termencoding','wildcharm','nobackup','cscopetagorder','formatexpr','nolisp','printmbcharset',
  'noshowfulltag','notermguicolors','wildignore','backupcopy','nocscopeverbose','formatprg','nolist',
  'printmbfont','noshowmatch','termwinkey','nowildignorecase','backupext','nocursorbind','fsync',
  'listchars','printoptions','showmode','termwinsize','nowildmenu','balloondelay','nocursorcolumn','nogdefault',
  'loadplugins','prompt','noallowrevins','completepopup','foldenable','langmenu','nopreserveindent',
  'showtabline','noterse','wildmode','noballoonevalterm','nocursorline','helpheight','magic','pumheight',
  'sidescroll','textauto','wildoptions','balloonexpr','debug','helplang','makeef','pumwidth','sidescrolloff',
  'notextmode','wincolor','belloff','nodelcombine','nohidden','makeencoding','pythonthreehome','signcolumn',
  'textwidth','window','nobinary','dictionary','history','makeprg','pythonhome','nosmartcase','thesaurus',
  'winheight','nobomb','nodiff','nohkmap','matchtime','pyxversion','nosmartindent','notildeop','nowinfixheight',
  'nobreakindent','diffexpr','nohkmapp','maxcombine','quickfixtextfunc','nosmarttab','timeout','nowinfixwidth',
  'breakindentopt','nodigraph','nohlsearch','maxfuncdepth','quoteescape','softtabstop','timeoutlen',
  'winminheight','bufhidden','display','noicon','maxmapdepth','noreadonly','nospell','notitle','winminwidth',
  'buflisted','eadirection','iconstring','maxmem','redrawtime','spellfile','titlelen','winwidth','buftype',
  'noedcompatible','noignorecase','maxmemtot','regexpengine','spelllang','titlestring','wrap','cdpath',
  'emoji','imactivatefunc','menuitems','norelativenumber','spelloptions','nottimeout','wrapmargin','cedit',
  'encoding','noimcmdline','modeline','remap','spellsuggest','ttimeoutlen','wrapscan','charconvert',
  'endofline','noimdisable','nomodelineexpr','report','nosplitbelow','ttybuiltin','write','nocindent','equalalways',
  'iminsert','modelines','norevins','nosplitright','ttyfast','nowriteany','cinoptions','equalprg','imsearch',
  'modifiable', 'norightleft', 'startofline', 'ttymouse', 'writebackup', 'clipboard', 'noerrorbells', 'imstatusfunc',
  'nomodified', 'noruler', 'statusline', 'ttyscroll', 'writedelay', 'cmdheight', 'esckeys', 'includeexpr', 'more',
  'rulerformat', 'suffixesadd', 'undodir', 'cmdwinheight', 'eventignore', 'noincsearch', 'mouse', 'scroll',
  'swapfile', 'noundofile', 'colorcolumn', 'noexpandtab', 'noinfercase', 'mousetime', 'noscrollbind', 'swapsync',
  'undolevels', 'columns', 'noexrc', 'noinsertmode', 'nonumber', 'scrolljump', 'switchbuf', 'undoreload', 'commentstring',
  'fileformat', 'isprint', 'numberwidth', 'scrolloff', 'synmaxcol', 'updatecount', 'nocompatible', 'fileignorecase',
  'omnifunc', 'nosecure', 'syntax', 'updatetime', 'backspace', 'backupdir', 'backupskip','breakat','casemap',
  'cinkeys', 'cinwords', 'comments', 'complete', 'completeopt', 'cryptmethod', 'cursorlineopt','define','diffopt',
  'directory', 'errorfile', 'errorformat', 'fileencoding', 'fileencodings', 'fileformats', 'fillchars', 'foldmarker',
  'foldtext', 'formatoptions', 'formatlistpat', 'grepformat', 'grepprg', 'guicursor', 'helpfile', 'highlight',
  'include', 'indentexpr', 'indentkeys', 'isfname', 'isident', 'iskeyword', 'lispwords', 'matchpairs',
  'maxmempattern', 'mkspellmem', 'mousemodel', 'nrformats', 'packpath', 'paragraphs', 'path', 'printexpr',
  'printheader', 'pythonthreedll', 'pythondll', 'rightleftcmd', 'rubydll', 'foldopen', 'joinspaces',
  'runtimepath', 'scrollopt', 'sections', 'selection', 'sessionoptions', 'shellpipe', 'shellredir', 'shortmess',
  'spellcapcheck', 'suffixes', 'term', 'termwinscroll', 'titleold', 'ttytype', 'viewdir', 'viewoptions', 'viminfo'
}

this.HL_ARGS = {
  "guifg","guibg","ctermfg","ctermbg","guisp","gui","cterm"
}

this.HL_ATTRS = {
  "bold", "underline","undercurl","underdouble","underdotted","underdashed",
  "strikethrough","reverse","inverse","italic","standout","altfont","nocombine",
  "NONE"
}

function this.init_once()
  if vim.g.easycomplete_cmdline ~= 1 then
    return
  end
  vim.g.easycomplete_cmdline_pattern = ""
  vim.g.easycomplete_cmdline_typing = 0
  this.bind_cmdline_event()
end

return this
