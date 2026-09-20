local util = require "easycomplete.util"
local log = util.log
local console = util.console
local normal_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#$_"
local global_ghost_tx_ns = vim.api.nvim_create_namespace('global_ghost_tx_ns')
local current_ghost_text = ""
local M = {}

local function is_cursor_at_EOL()
  -- 获取当前窗口的光标位置 (返回值为 {行号, 列号})
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1  -- 行号从0开始计数，所以减1
  local col = cursor[2]

  -- 获取当前行的文本
  local lines = vim.api.nvim_buf_get_lines(0, row, row + 1, false)
  if #lines == 0 then return true end  -- 如果没有获取到行，则认为是在行尾

  local line = lines[1]
  line = line:gsub("%s*$", "")

  -- 检查光标位置是否等于或超过行的长度
  if col >= #line then
    -- 光标位于行末或者超出行末
    return true
  else
    -- 光标不在行末
    return false
  end
end

local function get_next_char()
  -- 获取当前行内容（行号从 1 开始）
  local line = vim.fn.getline('.')

  -- 获取光标位置：{row, col}，列是 1-based
  local cursor = vim.api.nvim_win_get_cursor(0)  -- 0 表示当前窗口
  local row, col = cursor[1], cursor[2]

  -- 计算下一个字符的位置（列从 0 开始索引，所以 col 是 0-based）
  local next_col = col + 1  -- 下一个字符的索引（Lua 字符串索引从 1 开始）

  -- 检查是否越界
  if next_col >= 1 and next_col <= #line then
    return line:sub(next_col, next_col)
  else
    return ""  -- 光标已在行尾，无下一个字符
  end
end

function M.nvim_init_ghost_hl()
  local cursorline_bg = vim.fn["easycomplete#ui#GetBgColor"]("CursorLine")
  local normal_bg = vim.fn["easycomplete#ui#GetBgColor"]("Normal")
  local linenr_fg = vim.fn["easycomplete#ui#GetFgColor"]("LineNr")

  local snippet_fg = ""
  if vim.fn["easycomplete#ui#HighlightGroupExists"]("EasySnippets") then
    snippet_fg = vim.fn["easycomplete#ui#GetFgColor"]("EasySnippets")
  else
    snippet_fg = linenr_fg
  end

  if vim.fn.matchstr(cursorline_bg, "^\\d\\+") ~= "" then
    cursorline_bg = vim.fn.str2nr(cursorline_bg)
  end
  if vim.fn.matchstr(normal_bg, "^\\d\\+") ~= "" then
    normal_bg = vim.fn.str2nr(normal_bg)
  end
  if vim.fn.matchstr(snippet_fg, "^\\d\\+") ~= "" then
    snippet_fg = vim.fn.str2nr(snippet_fg)
  end

  vim.api.nvim_set_hl(0, "TabNineSuggestionFirstLine", {
    bg = cursorline_bg,
    fg = snippet_fg
  })
  vim.api.nvim_set_hl(0, "TabNineSuggestionNoneFirstLine", {
    fg = snippet_fg,
    bg = normal_bg
  })
end

local function stop_ghost_timer()
  vim.fn["easycomplete#StopSecondCompleteGhostTimer"]()
end

-- code_block 是一个字符串，有可能包含回车符
-- call v:lua.require("easycomplete.ghost_text").show_hint()
-- code_block 是数组类型
function M.show_hint(code_block)
  local virt_text = vim.fn.deepcopy({{
    code_block[1],
    "TabNineSuggestionFirstLine"
  }})
  local opt = {
    id = 1,
    virt_text_pos = "inline",
    virt_text = virt_text,
    -- virt_lines = virt_lines,
    -- virt_text_win_col = vim.fn.virtcol('.') - 1
  }
  -- 如果光标后跟随字幕，则不展开 ghost，如果是单词边界，则展开ghost
  local next_char = get_next_char()
  if next_char ~= "" and string.find(normal_chars, next_char, 1, true) then
    -- do nothing
  else
    vim.api.nvim_buf_set_extmark(0, global_ghost_tx_ns, vim.fn.line('.') - 1, vim.fn.col('.') - 1, opt)
  end

  current_ghost_text = code_block[1]
