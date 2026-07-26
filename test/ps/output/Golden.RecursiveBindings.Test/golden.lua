return {
  letRec = (function()
    local yes_S_0_S_loop
    local yes_S_0
    local v0_S_3
    yes_S_0_S_loop = function(_S_sel0, _S_a1)
      while true do
        if _S_sel0 == 1 then
          local v_S_2 = _S_a1
          if v_S_2 then
            _S_sel0, _S_a1 = 2, false
          else
            _S_sel0, _S_a1 = 2, true
          end
        else
          local v0_S_3 = _S_a1
          if v0_S_3 then
            _S_sel0, _S_a1 = 1, false
          else
            _S_sel0, _S_a1 = 1, true
          end
        end
      end
    end
    yes_S_0 = function(v_S_2) return yes_S_0_S_loop(1, v_S_2) end
    v0_S_3 = false
    return yes_S_0_S_loop(2, v0_S_3)
  end)(),
  whereRec = (function()
    local yes_S_14_S_loop
    local yes_S_14
    local v0_S_17
    yes_S_14_S_loop = function(_S_sel2, _S_a3)
      while true do
        if _S_sel2 == 1 then
          local v_S_16 = _S_a3
          if v_S_16 then
            _S_sel2, _S_a3 = 2, false
          else
            _S_sel2, _S_a3 = 2, true
          end
        else
          local v0_S_17 = _S_a3
          if v0_S_17 then
            _S_sel2, _S_a3 = 1, false
          else
            _S_sel2, _S_a3 = 1, true
          end
        end
      end
    end
    yes_S_14 = function(v_S_16) return yes_S_14_S_loop(1, v_S_16) end
    v0_S_17 = false
    return yes_S_14_S_loop(2, v0_S_17)
  end)(),
  letRecMixed = (function()
    local z_S_4 = 1
    local b_S_5_S_loop
    local b_S_5
    local a_S_6
    b_S_5_S_loop = function(_S_sel4)
      while true do if _S_sel4 == 1 then _S_sel4 = 2 else _S_sel4 = 1 end end
    end
    b_S_5 = function() return b_S_5_S_loop(1) end
    a_S_6 = function() return b_S_5_S_loop(2) end
    local f_S_7_S_w = function(f_S_7_S_u1, k_S_13) return a_S_6(k_S_13) end
    local y_S_8 = f_S_7_S_w(z_S_4, z_S_4)
    return f_S_7_S_w(f_S_7_S_w(y_S_8, y_S_8), f_S_7_S_w(y_S_8, 0))
  end)()
}
