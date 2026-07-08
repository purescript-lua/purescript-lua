local M = {}
M.Data_Semigroup_foreign = {
  concatString = function(s1) return function(s2) return s1 .. s2 end end
}
M.Data_Show_foreign = {
  showIntImpl = function(n) return tostring(n) end,
  showStringImpl = function(s)
    -- Mirror PureScript's `show`: wrap in double quotes and escape control
    -- characters, '"' and '\' so the result round-trips to a String literal.
    local out = { "\"" }
    local len = #(s)
    local i = 1
    while i <= len do
      local c = s:sub(i, i)
      local b = c:byte()
      if c == "\"" or c == "\\" then
        out[#(out) + 1] = "\\" .. c
      elseif b == 7 then
        out[#(out) + 1] = "\\a"
      elseif b == 8 then
        out[#(out) + 1] = "\\b"
      elseif b == 12 then
        out[#(out) + 1] = "\\f"
      elseif b == 10 then
        out[#(out) + 1] = "\\n"
      elseif b == 13 then
        out[#(out) + 1] = "\\r"
      elseif b == 9 then
        out[#(out) + 1] = "\\t"
      elseif b == 11 then
        out[#(out) + 1] = "\\v"
      elseif b < 32 or b == 127 then
        -- numeric escape; "\&" guards against a following digit being
        -- swallowed into the escape (e.g. "\27\&5" /= "\275").
        local nxt = s:sub(i + 1, i + 1)
        local gap = nxt >= "0" and nxt <= "9" and "\\&" or ""
        out[#(out) + 1] = "\\" .. tostring(b) .. gap
      else
        out[#(out) + 1] = c
      end
      i = i + 1
    end
    out[#(out) + 1] = "\""
    return table.concat(out)
  end
}
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end
}
M.Unsafe_Coerce_foreign = { unsafeCoerce = function(x) return x end }
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Control_Semigroupoid_semigroupoidFn = {
  compose = function(f)
    return function(g) return function(x) return f(g(x)) end end
  end
}
M.Control_Semigroupoid_compose = function(dict) return dict.compose end
M.Data_Show_show = function(dict) return dict.show end
M.Data_Functor_map = function(dict) return dict.map end
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Data_Either_Left = function(value0)
  return { ["$ctor"] = "Data.Either∷Either.Left", value0 = value0 }
end
M.Data_Either_Right = function(value0)
  return { ["$ctor"] = "Data.Either∷Either.Right", value0 = value0 }
end
M.Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function()
    return {
      map = function(f_S_501)
        return function(m_S_502) return f_S_501(m_S_502) end
      end
    }
  end
}
M.Data_Identity_applicativeIdentity = {
  pure = function(x_S_503) return x_S_503 end,
  Apply0 = function() return M.Data_Identity_applyIdentity end
}
M.Data_Identity_monadIdentity = {
  Applicative0 = function() return M.Data_Identity_applicativeIdentity end,
  Bind1 = function()
    return {
      bind = function(v_S_87)
        return function(f_S_88) return f_S_88(v_S_87) end
      end,
      Apply0 = function() return M.Data_Identity_applyIdentity end
    }
  end
}
M.Control_Monad_Except_Trans_compose = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)
M.Control_Monad_Except_Trans_ExceptT = function(x) return x end
M.Control_Monad_Except_Trans_monadExceptT = function(dictMonad)
  return {
    Applicative0 = function()
      return M.Control_Monad_Except_Trans_applicativeExceptT(dictMonad)
    end,
    Bind1 = function()
      return M.Control_Monad_Except_Trans_bindExceptT(dictMonad)
    end
  }
end
M.Control_Monad_Except_Trans_bindExceptT = function(dictMonad)
  return {
    bind = function(v)
      return function(k)
        return M.Control_Bind_bind(dictMonad.Bind1())(v)(function(v2_S_506)
          if "Data.Either∷Either.Left" == v2_S_506["$ctor"] then
            return M.Control_Monad_Except_Trans_compose(M.Control_Applicative_pure(dictMonad.Applicative0()))(M.Data_Either_Left)(v2_S_506.value0)
          elseif "Data.Either∷Either.Right" == v2_S_506["$ctor"] then
            return k(v2_S_506.value0)
          else
            return error("No patterns matched")
          end
        end)
      end
    end,
    Apply0 = function()
      return M.Control_Monad_Except_Trans_applyExceptT(dictMonad)
    end
  }
end
M.Control_Monad_Except_Trans_applyExceptT = function(dictMonad)
  return {
    apply = (function()
      local dictMonad_S_509 = M.Control_Monad_Except_Trans_monadExceptT(dictMonad)
      local bind_S_510 = M.Control_Bind_bind(dictMonad_S_509.Bind1())
      return function(f_S_511)
        return function(a_S_512)
          return bind_S_510(f_S_511)(function(fPrime_S_513)
            return bind_S_510(a_S_512)(function(aPrime_S_514)
              return M.Control_Applicative_pure(dictMonad_S_509.Applicative0())(fPrime_S_513(aPrime_S_514))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return {
        map = function(f_S_498)
          return function(v_S_500)
            local Data_Functor_map = M.Data_Functor_map
            return Data_Functor_map(((dictMonad.Bind1()).Apply0()).Functor0())(Data_Functor_map({
              map = function(f_S_507)
                return function(m_S_508)
                  if "Data.Either∷Either.Left" == m_S_508["$ctor"] then
                    return M.Data_Either_Left(m_S_508.value0)
                  elseif "Data.Either∷Either.Right" == m_S_508["$ctor"] then
                    return M.Data_Either_Right(f_S_507(m_S_508.value0))
                  else
                    return error("No patterns matched")
                  end
                end
              end
            })(f_S_498))(v_S_500)
          end
        end
      }
    end
  }
end
M.Control_Monad_Except_Trans_applicativeExceptT = function(dictMonad)
  local Control_Monad_Except_Trans_compose = M.Control_Monad_Except_Trans_compose
  return {
    pure = Control_Monad_Except_Trans_compose(M.Control_Monad_Except_Trans_ExceptT)(Control_Monad_Except_Trans_compose(M.Control_Applicative_pure(dictMonad.Applicative0()))(M.Data_Either_Right)),
    Apply0 = function()
      return M.Control_Monad_Except_Trans_applyExceptT(dictMonad)
    end
  }
end
M.Golden_LongExceptBind_Test_bind = M.Control_Bind_bind(M.Control_Monad_Except_Trans_bindExceptT(M.Data_Identity_monadIdentity))
M.Golden_LongExceptBind_Test_except = M.Control_Monad_Except_Trans_compose(M.Control_Monad_Except_Trans_ExceptT)(M.Control_Applicative_pure(M.Data_Identity_applicativeIdentity))
M.Golden_LongExceptBind_Test_go = (function()
  local _S_kont518 = function(x1_S_519)
    return function(x160_S_520)
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x160_S_520)(1))))(function( x161 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x161)(1))))(function( x162 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x162)(1))))(function( x163 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x163)(1))))(function( x164 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x164)(1))))(function( x165 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x165)(1))))(function( x166 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x166)(1))))(function( x167 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x167)(1))))(function( x168 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x168)(1))))(function( x169 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x169)(1))))(function( x170 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x170)(1))))(function( x171 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x171)(1))))(function( x172 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x172)(1))))(function( x173 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x173)(1))))(function( x174 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x174)(1))))(function( x175 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x175)(1))))(function( x176 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x176)(1))))(function( x177 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x177)(1))))(function( x178 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x178)(1))))(function( x179 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x179)(1))))(function( x180 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x180)(1))))(function( x181 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x181)(1))))(function( x182 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x182)(1))))(function( x183 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x183)(1))))(function( x184 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x184)(1))))(function( x185 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x185)(1))))(function( x186 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x186)(1))))(function( x187 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x187)(1))))(function( x188 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x188)(1))))(function( x189 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x189)(1))))(function( x190 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x190)(1))))(function( x191 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x191)(1))))(function( x192 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x192)(1))))(function( x193 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x193)(1))))(function( x194 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x194)(1))))(function( x195 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x195)(1))))(function( x196 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x196)(1))))(function( x197 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x197)(1))))(function( x198 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x198)(1))))(function( x199 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x199)(1))))(function( x200 )
                                                                                      return M.Control_Applicative_pure(M.Control_Monad_Except_Trans_applicativeExceptT(M.Data_Identity_monadIdentity))(M.Data_Semiring_foreign.intAdd(x1_S_519)(x200))
                                                                                    end)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end
  end
  local _S_kont521 = function(x1_S_522)
    return function(x120_S_523)
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x120_S_523)(1))))(function( x121 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x121)(1))))(function( x122 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x122)(1))))(function( x123 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x123)(1))))(function( x124 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x124)(1))))(function( x125 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x125)(1))))(function( x126 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x126)(1))))(function( x127 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x127)(1))))(function( x128 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x128)(1))))(function( x129 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x129)(1))))(function( x130 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x130)(1))))(function( x131 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x131)(1))))(function( x132 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x132)(1))))(function( x133 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x133)(1))))(function( x134 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x134)(1))))(function( x135 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x135)(1))))(function( x136 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x136)(1))))(function( x137 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x137)(1))))(function( x138 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x138)(1))))(function( x139 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x139)(1))))(function( x140 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x140)(1))))(function( x141 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x141)(1))))(function( x142 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x142)(1))))(function( x143 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x143)(1))))(function( x144 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x144)(1))))(function( x145 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x145)(1))))(function( x146 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x146)(1))))(function( x147 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x147)(1))))(function( x148 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x148)(1))))(function( x149 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x149)(1))))(function( x150 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x150)(1))))(function( x151 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x151)(1))))(function( x152 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x152)(1))))(function( x153 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x153)(1))))(function( x154 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x154)(1))))(function( x155 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x155)(1))))(function( x156 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x156)(1))))(function( x157 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x157)(1))))(function( x158 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x158)(1))))(function( x159 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x159)(1))))(function( x160 )
                                                                                      return _S_kont518(x1_S_522)(x160)
                                                                                    end)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end
  end
  local _S_kont524 = function(x1_S_525)
    return function(x80_S_526)
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x80_S_526)(1))))(function( x81 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x81)(1))))(function( x82 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x82)(1))))(function( x83 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x83)(1))))(function( x84 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x84)(1))))(function( x85 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x85)(1))))(function( x86 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x86)(1))))(function( x87 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x87)(1))))(function( x88 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x88)(1))))(function( x89 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x89)(1))))(function( x90 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x90)(1))))(function( x91 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x91)(1))))(function( x92 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x92)(1))))(function( x93 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x93)(1))))(function( x94 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x94)(1))))(function( x95 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x95)(1))))(function( x96 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x96)(1))))(function( x97 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x97)(1))))(function( x98 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x98)(1))))(function( x99 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x99)(1))))(function( x100 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x100)(1))))(function( x101 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x101)(1))))(function( x102 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x102)(1))))(function( x103 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x103)(1))))(function( x104 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x104)(1))))(function( x105 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x105)(1))))(function( x106 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x106)(1))))(function( x107 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x107)(1))))(function( x108 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x108)(1))))(function( x109 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x109)(1))))(function( x110 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x110)(1))))(function( x111 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x111)(1))))(function( x112 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x112)(1))))(function( x113 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x113)(1))))(function( x114 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x114)(1))))(function( x115 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x115)(1))))(function( x116 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x116)(1))))(function( x117 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x117)(1))))(function( x118 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x118)(1))))(function( x119 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x119)(1))))(function( x120 )
                                                                                      return _S_kont521(x1_S_525)(x120)
                                                                                    end)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end
  end
  local _S_kont527 = function(x1_S_528)
    return function(x40_S_529)
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x40_S_529)(1))))(function( x41 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x41)(1))))(function( x42 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x42)(1))))(function( x43 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x43)(1))))(function( x44 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x44)(1))))(function( x45 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x45)(1))))(function( x46 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x46)(1))))(function( x47 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x47)(1))))(function( x48 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x48)(1))))(function( x49 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x49)(1))))(function( x50 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x50)(1))))(function( x51 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x51)(1))))(function( x52 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x52)(1))))(function( x53 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x53)(1))))(function( x54 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x54)(1))))(function( x55 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x55)(1))))(function( x56 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x56)(1))))(function( x57 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x57)(1))))(function( x58 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x58)(1))))(function( x59 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x59)(1))))(function( x60 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x60)(1))))(function( x61 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x61)(1))))(function( x62 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x62)(1))))(function( x63 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x63)(1))))(function( x64 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x64)(1))))(function( x65 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x65)(1))))(function( x66 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x66)(1))))(function( x67 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x67)(1))))(function( x68 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x68)(1))))(function( x69 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x69)(1))))(function( x70 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x70)(1))))(function( x71 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x71)(1))))(function( x72 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x72)(1))))(function( x73 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x73)(1))))(function( x74 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x74)(1))))(function( x75 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x75)(1))))(function( x76 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x76)(1))))(function( x77 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x77)(1))))(function( x78 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x78)(1))))(function( x79 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x79)(1))))(function( x80 )
                                                                                      return _S_kont524(x1_S_528)(x80)
                                                                                    end)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end
  end
  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(1)))(function( x1 )
    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x1)(1))))(function( x2 )
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x2)(1))))(function( x3 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x3)(1))))(function( x4 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x4)(1))))(function( x5 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x5)(1))))(function( x6 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x6)(1))))(function( x7 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x7)(1))))(function( x8 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x8)(1))))(function( x9 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x9)(1))))(function( x10 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x10)(1))))(function( x11 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x11)(1))))(function( x12 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x12)(1))))(function( x13 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x13)(1))))(function( x14 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x14)(1))))(function( x15 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x15)(1))))(function( x16 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x16)(1))))(function( x17 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x17)(1))))(function( x18 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x18)(1))))(function( x19 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x19)(1))))(function( x20 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x20)(1))))(function( x21 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x21)(1))))(function( x22 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x22)(1))))(function( x23 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x23)(1))))(function( x24 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x24)(1))))(function( x25 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x25)(1))))(function( x26 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x26)(1))))(function( x27 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x27)(1))))(function( x28 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x28)(1))))(function( x29 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x29)(1))))(function( x30 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x30)(1))))(function( x31 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x31)(1))))(function( x32 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x32)(1))))(function( x33 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x33)(1))))(function( x34 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x34)(1))))(function( x35 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x35)(1))))(function( x36 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x36)(1))))(function( x37 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x37)(1))))(function( x38 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x38)(1))))(function( x39 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Data_Semiring_foreign.intAdd(x39)(1))))(function( x40 )
                                                                                  return _S_kont527(x1)(x40)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end)()
M.Golden_LongExceptBind_Test_compute = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)(M.Unsafe_Coerce_foreign.unsafeCoerce)(function( v_S_39 )
  return v_S_39
end)(M.Golden_LongExceptBind_Test_go)
return M.Effect_Console_foreign.log(M.Data_Show_show({
  show = function(v_S_189_S_517)
    if "Data.Either∷Either.Left" == v_S_189_S_517["$ctor"] then
      return M.Data_Semigroup_foreign.concatString("(Left ")(M.Data_Semigroup_foreign.concatString(M.Data_Show_show({
        show = M.Data_Show_foreign.showStringImpl
      })(v_S_189_S_517.value0))(")"))
    elseif "Data.Either∷Either.Right" == v_S_189_S_517["$ctor"] then
      return M.Data_Semigroup_foreign.concatString("(Right ")(M.Data_Semigroup_foreign.concatString(M.Data_Show_show({
        show = M.Data_Show_foreign.showIntImpl
      })(v_S_189_S_517.value0))(")"))
    else
      return error("No patterns matched")
    end
  end
})(M.Golden_LongExceptBind_Test_compute))()
