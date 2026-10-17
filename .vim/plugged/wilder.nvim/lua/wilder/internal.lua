local _M = {}

_M.fzy_filter = function(xs, q)
  local scores = require'fzy-lua-native'.filter(q, xs, false)
  result = {}

  table.sort(scores, function(a, b)
    if b[3] == nil then
      return true
    elseif a[3] == nil then
      return false
    end

    return a[3] > b[3]
  end)

  for i = 1, #scores do
    table.insert(result, scores[i][1])
  end

  return result
end

local cached_pattern = nil
local cached_re = nil

_M.pcre2_highlight = function(pattern, str)
  local pcre2 = require('pcre2')

  local re
  if pattern == cached_pattern then
    re = cached_re
  else
    re = assert(pcre2.new(pattern, pcre2.UCP, pcre2.UTF))
    re:jit_compile()
  end

  local head, tail, err = re:match(str)
  if err or not head then
    return 0
  end

  local chunks = {}

  current_start = nil
  current_end = nil

  -- remove first element which is the matched string
  for i = 2, #head do
    -- filter empty matches {0, 0}
    if tail[i] > 0 then
      if current_start == nil then
        current_start = head[i]
        current_end = tail[i]
      else
        next_start = head[i]
        next_end = tail[i]

        -- merge 2 contiguous chunks together
        if next_start == current_end + 1 then
          current_end = next_end
        else
          -- add the current chunk
          -- convert from {start+1}, {end+1} to {start}, {len}
          table.insert(chunks, {current_start - 1, current_end - current_start + 1})
          current_start = next_start
          current_end = next_end
        end
      end
    end
  end

  if current_start ~= nil then
    table.insert(chunks, {current_start - 1, current_end - current_start + 1})
  end

  return chunks
end

_M.fzy_highlight = function(needle, haystack)
  local fzy = require('fzy-lua-native')

  if not fzy.has_match(needle, haystack) then
    return 0
  end

  local positions = fzy.positions(needle, haystack)

  if #positions == 0 then
    return {}
  end

  local spans = {}
  local start = positions[1] - 1
  local finish = positions[1] - 1

  -- consecutive sequences may represent multibyte characters so
  -- we merge them together
  for i = 2, #positions do
    local current = positions[i] - 1

    if current ~= finish + 1 then
      table.insert(spans, {start, finish - start + 1})
      start = current
    end

    finish = current
  end

  table.insert(spans, {start, finish - start + 1})

  return spans
end

return _M