end

local function onkey_event_prevented()
  if vim.g.easycomplete_onkey_event == nil or vim.g.easycomplete_onkey_event == 0 then
    return true
  else
    return false
  end
end

local function safe_redraw()
  if vim.fn.has('nvim-0.10') then
    vim.api.nvim__redraw({
        win = vim.fn.win_getid(),
        flush = true
      })
  end
end

local function ghost_text_bind_event()
  if not vim.g.easycomplete_ghost_text then
    return
  end
  local curr_key = nil
  -- 注册按键监听器
  vim.on_key(function(keys, _)
    -- 这里不论是否是插入模式，都会触发，需要过滤掉
    if vim.api.nvim_get_mode().mode ~= "i" then
      return
    end
    if onkey_event_prevented() then
      return
    end
    -- 将按键字节序列转换为字符串
    local key_str = vim.api.nvim_replace_termcodes(keys, true, false, true)
    -- 更新 last_key 变量
    curr_key = key_str
    do
      ------{{ ghost_handler --------------------------------
      if vim.api.nvim_get_mode().mode ~= "i" then
        return
      end
      if onkey_event_prevented() then
        return
      end
      if curr_key == nil or string.byte(curr_key) == nil then
        return
      end
      -- 这里连续输入极快时会有抖动，原因是输入过有时会一次前进两个字符
      -- 这时处理占位符时要按两个步长来处理，因此这里记录了上一次输入
      stop_ghost_timer()
      if curr_key and string.find(normal_chars, curr_key, 1, true) then
        -- 正常输入
        if vim.fn["easycomplete#pum#visible"]() then
          local ok, err = pcall(function()
            local ghost_text = current_ghost_text
            if ghost_text == "" or #ghost_text == 1 then
              M.delete_hint()
              vim.g.easycomplete_ghost_text_str = ""
            elseif #ghost_text >= 2 then
              local new_ghost_text = string.sub(ghost_text, 2)
              current_ghost_text = new_ghost_text
              if #new_ghost_text == 0 then
                M.delete_hint()
              else
                M.show_hint({new_ghost_text})
              end
              vim.g.easycomplete_ghost_text_str = new_ghost_text
            end
            -- safe_redraw()
          end)
          if not ok then
            print("Ghost Text Error: " .. err)
          end
        end
      elseif curr_key and string.byte(curr_key) == 8 then
        -- 退格键
        if vim.fn["easycomplete#pum#visible"]() then
          local ok, err = pcall(function()
            local ghost_text = current_ghost_text
            if ghost_text == "" then
              -- M.delete_hint()
              vim.g.easycomplete_ghost_text_str = ""
            elseif #ghost_text >= 1 then
              local new_ghost_text = string.rep("a", 1) .. ghost_text
              M.show_hint({new_ghost_text})
              vim.g.easycomplete_ghost_text_str = new_ghost_text
            end
            -- safe_redraw()
          end)
          if not ok then
            print("Ghost Text Error BackSpace " .. err)
          end
        else
          M.delete_hint()
          vim.g.easycomplete_ghost_text_str = ""
        end
      else
        -- 其他字符
      end
      curr_key = nil
      ------}} ghost_handler --------------------------------
    end -- end do
  end)
  vim.api.nvim_create_autocmd({"CursorMovedI"}, {
      pattern = "*",
      callback = function()
      end,
    })
end

function M.init_once()
  if vim.g.easycomplete_ghost_txt_tmp_ready == 1 then
    return
  end
  vim.g.easycomplete_ghost_txt_tmp_ready = 1
  ghost_text_bind_event()
end

function M.delete_hint()
  vim.api.nvim_buf_del_extmark(0, global_ghost_tx_ns, 1)
  current_ghost_text = ""
end

return M
