local M = {}
M.Golden_Values_Test_f = function() return true end
return {
  a = 1,
  b = "b",
  c = (function()
    local v_S_6 = function() return 0 end
    if M.Golden_Values_Test_f(2) then
      if M.Golden_Values_Test_f(1) then return 42 else return v_S_6(true) end
    else
      return v_S_6(true)
    end
  end)(),
  J = function(value0)
    return { ["$ctor"] = "Golden.CaseStatements.Test∷M.J", value0 = value0 }
  end,
  N = { ["$ctor"] = "Golden.CaseStatements.Test∷M.N" },
  d = function(m_S_34)
    return function(n_S_35)
      return function(x_S_36)
        local v_S_37 = function()
          if "y" == x_S_36 then return 0 else return 1 end
        end
        if "x" == x_S_36 then
          if "Golden.CaseStatements.Test∷M.J" == m_S_34["$ctor"] then
            if "Golden.CaseStatements.Test∷M.N" == n_S_35["$ctor"] then
              return m_S_34.value0
            else
              return v_S_37(true)
            end
          else
            return v_S_37(true)
          end
        else
          return v_S_37(true)
        end
      end
    end
  end,
  multipleGuards = 1
}
