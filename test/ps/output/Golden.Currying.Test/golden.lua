return {
  apply = function(f1_S_0) return function(x_S_0) return f1_S_0(x_S_0) end end,
  f = function()
    return function()
      return function() return function() return "ok" end end
    end
  end
}
