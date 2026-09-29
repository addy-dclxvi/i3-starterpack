-- local debug = true
local EasyComplete = {}
local util = require "easycomplete.util"
local console = util.console
local log = util.log
local global_timer = vim.loop.new_timer()
local global_timer_counter = 1

-- 全局配置函数
-- @param config, 全局配置的对象
-- @return this, 以便链式调用
function EasyComplete.config(config)
  for key, value in pairs(config) do
    if key == "setup" and type(value) == "function" then
      pcall(value)
    else
      vim.g["easycomplete_" .. key] = value
    end
  end
  return EasyComplete
end

-- setup 函数，传入一个方法，这个方法是一个空入参的立即执行的函数
-- @param func，一个立即执行的函数
-- @return this, 以便链式调用
function EasyComplete.setup(func)
  if func == nil then
    return
  end
  if type(func) == 'function' then
    pcall(func)
  end
  return EasyComplete
end

function EasyComplete.complete_changed()
  console('--',util.get(vim.v.event, "completed_item", "user_data"))
end

-- 执行typing的函数，已经废弃
function EasyComplete.typing(...)
  local ctx = vim.fn['easycomplete#context']()
  print({
    console(vim.v.event)
  })

  print({
    pcall(function()
      console { aaa = 123 , bb = 456 }
      local aaa = vim.api.nvim_command("echo g:easycomplete_default_plugin_init")
    end)
  })
end

-- 执行每个模块里的 init_once 方法
-- @param mojos, 一个 table，传入需要初始化的模块名称
-- @return nil
function EasyComplete.load_mojo(mojos)
  if vim.g.easycomplete_lua_mojos_loaded == 1 then
    return
  end
  vim.g.easycomplete_lua_mojos_loaded = 1
  for i, mojo in ipairs(mojos) do
    local mojo_name = "easycomplete." .. mojo
    local Mo = require(mojo_name)
    Mo.init_once()
  end
end

-- 全局的 lua 初始化入口
function EasyComplete.init()
  EasyComplete.load_mojo({"autocmd", "tabnine", "ghost_text", "luasnip", "cmdline", "util"})
end

-- 普通的 cmp items 排序方法，只做最简单的比较
-- @param items, cmp items 列表
-- @reutrn 返回排序后的列表
function EasyComplete.normalize_sort(items)
  table.sort(items, function(a1, a2)
    local k1 = util.get_word(a1)
    local l1 = #k1
    local k2 = util.get_word(a2)
    local l2 = #k2
    return l1 > l2
  end)

  table.sort(items, function(a1, a2)
    local k1 = util.get_word(a1)
    local k2 = util.get_word(a2)
    return k1 > k2
  end)
  return items
end


-- 字符串组成的数组进行去重
-- @param items, 字符串数组
-- @return table, 去重后的数组
function EasyComplete.distinct(items)
  return util.distinct(items)
end

-- 根据 buflines 分割出来关键词
-- @param table list, 传入buflines
-- @return table, 字符串数组，这里的数组没有去重
function EasyComplete.get_buf_keywords_from_lines(lines)
  local buf_keywords = {}
  for _, line in ipairs(lines) do
    if vim.bo.filetype == "lua" then
      for word in line:gmatch("[0-9a-zA-Z_]+") do
        table.insert(buf_keywords, word)
      end
    else
      for word in line:gmatch("[0-9a-zA-Z_#]+") do
        table.insert(buf_keywords, word)
      end
    end
  end
  return buf_keywords
end

-- 一个单词的 fuzzy 比对，没有计算 score
-- @param haystack, 原始单词
-- @param needle, 比对单词
-- @return boolean, 比对成功或者失败
function EasyComplete.fuzzy_search(haystack, needle)
  return util.fuzzy_search(haystack, needle)
end

-- vim.fn.matchfuzzy 的重新实现，只返回结果，不返回分数
-- @param match_list, 待比对的数组列表
-- @param needle, 比对的单词
-- @return table, 返回比对成功的列表
function EasyComplete.matchfuzzy_and_filter(match_list, needle)
  local result = {}
  for _, item in ipairs(match_list) do
    if EasyComplete.fuzzy_search(needle, item) then
      table.insert(result, item)
    end
  end
  return result
end

-- 简单的过滤，只通过做模糊匹配来过滤，不考虑fuzzymatch 的分数
-- @param match_list, 原始列表
-- @param needle, 比对单词
-- @return table，返回过滤后的列表
function EasyComplete.filter(match_list, needle)
  local result = {}
  for _, item in ipairs(match_list) do
    if #item < #needle then
      -- pass
      goto continue
    elseif item == needle then
      -- pass
      table.insert(result, item)
      goto continue
    end
    local idx = string.find(string.lower(item), "" .. string.lower(needle))
    if type(idx) == type(2) and idx <= 3 then
      table.insert(result, item)
    end
    ::continue::
  end
  return result
end

-- 假设 s:GetItemWord(item) 在 Lua 中对应 item.word
-- @param item
-- @return word
local function get_item_word(item)
  return item.word or ""
end

local function find_string_pos(arr, target)
  for i, str in ipairs(arr) do
    if str == target then
      return i  -- 返回找到的索引
    end
  end
  return 0  -- 如果未找到，则返回 0
end

