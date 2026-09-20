local util = {}
local zizz_flag = 0
local zizz_timer = vim.loop.new_timer()
local async_timer = vim.loop.new_timer()
local lua_speed = require("easycomplete.lib.speed")
local async_timer_counter = 0
local rust_speed = nil
local global_rust_ready = nil
local package_cpath_ready = false
-- 预定义的 LSP 类型列表（索引从 1 开始，对应 Vimscript 的 1-based）
local easycomplete_kinds = {
  '',           'text',        'method',         'function',
  'constructor','field',       'variable',       'class',
  'interface',  'module',      'property',       'unit',
  'value',      'enum',        'keyword',        'snippet',
  'color',      'file',        'reference',      'folder',
  'enummember', 'constant',    'struct',         'event',
  'operator',   'typeparameter', 'const'
}

local function console(...)
  local args = {...}
  local ok, res = pcall(util.console, unpack(args))
  if ok then
    return res
  else
    print(res)
  end
end

-- 给 rust 初始化需要的全局变量
-- 为了确保同名函数入参一致，viml → lua → rust
-- 一些常用的全局变量同样作为全局值带入 rust
-- rust 中每次使用最好更新一下
function init_global_vars_for_rust()
  easycomplete_pum_maxlength = vim.g.easycomplete_pum_maxlength
  easycomplete_pum_fix_width = vim.g.easycomplete_pum_fix_width
  easycomplete_first_complete_hit = vim.g.easycomplete_first_complete_hit
  easycomplete_stunt_menuitems = vim.g.easycomplete_stunt_menuitems
end

-- rust & lua
function util.parse_abbr(abbr)
  if util.rust_ready() then
    return rust_speed.parse_abbr(abbr)
  else
    return lua_speed.parse_abbr(abbr)
  end
end

function util.zizz()
  if zizz_flag > 0 then
    zizz_timer:stop()
    zizz_flag = 0
  end
  zizz_timer:start(30, 0, function()
    zizz_flag = 0
  end)
  zizz_flag = 1
end

function util.zizzing()
  if zizz_flag == 1 then
    return true
  else
    return false
  end
end

function util.get_fullpath(prefx)
  local last_path
  -- 匹配包含斜杠的路径（如 ./a/b/c、../a/b/c、/a/b/c 等）
  for path in string.gmatch(prefx, "%S+/[^%s]*") do
    last_path = path
  end
  return last_path or ""
end

