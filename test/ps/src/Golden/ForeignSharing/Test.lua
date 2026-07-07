return {
  same = (function(a)
    return function(b)
      return rawequal(a, b)
    end
  end)
}
