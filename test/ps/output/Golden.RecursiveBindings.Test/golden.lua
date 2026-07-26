return {
  letRec = (function()
    local yes_S_0_S_loop
    local yes_S_0
    local v0_S_0
    yes_S_0_S_loop = function(_S_sel0, _S_a0)
      while true do
        if _S_sel0 == 1 then
          local v_S_0 = _S_a0
          if v_S_0 then
            _S_sel0, _S_a0 = 2, false
          else
            _S_sel0, _S_a0 = 2, true
          end
        else
          local v0_S_0 = _S_a0
          if v0_S_0 then
            _S_sel0, _S_a0 = 1, false
          else
            _S_sel0, _S_a0 = 1, true
          end
        end
      end
    end
    yes_S_0 = function(v_S_0) return yes_S_0_S_loop(1, v_S_0) end
    v0_S_0 = false
    return yes_S_0_S_loop(2, v0_S_0)
  end)(),
  whereRec = (function()
    local yes_S_1_S_loop
    local yes_S_1
    local v0_S_1
    yes_S_1_S_loop = function(_S_sel1, _S_a1)
      while true do
        if _S_sel1 == 1 then
          local v_S_1 = _S_a1
          if v_S_1 then
            _S_sel1, _S_a1 = 2, false
          else
            _S_sel1, _S_a1 = 2, true
          end
        else
          local v0_S_1 = _S_a1
          if v0_S_1 then
            _S_sel1, _S_a1 = 1, false
          else
            _S_sel1, _S_a1 = 1, true
          end
        end
      end
    end
    yes_S_1 = function(v_S_1) return yes_S_1_S_loop(1, v_S_1) end
    v0_S_1 = false
    return yes_S_1_S_loop(2, v0_S_1)
  end)(),
  letRecMixed = (function()
    local z_S_0 = 1
    local b_S_0_S_loop
    local b_S_0
    local a_S_0
    b_S_0_S_loop = function(_S_sel2)
      while true do if _S_sel2 == 1 then _S_sel2 = 2 else _S_sel2 = 1 end end
    end
    b_S_0 = function() return b_S_0_S_loop(1) end
    a_S_0 = function() return b_S_0_S_loop(2) end
    local f_S_0_S_w = function(f_S_0_S_u1, k_S_0) return a_S_0(k_S_0) end
    local y_S_0 = f_S_0_S_w(z_S_0, z_S_0)
    return f_S_0_S_w(f_S_0_S_w(y_S_0, y_S_0), f_S_0_S_w(y_S_0, 0))
  end)()
}