-- 求一个列表t的前limit个元素
-- util.sub_table({...}, 1, 20) 求列表从1到20个元素
function util.sub_table(t, from, to)
  local result = {}
  table.move(t, from, math.min(#t, to), 1, result)
  return result
end

-- filter 函数，t 是一个输入的数组
function util.filter(t, func)
  local result = {}
  for _, v in ipairs(t) do
    if func(v) then
      table.insert(result, v)
    end
  end
  return result
end

-- items 字符串组成的数组
function util.distinct(items)
  local unique_values = {}
  local result = {}
  for _, value in ipairs(items) do
    if #value == 0 then
      -- 空字符串
      -- continue
    elseif #value == 1 and vim.g.easycomplete_cmdline_typing == 0 then
      -- 在insert模式下，把一个长度的字符也过滤掉
      -- continue
    elseif tonumber(value:sub(1,1)) ~= nil then
      -- 首字符是数字
      -- continue
    elseif not unique_values[value] then
      unique_values[value] = true
      table.insert(result, value)
    end
  end
  table.sort(result)
  return result
end

-- cpu 架构：arm64 / x86_64
function util.get_arch()
  return vim.fn["easycomplete#util#GetArch"]()
end

-- 判断是否是 MacOS
function util.is_macos()
  return vim.fn["easycomplete#util#IsMacOS"]()
end

-- Get rust speed.rs
function util.init_rust_speed()
  -- 确保库文件名为 helloworld_module.so/.dll/.dylib
  if rust_speed ~= nil then
    return rust_speed
  else
    if package_cpath_ready then
      -- do nothing
    else
      package.cpath = package.cpath .. ";" .. util.get_rust_exec_path()
      package_cpath_ready = true
    end
    init_global_vars_for_rust()
    local local_lib = require("easycomplete_rust_speed")
    rust_speed = local_lib
    return local_lib
  end
end

function util.get_rust_exec_path()
  local root_dir = vim.fn["easycomplete#util#GetEasyCompleteRootDirectory"]()
  local lib_path = nil
  if util.is_macos() then
    lib_path = root_dir .. "/target/release/"
    lib_path = lib_path .. "libeasycomplete_rust_speed.dylib"
  end
  return lib_path
end

-- 判断rust启用环境
-- 先在 MacOS x86_64 下调通
function util.rust_ready()
  if vim.g.easycomplete_rust_enable == 0 then
    return false
  end
  if global_rust_ready == true then
    return true
  elseif global_rust_ready == false then
    return false
  elseif global_rust_ready == nil then
    local lib_path = util.get_rust_exec_path()
    -- TODO mlua arm64 下重新编译
    if util.get_arch() ~= "x86_64" or not util.is_macos() then
      global_rust_ready = false
    elseif vim.fn.executable(lib_path) == 0 then
      global_rust_ready = false
    else
      global_rust_ready = true
    end
    return global_rust_ready
  end
end

function util.get_file_tags(filename)
  local lines = {}
  local tags = {}
  local file, err = io.open(filename, "r")  -- 打开文件为只读模式
  if not file then
    print("打开文件失败: " .. err)
    return {}
  end
  for line in file:lines() do  -- 使用 :lines() 迭代器逐行读取
    local tag = line:match('^([^\t]+)')
    if tag then table.insert(tags, tag) end
  end
  file:close()  -- 关闭文件
  return tags
end

-- rust & lua
function util.replacement(abbr, positions, wrap_char)
  if util.rust_ready() then
    return rust_speed.replacement(abbr, positions, wrap_char)
  else
    return lua_speed.replacement(abbr, positions, wrap_char)
  end
end

function util.complete_menu_fuzzy_filter(all_menu, word, key_name, maxlength)
  local tt = vim.fn.reltime()
  local ret = nil
  if util.rust_ready() then
    ret = rust_speed.complete_menu_fuzzy_filter(all_menu, word, key_name, maxlength)
  else
    local all_items = util.trim_array_to_length(all_menu, maxlength + 130)
    local matching_res = vim.fn.matchfuzzypos(all_items, word, {
        key = key_name,
        matchseq = 1,
        limit = maxlength
      })
    ret = util.complete_menu_filter(matching_res, word)
  end
  --console(vim.fn.reltimestr(vim.fn.reltime(tt)), #ret)
  return ret
end

function util.complete_menu_filter(matching_res, word)
  -- local tt = vim.fn.reltime()
  local ret = {}
  if util.rust_ready() then
    ret = rust_speed.complete_menu_filter(matching_res, word)
  else
    ret = lua_speed.complete_menu_filter(matching_res, word)
  end
  -- console(vim.fn.reltimestr(vim.fn.reltime(tt)), #ret)
  return ret
end

-- 主函数：LSP 类型解析
-- easycomplete#util#LspType(c_type) 重新实现
function util.lsp_type(c_type)
  local type_fullname = ""
  local type_shortname = ""

  local idx = 0
  if type(c_type) == "string" and not c_type:find("^%d%d?$") then
    type_fullname = c_type
  else
    if type(c_type) == "string" and c_type:find("^%d%d?$") then
      idx = tonumber(c_type)
    elseif type(c_type) == "number" then
      idx = c_type
    end
    idx = idx + 1

    if idx >= 1 and idx <= #easycomplete_kinds then
      type_fullname = easycomplete_kinds[idx]
    else
      type_fullname = ""
    end
  end

  if type_fullname == "var" then
    type_fullname = "variable"
  end

  -- 获取首字母作为 shortname（如果非空）
  if type(type_fullname) ~= "string" then
    type_fullname = ""
    type_shortname = ""
  elseif type(type_fullname) == "string" and type_fullname ~= "" then
    type_shortname = type_fullname:sub(1, 1)
  else
    type_shortname = ""
  end

  -- 查找符号（symble）
  local symble = ""
  local font_map = vim.g.easycomplete_lsp_type_font or {}

  if type(font_map) == "table" then
    if font_map[type_fullname] ~= nil then
      symble = font_map[type_fullname]
    else
      -- fallback 到首字母，如果不存在则使用 shortname 本身
      symble = font_map[type_shortname] or type_shortname
    end
  else
    symble = type_shortname
  end

  -- 返回结果表
  return {
    symble = symble,
    fullname = type_fullname,
    shortname = type_shortname
  }
end

-- completeAdd 中对遗留非符合格式的 item 进行 wrap
-- 601 个元素，lua 用时 10ms, rust 用时 5ms
--
-- 实际 runtime 中只有 plugin_name == buf 的 item 是裸的格式，需要 wrap 装配
-- 但不做装配也可以正常运行，为了格式统一，这里统一做装配
-- 因为这个函数是异步等 lsp 返回结果后调用的，而最晚调用的是 lsp plugin，因此
-- 而 lsp 的结果在这个函数里不耗时，因此也不影响性能
function util.final_normalize_menulist(arr, plugin_name)
  if util.rust_ready() then
    if vim.b.easycomplete_lsp_plugin and vim.b.easycomplete_lsp_plugin["name"] == plugin_name then
      return arr
    else
      return rust_speed.final_normalize_menulist(arr, plugin_name)
    end
  else
    return lua_speed.final_normalize_menulist(arr, plugin_name)
  end
end

-- easycomplete#util#BadBoy_Vim(item, typing_word) 的lua 实现
-- 实测 lua 的实现比 rust 在进行 200 次循环时快 2ms
-- - lua：6ms，rust：8ms
function util.badboy_vim(item, typing_word)
  if not util.rust_ready() then
    return lua_speed.badboy_vim(item, typing_word)
  else
    return lua_speed.badboy_vim(item, typing_word)
  end
end

-- 一个单词的 fuzzy 比对，没有计算 score
-- @param haystack, 原始单词
-- @param needle, 比对单词
-- @return boolean, 比对成功或者失败
function util.fuzzy_search(haystack, needle)
  if util.rust_ready() then
    return rust_speed.fuzzy_search(haystack, needle)
  else
    return lua_speed.fuzzy_search(haystack, needle)
  end
end

function util.matchfuzzypos(a,b,c)
  local ret = rust_speed.matchfuzzypos(a,b,c)
  return ret
end

-- easycomplete#util#GetVimCompletionItems 的 lua 实现
function util.get_vim_complete_items(response, plugin_name, word)
  local tt = vim.fn.reltime()
  local l_result = response["result"]
  local l_items = {}
  local l_incomplete = 0
  if type(l_result) == type({}) and l_result["items"] == nil then
    l_items = l_result
    l_incomplete = 0
  elseif type(l_result) == type({}) and l_result["items"] ~= nil then
    l_items = l_result["items"]
    if l_result["isIncomplete"] ~= nil then
      l_incomplete = l_result["isIncomplete"]
    else
      l_incomplete = 0
    end
  else
    l_items = {}
    l_incomplete = 0
  end

  local l_vim_complete_items = {}
  local l_items_length = #l_items
  local typing_word = word

  for _, l_completion_item in ipairs(l_items) do
    -- 这几个耗时要解决, 目前只重写了 BadBoy_Vim 函数
    if vim.o.filetype == "nim" and vim.fn['easycomplete#util#BadBoy_Nim'](l_completion_item, typing_word) then
      goto continue
    end
    if vim.o.filetype == "vim" and util.badboy_vim(l_completion_item, typing_word) then
      goto continue
    end
    if vim.o.filetype == 'dart' and vim.fn['easycomplete#util#BadBoy_Dart'](l_completion_item, typing_word) then
      goto continue
    end

    local l_expandable = false
    if l_completion_item["insertTextFormat"] == 2 then
      l_expandable = true
    end

    local l_lsp_type_obj = {}
    local l_kind = 0
    if l_completion_item["kind"] ~= nil then
      l_lsp_type_obj = util.lsp_type(l_completion_item["kind"])
      l_kind = l_completion_item["kind"]
    else
      l_lsp_type_obj = util.lsp_type(0)
      l_kind = 0
    end

    local l_menu_str = ""
    if vim.g.easycomplete_menu_abbr == 1 then
      l_menu_str = "[" .. string.upper(plugin_name) .. "]"
    else
      l_menu_str = l_lsp_type_obj["fullname"]
    end
    local l_vim_complete_item = {
      kind = l_lsp_type_obj["symble"],
      dup = 1,
      kind_number = l_kind,
      menu = l_menu_str,
      empty = 1,
      icase = 1,
      lsp_item = l_completion_item
    }
    if l_completion_item["textEdit"] ~= nil and type(l_completion_item['textEdit']) == type({}) then
      if l_completion_item['textEdit']['nextText'] ~= nil then
        l_vim_complete_item["word"] = l_completion_item['textEdit']['nextText']
      end
      if l_completion_item['textEdit']['newText'] ~= nil then
        l_vim_complete_item["word"] = l_completion_item['textEdit']['newText']
      end
    elseif l_completion_item["insertText"] ~= nil and l_completion_item['insertText'] ~= "" then
      l_vim_complete_item["word"] = l_completion_item['insertText']
    else
      l_vim_complete_item["word"] = l_completion_item['label']
    end
    if plugin_name == "cpp" and string.find(l_completion_item['label'], "^[•%s]") then
      l_vim_complete_item["word"] = string.gsub(l_completion_item['label'], "^•", "")
      l_vim_complete_item["word"] = string.gsub(l_vim_complete_item["word"], "^%s", "")
      l_completion_item["label"] = l_vim_complete_item["word"]
    end

    local l_item_user_data_json_cache = {}
    if l_expandable == true then
      local l_origin_word = l_vim_complete_item['word']
      local l_placeholder_regex = [[\$[0-9]\+\|\${\%(\\.\|[^}]\)\+}]]
      l_vim_complete_item['word'] = vim.fn['easycomplete#lsp#utils#make_valid_word'](
            vim.fn.substitute(l_vim_complete_item['word'], l_placeholder_regex, "", "g"))
      local l_placeholder_position = vim.fn.match(l_origin_word, l_placeholder_regex)
      local l_cursor_backing_steps = string.len(string.sub(l_vim_complete_item['word'], l_placeholder_position + 1))
      l_vim_complete_item['abbr'] = l_completion_item['label'] .. '~'
      local l_user_data_json = {plugin_name = plugin_name}
      if string.len(l_origin_word) > string.len(l_vim_complete_item['word']) then
        l_user_data_json = {
          expandable = 1,
          placeholder_position = l_placeholder_position,
          cursor_backing_steps = l_cursor_backing_steps
        }
        -- l_vim_complete_item['user_data'] = vim.fn.json_encode(l_user_data_json)
        l_vim_complete_item['user_data_json'] = l_user_data_json
      end
      local l_user_data_json_l = vim.fn.extend(l_user_data_json, {
          expandable = 1
        })
      -- l_vim_complete_item['user_data'] = vim.fn.json_encode(l_user_data_json_l)
      l_vim_complete_item['user_data_json'] = l_user_data_json_l
      l_item_user_data_json_cache = l_user_data_json_l
    elseif string.find(l_completion_item['label'], ".+%(.*%)") then
      l_vim_complete_item['abbr'] = l_completion_item['label']
      if vim.fn['easycomplete#SnipExpandSupport']() then
        l_vim_complete_item['word'] = l_completion_item['label']
      else
        -- 如果不支持snipexpand，则只做简易展开
        l_vim_complete_item['word'] = string.gsub(l_completion_item['label'], "%(.*%)","") .. "()"
      end
      l_vim_complete_item['user_data_json'] = {
        expandable = 1,
        placeholder_position = string.len(l_vim_complete_item['word']) - 1,
        cursor_backing_steps = 1
      }
      -- rust 里insertText字段不存在，改用 label
      local insert_text = ""
      if plugin_name == "rust" then
        if l_completion_item["insertText"] then
          insert_text = l_completion_item["insertText"]
        else
          insert_text = l_completion_item["label"]
        end
      end
      if vim.fn['easycomplete#SnipExpandSupport']() then
        if string.find(insert_text, "%${%d") then
          -- 原本就是 snippet 形式
          -- Do nothing
          l_completion_item["insertText"] = insert_text
        elseif string.find(insert_text, ".+%(.*%)$") then
          l_completion_item["insertText"] = vim.fn["easycomplete#util#NormalizeFunctionalSnip"](insert_text)
        elseif string.find(l_vim_complete_item["word"], ".+%(.*%)$") then
          l_completion_item["insertText"] = vim.fn["easycomplete#util#NormalizeFunctionalSnip"](l_vim_complete_item["word"])
        else
          -- 不是函数形式，do nogthing
          l_completion_item["insertText"] = insert_text
        end
      else
        l_vim_complete_item['user_data_json']["custom_expand"] = 1
      end
      -- l_vim_complete_item["user_data"] = vim.fn.json_encode(l_vim_complete_item['user_data_json'])
      l_item_user_data_json_cache = l_vim_complete_item['user_data_json']
    else
      l_vim_complete_item['abbr'] = l_completion_item['label']
      l_item_user_data_json_cache = {plugin_name = plugin_name}
    end
    local l_t_info = {}
    if l_completion_item["documentation"] ~= nil then
      l_t_info = vim.fn['easycomplete#util#NormalizeLspInfo'](l_completion_item["documentation"])
    else
      l_t_info = {}
    end
    if l_completion_item["detail"] == nil or l_completion_item["detail"] == "" then
      l_vim_complete_item['info'] = l_t_info
    else
      l_vim_complete_item['info'] = {l_completion_item["detail"]}
      for _, v in ipairs(l_t_info) do table.insert(l_vim_complete_item['info'], v) end
    end

    local sha256_str_o = vim.base64.encode(l_vim_complete_item['word'] .. tostring(l_vim_complete_item['info']))
    local sha256_str = string.sub(sha256_str_o, 1, 32)
    local user_data_json = vim.fn.extend(l_item_user_data_json_cache, {
             plugin_name = plugin_name,
             sha256 = sha256_str,
             lsp_item = l_completion_item
           })
    l_vim_complete_item['user_data'] = vim.fn.json_encode(user_data_json)
    l_vim_complete_item["user_data_json"] = user_data_json

    if l_vim_complete_item["word"] ~= "" then
      table.insert(l_vim_complete_items, l_vim_complete_item)
    end

    ::continue::
  end -- endfor
  -- console(vim.fn.reltimestr(vim.fn.reltime(tt)))
  return { items = l_vim_complete_items, incomplete = l_incomplete }
end -- endfunction

-- 把一个lsp返回标准格式的items列表
-- 转换为一个字符串组成的数组，主要是调试用
function util.get_plain_items(all_menu)
  local new_list = {}
  for _, value in ipairs(all_menu) do
    table.insert(new_list, value["word"])
  end
  return new_list
end

-- TODO 需要再测试一下这个函数
function util.get(a, ...)
  local args = {...}
  if type(a) ~= "table" then
    return a
  end
  local tmp_obj = a
  for i = 1, #args do
    tmp_obj = tmp_obj[args[i]]
    if tmp_obj == nil or type(tmp_obj) == nil then
      break
    end
  end
  return tmp_obj
end

-- get word or abbr
function util.get_word(a)
  local k = a.abbr
  if type(k) == nil or k == nil or k ~= "" then
    local k = a.word
  end
  return k
end

function util.isTN(item)
  local plugin_name = util.get_item_plugin_name(item)
  if plugin_name == "tn" then
    return true
  else
    return false
  end
end

function util.curr_lsp_constructor_calling()
  util.constructor_calling_by_name(util.current_plugin_name())
end

function util.show_success_message()
  vim.defer_fn(function()
    util.log("LSP is initalized successfully!")
  end, 100)
end

function util.get_configuration()
  local curr_lsp_name = util.current_lsp_name()
  return {
    easy_plugin_ctx      = util.current_plugin_ctx(),
    easy_plugin_name     = util.current_plugin_name(),
    easy_lsp_name        = curr_lsp_name,
    easy_lsp_config_path = util.get_default_config_path(),
    easy_cmd_full_path   = util.get_default_command_full_path(),
    nvim_lsp_root        = util.get(server, "root_dir"),
    -- nvim_lsp_root_path   = Server.get_server_root_path(),
    -- nvim_lsp_ok          = ok,
  }
end

-- 定义日志函数，日志写在 ~/debuglog 中
function util.debug(...)
  local args = {...}
  local homedir = os.getenv("HOME") or os.getenv("USERPROFILE")
  local filename = homedir .. "/.config/vim-easycomplete/debuglog"
  local file = io.open(filename, "w")
  if not file then
    print("无法创建或打开日志文件: ~/.config/vim-easycomplete/debuglog")
    return
  end
  -- 获取当前时间（可选）
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")

  local output_msg = ""
  for i, v in ipairs(args) do
    output_msg = output_msg .. " " .. vim.inspect(v)
  end
  -- 写入日志内容
  file:write(string.format("[%s]%s\n", timestamp, output_msg))
  -- 关闭文件
  file:close()
end

function util.constructor_calling_by_name(plugin_name)
  vim.fn['easycomplete#ConstructorCallingByName'](plugin_name)
end

function util.console(...)
  return vim.fn['easycomplete#log#log'](...)
end

function util.log(...)
  return vim.fn['easycomplete#util#info'](...)
end

function util.get_item_plugin_name(...)
  return vim.fn['easycomplete#util#GetPluginNameFromUserData'](...)
end

function util.current_plugin_ctx()
  return vim.fn['easycomplete#GetCurrentLspContext']()
end

function util.current_plugin_name()
  local curr_ctx = util.current_plugin_ctx()
  local plugin_name = util.get(curr_ctx, 'name')
  return plugin_name
end

function util.current_lsp_name()
  local curr_plugin_ctx = util.current_plugin_ctx()
  if curr_plugin_ctx.name == "ts" then
    return "tsserver"
  end
  local lsp_name = util.get(curr_plugin_ctx, "lsp", "name")
  return lsp_name
end

function util.get_default_lsp_root_path()
  local all_root = vim.fn['easycomplete#installer#LspServerDir']()
  local plugin_name = util.current_plugin_name()
  local root_path = vim.fn.join({
    all_root,
    plugin_name,
  }, "/")
  return root_path
end

function util.get_default_config_path()
  local lsp_root = util.get_default_lsp_root_path()
  local config_path = vim.fn.join({
    lsp_root,
    "config.json",
  }, "/")
  return config_path
end

function util.get_default_command_full_path()
  local curr_plugin_ctx   = util.current_plugin_ctx()
  local command_name      = util.get(curr_plugin_ctx, "command")
  local command_full_path = vim.fn.join({
    util.get_default_lsp_root_path(),
    command_name
  }, "/")
  return command_full_path
end

function util.nvim_installer_installed()
  return vim.g.loaded_nvim_lsp_installer
end

-- concat is a array
function util.create_command(file_path, content)
  if vim.fn.executable(file_path) then
    vim.fn.delete(file_path, "rf")
  end
  vim.fn.writefile(content, file_path, "a")
  vim.fn.setfperm(file_path, "rwxr-xr-x")
end

function util.create_config(file_path, content)
  if vim.fn.executable(file_path) then
    vim.fn.delete(file_path, "rf")
  end
  vim.fn.writefile(content, file_path, "a")
end

-- 根据word的长度，筛出最短的n个元素
function util.trim_array_to_length(arr, n)
  if util.rust_ready() then
    return rust_speed.trim_array_to_length(arr,n)
  else
    return lua_speed.trim_array_to_length(arr,n)
  end
end

function util.get_typing_word()
  return vim.fn['easycomplete#util#GetTypingWord']()
end

-- CompleteMenuFilter 函数句柄入口，内部会调用 complete_menu_filter
-- complete_menu_filter 只是性能优化使用的多种实现
-- 只给 cmdline 调用
function util.menu_filter(menu_list, word, max_word)
  local ret = vim.fn['easycomplete#util#CompleteMenuFilter'](menu_list, word, max_word)
  return ret
end

function util.get_buf_keywords(typing_word)
  local items_list = vim.fn['easycomplete#sources#buf#GetBufKeywords'](typing_word)
  local distinct_items = util.distinct(items_list)
  return distinct_items
end

function util.check_noice()
  local ok, nc = pcall(function()
    return require("noice.config")
  end)
  if not ok then
    return false
  else
    return nc.is_running()
  end
end

function util.easy_lsp_installed()
  local plugin_name = vim.fn["easycomplete#util#GetLspPluginName"]()
  local current_lsp_ctx = util.current_plugin_ctx()
  local easy_available_command = vim.fn["easycomplete#installer#GetCommand"](plugin_name)
  if plugin_name == "ts" and string.find(easy_available_command, "tsserver$") then
    return true
  end
  local easy_lsp_ready = util.get(current_lsp_ctx, "lsp", "ready")
  if easy_available_command ~= "" and easy_lsp_ready == true then
    return true
  else
    return false
  end
end

function util.async_run(func, args, timeout)
  async_timer:start(timeout, 0, function()
    if type(func) == "string" then
      -- 如果是字符串，则作为全局函数名调用
      local f = vim.fn[func]
      if type(f) == "function" then
        vim.schedule(function()
          local ok,err = pcall(f, unpack(args))
          if not ok then
            print("async_run调用失败:", err)
          end
        end)
      else
        vim.schedule(function()
          vim.notify("async_run: 全局函数不存在或不是函数: " .. func, vim.log.levels.ERROR)
        end)
      end
    elseif type(func) == "function" then
      -- 如果是函数对象，直接调用
      vim.schedule(function()
        local ok,err = pcall(func, unpack(args))
        if not ok then
          print("async_run调用失败:", err)
        end
      end)
    else
      vim.schedule(function()
        vim.notify("async_run: 无效的函数类型", func, vim.log.levels.ERROR)
      end)
    end
  end)
  return async_timer_counter + 1
end

function util.trim_before(str)
  if str == "" then return "" end
  return string.gsub(str, "^%s*(.-)$", "%1")
end

-- 判断一个list中是否包含某个字符串元素
function util.has_item(tb, it)
  return vim.tbl_contains(tb, it)
end

function util.stop_async_run()
  async_timer:stop()
  async_timer_counter = 0
end

function util.defer_fn(func_name, args, timeout)
  if type(func_name) == "string" then
    -- 如果是字符串，则作为全局函数名调用
    local f = vim.fn[func_name]
    if type(f) == "function" then
      vim.defer_fn(function()
        vim.schedule(function()
          local ok, err = pcall(f, unpack(args))
          if not ok then
            print("defer_fn调用失败:", err)
          end
        end)
      end, timeout)
    else
      vim.schedule(function()
        vim.notify("defer_fn: 全局函数不存在或不是函数: " .. func_name, timeout, vim.log.levels.ERROR)
      end)
    end
  else
    vim.schedule(function()
      vim.notify("defer_fn: 传入参数不是字符串", vim.log.levels.ERROR)
    end)
  end
end

-- util 初始化入口
function util.init_once()
  if util.rust_ready() then
    util.init_rust_speed()
    -- console(rust_speed.hello("hello", "rust"))
    -- local data = {name = "Alice", age = 30, active = true}
    -- console(rust_speed.replacement("1234",{1,2},"x"))
    -- console(rust_speed.get_first_complete_hit())
  end
end

return util
