local speed = {}

local function console(...)
  return vim.fn['easycomplete#log#log'](...)
end

function speed.final_normalize_menulist(arr, plugin_name)
  if #arr == 0 then
    return {}
  end
  if vim.b.easycomplete_lsp_plugin and vim.b.easycomplete_lsp_plugin["name"] == plugin_name then
    return arr
  end
  if plugin_name == "snips" then
    return arr
  end
  local l_menu_list = {}
  -- 601 个元素，用时 10ms
  for _, item in ipairs(arr) do
    -- 这里item会转换为"table: 0x0109a29a00"，base64后无需截短
    local sha256_str = vim.base64.encode(tostring(item))
    local r_user_data = {}
    local t_user_data = {
      plugin_name = plugin_name,
      sha256 = sha256_str
    }
    if plugin_name == "ts" and item.user_data ~= nil then
      r_user_data = vim.fn.extend(vim.fn.json_decode(item.user_data), t_user_data)
    else
      r_user_data = t_user_data
    end
    table.insert(l_menu_list, vim.fn.extend({
          word = '',
          menu = '',
          user_data = vim.fn.json_encode(r_user_data),
          equal = 0,
          dup = 1,
          info = '',
          kind = '',
          abbr = '',
          kind_number = 0,
          plugin_name = plugin_name,
          user_data_json = r_user_data
      }, item))
  end
  return l_menu_list
end

function speed.replacement(abbr, positions, wrap_char)
  -- 转换为字符数组（字符串 -> 字符表）
  local letters = {}
  for i = 1, #abbr do
    -- lua 的 string.sub 是根据字节长度取下表对应的字符，而不是字符长度
    -- 因此对于 unicode 字符就取不正确，需要用 vim.fn.strcharpart 代替
    -- letters[i] = abbr:sub(i, i)
    letters[i] = vim.fn.strcharpart(abbr, i - 1, 1)
  end
  -- 对每个位置进行包裹处理
  for _, idx in ipairs(positions) do
    if idx >= 0 and idx < #letters then
      letters[idx+1] = wrap_char .. letters[idx+1] .. wrap_char
    end
  end
  -- 合并成新字符串
  local res_o = table.concat(letters)
  local res_r = string.gsub(res_o, "%" .. wrap_char .. "%" .. wrap_char, "")
  return res_r
end

function speed.parse_abbr(abbr)
  local max_length = vim.g.easycomplete_pum_maxlength
  if #abbr <= max_length then
    if vim.g.easycomplete_pum_fix_width == 1 then
      local spaces = string.rep(" ", max_length - #abbr)
      return abbr .. spaces
    else
      return abbr
    end
  else
    local short_abbr = string.sub(abbr, 1, max_length - 1) .. "…"
    return short_abbr
  end
end

function speed.complete_menu_filter(matching_res, word)
  local fullmatch_result = {} -- 完全匹配
  local firstchar_result = {} -- 首字母匹配
  local fuzzymatching = matching_res[1]
  local fuzzy_position = matching_res[2]
  local fuzzy_scores = matching_res[3]
  local fuzzymatch_result = {}

  for i, item in ipairs(fuzzymatching) do
    if item["abbr"] == nil or item["abbr"] == "" then
      item["abbr"] = item["word"]
    end
    local abbr = item["abbr"]
    abbr = speed.parse_abbr(abbr)
    item["abbr"] = abbr
    local p = fuzzy_position[i]
    item["abbr_marked"] = speed.replacement(abbr, p, "§")
    item["marked_position"] = p
    item["score"] = fuzzy_scores[i]
    if string.find(string.lower(item["word"]), string.lower(word)) == 1 then
      table.insert(fullmatch_result, item)
    -- elseif string.lower(string.sub(item["word"],1,1)) == string.lower(string.sub(word,1,1)) then
    --   table.insert(firstchar_result, item)
    else
      table.insert(fuzzymatch_result, item)
    end
  end

  local stunt_items = vim.fn["easycomplete#GetStuntMenuItems"]()

  if #stunt_items == 0 and vim.g.easycomplete_first_complete_hit == 1 then
    table.sort(fuzzymatch_result, function(a, b)
      return #a.word < #b.word -- 按 word 字段的长度升序排序
    end)
  end

  local filtered_menu = {}
  for _, v in ipairs(fullmatch_result) do table.insert(filtered_menu, v) end
  for _, v in ipairs(firstchar_result) do table.insert(filtered_menu, v) end
  for _, v in ipairs(fuzzymatch_result) do table.insert(filtered_menu, v) end
  return filtered_menu
end

-- lua 实现比 rust 要快，原因待查
function speed.badboy_vim(item, typing_word)
  local word = ""
  if item["label"] then
    word = item["label"]
  end
  if #word == 0 then
    return true
  elseif #typing_word == 1 then
    local pos = string.find(word, typing_word)
    if pos == nil then
      return true
    elseif pos >= 0 and pos <= 5 then
      return false
    else
      return true
    end
  else
    if speed.fuzzy_search(typing_word, word) then
      return false
    else
      return true
    end
  end
end

-- fuzzy_search("AsyncController","ac") true
function speed.fuzzy_search(haystack, needle)
  if #haystack > #needle then
    return false
  end
  local haystack = string.lower(haystack)
  local needle = string.lower(needle)
  if #haystack == #needle then
    if haystack == needle then
      return true
    else
      return false
    end
  end
  -- string.find("easycomplete#context","[0-9a-z#]*z[0-9a-z#]*t[0-9a-z#_]*")
  -- string.gsub("easy", "(.)", "-%1")
  local middle_regx = "[0-9a-z#_]*"
  local needle_ls_regx = string.gsub(haystack, "(.)", "%1" .. middle_regx)
  local idx = string.find(needle, needle_ls_regx)
  if idx ~= nil and idx <= 2 then
    return true
  else
    return false
  end
end

-- 根据word的长度，筛出最短的n个元素
function speed.trim_array_to_length(arr, n)
  -- 如果数组长度小于等于 n，直接返回原数组
  if #arr <= n then
    return arr
  end

  -- 创建一个包含索引和 word 长度的表
  local arr_length_arr = {}
  for idx, item in ipairs(arr) do
    table.insert(arr_length_arr, {
      idx = idx - 1,        -- Lua 索引从 1 开始，Vim 从 0 开始，所以存 idx-1 以匹配原逻辑
      length = #item.word   -- strlen(item["word"]) 等价于 #item.word
    })
  end

  -- 按长度升序排序：短的在前
  table.sort(arr_length_arr, function(a, b)
    return a.length < b.length
  end)

  -- 取前 n 个最短的项
  local new_arr_length_arr = {}
  for i = 1, n do
    table.insert(new_arr_length_arr, arr_length_arr[i])
  end

  -- 根据原始索引从原数组中取出对应元素
  local ret = {}
  for _, item in ipairs(new_arr_length_arr) do
    table.insert(ret, arr[item.idx + 1])  -- 转回 Lua 索引
  end

  return ret
end

return speed
