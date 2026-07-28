return {
  b = function(x_S_0)
    return function() if 1 == x_S_0 then return 1 else return 3 end end
  end,
  c = function(x_S_1)
    return function(x1_S_0)
      if 1 == x1_S_0 then
        return 1
      elseif 1 == x_S_1 then
        return 2
      else
        return 3
      end
    end
  end
}
