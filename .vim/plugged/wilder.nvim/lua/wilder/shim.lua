-- wilder#lua#wrap() : VimL -> intermediate representation
-- shim.unwrap       : intermediate representation -> Lua
-- there is no shim.wrap since Lua -> VimL is safe

local function unwrap_function(f)
  local index = f.index
  local prox = newproxy(true)
  local prox_mt = getmetatable(prox)
  prox_mt.__gc = vim.schedule_wrap(function()
    vim.call('wilder#lua#unref_wrapped_function', index)
  end)
  f[prox] = true

  return function(...)
    -- use f.index so closure holds a reference to f
    return require('wilder.shim').unwrap(vim.call('wilder#lua#call_wrapped_function', f.index, ...))
  end
end

local function unwrap(t)
  if type(t) == "table" then
    if t.__wilder_wrapped__ == 477094643697281 then
      return unwrap_function(t)
    end

    for key, value in pairs(t) do
      t[key] = unwrap(value)
    end
  end

  if type(t) == "list" then
    for index, value in pairs(t) do
      t[index] = unwrap(value)
    end
  end

  return t
end

local function call(f, ...)
  return require('wilder.shim').unwrap(vim.call('wilder#lua#call', f, ...))
end

return {
  call = call,
  unwrap = unwrap,
}
