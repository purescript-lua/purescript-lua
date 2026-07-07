return {
  letRec = (function()
    local yes_S_0
    local no_S_1
    yes_S_0 = function(v_S_2)
      if v_S_2 then
        return no_S_1(false)
      elseif false == v_S_2 then
        return no_S_1(true)
      else
        return error("No patterns matched")
      end
    end
    no_S_1 = function(v0_S_3)
      if v0_S_3 then
        return yes_S_0(false)
      elseif false == v0_S_3 then
        return yes_S_0(true)
      else
        return error("No patterns matched")
      end
    end
    return no_S_1(false)
  end)(),
  whereRec = (function()
    local yes_S_14
    local no_S_15
    yes_S_14 = function(v_S_16)
      if v_S_16 then
        return no_S_15(false)
      elseif false == v_S_16 then
        return no_S_15(true)
      else
        return error("No patterns matched")
      end
    end
    no_S_15 = function(v0_S_17)
      if v0_S_17 then
        return yes_S_14(false)
      elseif false == v0_S_17 then
        return yes_S_14(true)
      else
        return error("No patterns matched")
      end
    end
    return no_S_15(false)
  end)(),
  letRecMixed = (function()
    local z_S_4 = 1
    local b_S_5
    local a_S_6
    b_S_5 = function() return a_S_6(z_S_4) end
    a_S_6 = function() return b_S_5(z_S_4) end
    local f_S_7_S_w = function(f_S_7_S_u1, k_S_13) return a_S_6(k_S_13) end
    local y_S_8 = f_S_7_S_w(z_S_4, z_S_4)
    return f_S_7_S_w(f_S_7_S_w(y_S_8, y_S_8), f_S_7_S_w(y_S_8, 0))
  end)()
}