-- 给 menu_list 去重，只在 Firstcomplete 中调用
-- 这两个函数耗时相等，570个元素耗时3~4ms
-- @param menu_list, 待去重的列表，列表元素是 cmp item
-- @return table, 去重后的列表
function EasyComplete.distinct_keywords_new(menu_list)
  if not menu_list or #menu_list == 0 then
    return {}
  end

  local result_items = {}
  local buf_list = {}

  -- 第一步：收集所有来自 'buf' 的 word
  for _, item in ipairs(menu_list) do
    local plugin_name = item.plugin_name or ""
    if plugin_name == "buf" then
      table.insert(buf_list, item.word)
    end
  end

  local same_word_list = {}
  for _, item in ipairs(menu_list) do
    local plugin_name = item.plugin_name or ""
    if plugin_name == "buf" or plugin_name == "snips" then
      goto continue
    end

    local word = get_item_word(item)
    local idx = find_string_pos(buf_list, word)
    if idx >= 1 then
      table.remove(buf_list, idx)
    end
    ::continue::
  end

  for _, item in ipairs(menu_list) do
    local plugin_name = item.plugin_name or ""
    local word = get_item_word(item)
    if plugin_name == "buf" and vim.tbl_contains(buf_list, word) then
      table.insert(result_items, item)
    elseif plugin_name ~= "buf" then
      table.insert(result_items, item)
    end
  end

  return result_items
end

function EasyComplete.distinct_keywords(menu_list)
  if not menu_list or #menu_list == 0 then
    return {}
  end

  local result_items = menu_list
  local buf_list = {}

  -- 第一步：收集所有来自 'buf' 的 word
  for _, item in ipairs(menu_list) do
    local plugin_name = item.plugin_name or ""
    if plugin_name == "buf" then
      table.insert(buf_list, item.word)
    end
  end

  -- 第二步：如果 word 被 buf 包含，且是 buf 类型，则从结果中移除
  for _, item in ipairs(menu_list) do
    local plugin_name = item.plugin_name or ""
    if plugin_name == "buf" or plugin_name == "snips" then
      goto continue
    end

    local word = get_item_word(item)
    if vim.tbl_contains(buf_list, word) then
      -- 过滤掉 result_items 中 plugin_name == "buf" 且 word 相同的项
      for i = #result_items, 1, -1 do
        local it = result_items[i]
        if (it.plugin_name == "buf") and (it.word == word) then
          table.remove(result_items, i)
        end
      end
    end
    ::continue::
  end
  return result_items
end

-- 注册源
function EasyComplete.register_source(tb)
  vim.fn["easycomplete#RegisterSource"](tb)
end

-- 注册 lsp server
function EasyComplete.register_lsp_server(opt, tb)
  vim.fn["easycomplete#RegisterLspServer"](opt, tb)
end

-- 获得 lsp 命令
function EasyComplete.get_command(plugin_name)
  return vim.fn["easycomplete#installer#GetCommand"](plugin_name)
end

-- 得到插件根目录
function EasyComplete.get_default_root_uri()
  return vim.fn["easycomplete#util#GetDefaultRootUri"]()
end

-- 调用 lsp complete
function EasyComplete.do_lsp_complete(opt, ctx)
  return vim.fn["easycomplete#DoLspComplete"](opt, ctx)
end

-- 调用 lsp defination
function EasyComplete.do_lsp_defination()
  return vim.fn["easycomplete#DoLspDefinition"]()
end

-- 判断 diagnostics 中是否已经包含 item（根据 sortNumber）
function EasyComplete.has(diagnostics, item)
  local item_sort = item.sortNumber
  if not item_sort then return false end

  for _, elem in ipairs(diagnostics) do
    if elem.sortNumber == item_sort then
      return true
    end
  end

  return false
end

-- 对 diagnostics 列表进行去重
function EasyComplete.sign_distinct(diagnostics)
  if not diagnostics or #diagnostics == 0 then
    return {}
  end

  local ret = {}
  for _, item in ipairs(diagnostics) do
    if not EasyComplete.has(ret, item) then
      table.insert(ret, item)
    end
  end

  return ret
end

function EasyComplete.replacement(abbr, positions, wrap_char)
  return util.replacement(abbr, positions, wrap_char)
end

function EasyComplete.global_timer_start(function_name, timeout)
  global_timer:start(timeout, 0, function()
    vim.schedule(function()
      -- vim.fn[function_name]()
      local ok, err = pcall(vim.fn[function_name])
      if not ok then
        print("EasyComplete 调用失败:", err)
      end
    end)
  end)
end

-- buf_list + dict_list 去重后做 normalize 包裹
function EasyComplete.combine_list(buf_list, dict_list)
  local combined_list = {}
  for _, v in ipairs(buf_list) do table.insert(combined_list, v) end
  for _, v in ipairs(dict_list) do table.insert(combined_list, v) end
  local combine_all = EasyComplete.distinct(combined_list)
  local ret_list = {}
  for _, v in ipairs(combine_all) do
    local kind_str = ""
    local menu_str = ""
    if vim.tbl_contains(buf_list, v) then
      kind_str = vim.g.easycomplete_kindflag_buf
      menu_str = vim.g.easycomplete_menuflag_buf
    else
      kind_str = vim.g.easycomplete_kindflag_dict
      menu_str = vim.g.easycomplete_menuflag_dict
    end
    table.insert(ret_list, {
        word = v,
        dup = 1,
        icase = 1,
        equal = 1,
        info = "",
        abbr = v,
        kind = kind_str,
        menu = menu_str,
      })
  end
  return ret_list
end

function EasyComplete.global_timer_stop()
  global_timer:stop()
end

return EasyComplete

