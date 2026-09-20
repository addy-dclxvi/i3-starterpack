local pum = {}

function pum.complete(start_col, menu_items)
  vim.fn["easycomplete#pum#complete"](start_col, menu_items)
end

function pum.close()
  vim.fn["easycomplete#pum#close"]()
end

function pum.bufid()
  local pum_bufid = vim.fn['easycomplete#pum#bufid']()
  return pum_bufid
end

function pum.winid()
  local pum_winid = vim.fn['easycomplete#pum#winid']()
  return pum_winid
end

function pum.visible()
  return vim.fn["easycomplete#pum#visible"]()
end

function pum.selected()
  return vim.fn['easycomplete#pum#CompleteCursored']()
end

function pum.selected_item()
  return vim.fn['easycomplete#pum#CursoredItem']()
end

function pum.select(index)
  return vim.fn['easycomplete#pum#select'](index)
end

function pum.select_next()
  vim.fn['easycomplete#pum#next']()
end

function pum.select_prev()
  vim.fn['easycomplete#pum#prev']()
end

-- for cmdline only
function pum.get_path_cmp_items()
  local typing_path = vim.fn['easycomplete#sources#path#TypingAPath']()
  -- 取根目录
  -- insert模式下为了避免和输入注释"//"频繁干扰，去掉了根目录的路径匹配
  -- 这里不存在这个频繁干扰的问题，再加回来
  if string.find(typing_path.prefx,"%s/$") ~= nil then
    typing_path.is_path = 1
  end
  if typing_path.is_path == 0 then
    return {}
  else
    local ret = vim.fn['easycomplete#sources#path#GetDirAndFiles'](typing_path, typing_path.fname)
    return ret
  end
end

return pum
