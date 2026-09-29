local M = {}
local Util = require "easycomplete.util"
local console = Util.console
local loading_ns = vim.api.nvim_create_namespace('loading_ns')
local loading_timer = vim.loop.new_timer()
local loading_chars = {'⠇','⠋','⠙','⠸','⢰','⣠','⣄','⡆'}
local cursor = 1

local function set_loading_interval(interval, callback)
  loading_timer:start(interval, interval, function ()
    callback()
  end)
end

local function clear_loading_interval()
  loading_timer:stop()
end

function M.start()
  local count = 1
  set_loading_interval(90, function()
    count = count + 1
    vim.schedule(function()
      if cursor == 1 and vim.fn["easycomplete#pum#visible"]() then
        M.stop()
        return
      end
      vim.api.nvim_buf_set_extmark(0, loading_ns, vim.fn.line('.') - 1, vim.fn.col('.') - 1, {
          id = 2,
          virt_text_pos = "eol",
          virt_text = {{tostring(M.get_loading_str()) .. "", "TabNineSuggestionFirstLine"}},
          virt_lines = nil
        })
    end)
  end)
end

function M.stop()
  if type(loading_timer) == "userdata" then
    clear_loading_interval()
    vim.api.nvim_buf_del_extmark(0, loading_ns, 2)
  end
end

function M.get_loading_str()
  if cursor < #loading_chars then
    cursor = cursor + 1
  elseif cursor == #loading_chars then
    cursor = 1
  end
  return loading_chars[cursor]
end

return M
