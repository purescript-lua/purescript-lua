return {
  a = 1,
  b = "b",
  c = 42,
  J = function(value0) return { "Golden.CaseStatements.Test∷M.J", value0 } end,
  N = { "Golden.CaseStatements.Test∷M.N" },
  d = function(m_S_34)
    return function(n_S_35)
      return function(x_S_36)
        local v_S_37 = function()
          if "y" == x_S_36 then return 0 else return 1 end
        end
        if "x" == x_S_36 then
          if "Golden.CaseStatements.Test∷M.J" == m_S_34[1] then
            if "Golden.CaseStatements.Test∷M.N" == n_S_35[1] then
              return m_S_34[2]
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
