local pum = require("easycomplete.pum")
local util = require "easycomplete.util"
local console = util.console
local M = {}
local input_chars_vec = {}
local auto_pair_funcs = {
  "AutoPairsInsert("
}

local function match_autopair_func()
  local matched = false
  local input_chars = table.concat(input_chars_vec, "")
  for _, value in ipairs(auto_pair_funcs) do
    if string.sub(input_chars, -#value) == value then
      matched = true
      break
    end
  end
  if matched then
    input_chars_vec = {}
  end
  return matched
end

function M.hack_pair_input(keys)
  if not pum.visible() then
    return
  end
  if #input_chars_vec > 30 then
    table.remove(input_chars_vec,1)
  end
  table.insert(input_chars_vec, keys)
  if match_autopair_func() then
    vim.defer_fn(function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-cr>", true, true, true), 't', true)
    end,10)
  end
end

return M
