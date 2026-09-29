local M = {}
local Util = require "easycomplete.util"
local console = Util.console
local snip_cache = {}

-- normalize_info 把占位符去掉，为了给info显示用
local function normalize_info(docstring)
  if docstring == "" then
    return {}
  end
  local new_lines = {}
  local snip_lines = vim.split(docstring, "\n")
  for i, line_str in pairs(snip_lines) do
    local subline = string.gsub(line_str, "%${[^{^}]-}", "")
    local subline = string.gsub(subline, "%${[^{^}]-}", "")
    new_lines[#new_lines + 1] = subline
  end
  return new_lines
end

-- luasnip 对 snipmate 的支持不好，如果片段中有多个没有替代符的占位符"${1}"
-- luasnip 无法通过 Tab 来跳转，必须要加上一个空格作为站位
local function hack_snipmate(docstring)
  return docstring:gsub("%${(%d+)%}", "${%1: }")
end


function M.luasnip_installed()
  -- do return false end
  if vim.g.easycomplete_lua_snip_enable == nil then
    local ok, ls = pcall(function()
      return require("luasnip")
    end)
    if not ok then
      vim.g.easycomplete_lua_snip_enable = 0
      return false
    else
      vim.g.easycomplete_lua_snip_enable = 1
    end
  end
  if vim.g.easycomplete_lua_snip_enable == 1 then
    return true
  else
    return false
  end
end

function M.init_once()
  -- exec once
  if vim.g.easycomplete_lua_snip_checkdone == 1 then
    return
  end
  vim.g.easycomplete_lua_snip_checkdone = 1
  if not M.luasnip_installed() then
    return
  end
  require('luasnip').filetype_extend("typescript", { "javascript" })
  local snip_path = ""
  if vim.g.easycomplete_custom_snippet == "" then
    snip_path = vim.fn["easycomplete#util#GetEasyCompleteRootDirectory"]() .. '/snippets'
  else
    snip_path = vim.g.easycomplete_custom_snippet
  end
  if vim.fn.filereadable(snip_path .. '/package.json') == 1 then
    require("luasnip.loaders.from_vscode").lazy_load({ path = { snip_path } })
    vim.g.easycomplete_luasnip_from_where = "vscode"
  else
    require("luasnip.loaders.from_snipmate").lazy_load({ path = { snip_path } })
    vim.g.easycomplete_luasnip_from_where = "snipmate"
  end
  M.bind_snip_event()
end

function M.bind_snip_event()
  vim.keymap.set('s', '<Tab>', function()
    if require('luasnip').locally_jumpable(1) then
      require('luasnip').jump(1)
    end
  end, { expr = true, silent = true })
  vim.keymap.set('s', '<S-Tab>', function()
    if require('luasnip').locally_jumpable(-1) then
      require('luasnip').jump(-1)
    end
  end, { expr = true, silent = true })
end

function M.get_snip_items(typing, plugin_name, ctx)
  if not M.luasnip_installed() then
    return {}
  end

  local ls = require("luasnip")
  -- TODO: 如果 buffer 中输入了一个 snip，删除后未保存，在原位置
  -- 继续输入字符，则会判断为in_snippet，返回空，实则不应该判断
  -- 为 in_snippet，需进一步调试
  if ls.in_snippet() then
    return {}
  end
  local filetypes = require("luasnip.util.util").get_snippet_filetypes()
  local all_items = {}
  local matched_items = {}
  for i = 1, #filetypes do
    local ft = filetypes[i]
    if not snip_cache[ft] then
      local ft_items = {}
      local ft_table = ls.get_snippets(ft, {type = "snippets"})
      local tab = ft_table
      local auto = false
      for j, snip in pairs(tab) do
        if not snip.hidden then -- and string.sub(string.lower(snip.trigger), 1, #typing) == string.lower(typing) then
          local sha256 = vim.fn["easycomplete#util#Sha256"](snip.trigger)
          sha256 = string.sub(sha256, 1, 16)
          local user_data_json = {
            plugin_name = plugin_name,
            sha256 = sha256
          }
          local ok, user_data = pcall(vim.fn.json_encode, user_data_json)
          if not ok then
            return {}
          end

          local snip_docstring = ""
          if vim.g.easycomplete_luasnip_from_where == "snipmate" then
            snip_docstring = hack_snipmate(snip.docstring)
          else
            snip_docstring = snip.docstring
          end

          ft_items[#ft_items + 1] = {
            word = snip.trigger,
            abbr = snip.trigger .. "~",
            kind = vim.g.easycomplete_kindflag_snip,
            menu = vim.g.easycomplete_menuflag_snip,
            user_data = user_data,
            info = vim.list_extend({"Snippet: " .. snip.trigger, "--------"}, normalize_info(snip.docstring)),
            docstring = snip_docstring,
            label = snip.trigger,
            user_data_json = user_data_json,
            data = {
              priority = snip.effective_priority or 1000, -- Default priority is used for old luasnip versions
              filetype = ft,
              snip_id = snip.id,
              show_condition = snip.show_condition,
              auto = auto
            },
          }
        end
      end
      table.sort(ft_items, function(a, b)
        return a.data.priority > b.data.priority
      end)
      snip_cache[ft] = ft_items
    end -- if
    vim.list_extend(all_items, snip_cache[ft])
  end
  for _, item in pairs(all_items) do
    if string.sub(string.lower(item.word), 1, #typing) == string.lower(typing) then
      matched_items[#matched_items + 1] = item
    end
  end
  return matched_items
end

return M
