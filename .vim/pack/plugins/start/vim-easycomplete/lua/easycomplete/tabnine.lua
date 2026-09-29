local Util = require "easycomplete.util"
local loading = require "easycomplete.loading"
local ghost_text = require "easycomplete.ghost_text"
local log = Util.log
local console = Util.console
local Export = {}

function Export.init_once()
  -- exec once
  if vim.g.easycomplete_tabnine_tmp_ready == 1 then
    return
  end
  vim.g.easycomplete_tabnine_tmp_ready = 1
  ghost_text.nvim_init_ghost_hl()
  vim.api.nvim_create_autocmd({"ColorScheme"}, {
    pattern = {"*"},
    callback = function()
      ghost_text.nvim_init_ghost_hl()
    end
  })
end

function Export.loading_start()
  loading.start()
end

function Export.loading_stop()
  loading.stop()
end

-- code_block 是一个字符串，有可能包含回车符
-- call v:lua.require("easycomplete.tabnine").show_hint()
-- code_block 是数组类型
function Export.show_hint(code_block)
  ghost_text.show_hint(code_block)
end

function Export.delete_hint()
  ghost_text.delete_hint()
end

return Export
