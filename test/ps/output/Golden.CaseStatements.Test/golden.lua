return {
  a = 1,
  b = "b",
  c = 42,
  J = function(value0_S_0)
    return { "Golden.CaseStatements.Test∷M.J", value0_S_0 }
  end,
  N = { "Golden.CaseStatements.Test∷M.N" },
  d = function(m_S_0)
    return function(n_S_0)
      return function(x_S_0)
        local v_S_0 = function()
          if "y" == x_S_0 then return 0 else return 1 end
        end
        if "x" == x_S_0 then
          if "Golden.CaseStatements.Test∷M.J" == m_S_0[1] then
            if "Golden.CaseStatements.Test∷M.N" == n_S_0[1] then
              return m_S_0[2]
            else
              return v_S_0(true)
            end
          else
            return v_S_0(true)
          end
        else
          return v_S_0(true)
        end
      end
    end
  end,
  multipleGuards = 1
}
