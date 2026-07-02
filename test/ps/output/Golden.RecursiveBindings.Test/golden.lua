return {
  letRec = (function()
    local yes
    local no
    yes = function(v)
      if v then
        return no(false)
      else
        if false == v then
          return no(true)
        else
          return error("No patterns matched")
        end
      end
    end
    no = function(v)
      if v then
        return yes(false)
      else
        if false == v then
          return yes(true)
        else
          return error("No patterns matched")
        end
      end
    end
    return no(false)
  end)(),
  whereRec = (function()
    local yes
    local no
    yes = function(v)
      if v then
        return no(false)
      else
        if false == v then
          return no(true)
        else
          return error("No patterns matched")
        end
      end
    end
    no = function(v)
      if v then
        return yes(false)
      else
        if false == v then
          return yes(true)
        else
          return error("No patterns matched")
        end
      end
    end
    return no(false)
  end)(),
  letRecMixed = (function()
    local z = 1
    local b
    local a
    b = function() return a(z) end
    a = function() return b(z) end
    local f = function() return function(k) return a(k) end end
    local y = f(z)(z)
    return f(f(y)(y))(f(y)(0))
  end)()
}
