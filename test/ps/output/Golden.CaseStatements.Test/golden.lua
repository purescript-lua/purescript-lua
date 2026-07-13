return {
  a = 1,
  b = "b",
  c = 42,
  J = function(value0) return { "Golden.CaseStatements.Test∷M.J", value0 } end,
  N = { "Golden.CaseStatements.Test∷M.N" },
  d = function(m_S_10)
    return function(n_S_11)
      return function(x_S_12)
        local v_S_13 = function()
          if "y" == x_S_12 then return 0 else return 1 end
        end
        if "x" == x_S_12 then
          if "Golden.CaseStatements.Test∷M.J" == m_S_10[1] then
            if "Golden.CaseStatements.Test∷M.N" == n_S_11[1] then
              return m_S_10[2]
            else
              return v_S_13(true)
            end
          else
            return v_S_13(true)
          end
        else
          return v_S_13(true)
        end
      end
    end
  end,
  multipleGuards = 1
}
