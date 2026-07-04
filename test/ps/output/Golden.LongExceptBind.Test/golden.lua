local M = {}
M.Data_Show_foreign = {
  showIntImpl = function(n) return tostring(n) end,
  showStringImpl = function(s)
      -- Mirror PureScript's `show`: wrap in double quotes and escape control
      -- characters, '"' and '\' so the result round-trips to a String literal.
      local out = {"\""}
      local len = #s
      local i = 1
      while i <= len do
        local c = s:sub(i, i)
        local b = c:byte()
        if c == "\"" or c == "\\" then
          out[#out + 1] = "\\" .. c
        elseif b == 0x07 then
          out[#out + 1] = "\\a"
        elseif b == 0x08 then
          out[#out + 1] = "\\b"
        elseif b == 0x0C then
          out[#out + 1] = "\\f"
        elseif b == 0x0A then
          out[#out + 1] = "\\n"
        elseif b == 0x0D then
          out[#out + 1] = "\\r"
        elseif b == 0x09 then
          out[#out + 1] = "\\t"
        elseif b == 0x0B then
          out[#out + 1] = "\\v"
        elseif b < 0x20 or b == 0x7F then
          -- numeric escape; "\&" guards against a following digit being
          -- swallowed into the escape (e.g. "\27\&5" /= "\275").
          local nxt = s:sub(i + 1, i + 1)
          local gap = (nxt >= "0" and nxt <= "9") and "\\&" or ""
          out[#out + 1] = "\\" .. tostring(b) .. gap
        else
          out[#out + 1] = c
        end
        i = i + 1
      end
      out[#out + 1] = "\""
      return table.concat(out)
    end
}
M.Data_Semiring_foreign = {
  intAdd = function(x) return function(y) return x + y end end,
  intMul = function(x) return function(y) return x * y end end
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
M.Data_Either_append = function(s1) return function(s2) return s1 .. s2 end end
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
      map = function(f_S_1228)
        return function(m_S_1229) return f_S_1228(m_S_1229) end
      end
    }
  end
}
M.Data_Identity_applicativeIdentity = {
  pure = function(x_S_1230) return x_S_1230 end,
  Apply0 = function() return M.Data_Identity_applyIdentity end
}
M.Data_Identity_monadIdentity = {
  Applicative0 = function() return M.Data_Identity_applicativeIdentity end,
  Bind1 = function()
    return {
      bind = function(v_S_102)
        return function(f_S_103) return f_S_103(v_S_102) end
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
        return M.Control_Bind_bind(dictMonad.Bind1())(v)(function(v2_S_1233)
          if "Data.Either∷Either.Left" == v2_S_1233["$ctor"] then
            return M.Control_Monad_Except_Trans_compose(M.Control_Applicative_pure(dictMonad.Applicative0()))(M.Data_Either_Left)(v2_S_1233.value0)
          else
            if "Data.Either∷Either.Right" == v2_S_1233["$ctor"] then
              return k(v2_S_1233.value0)
            else
              return error("No patterns matched")
            end
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
      local bind_S_1240 = M.Control_Bind_bind((M.Control_Monad_Except_Trans_monadExceptT(dictMonad)).Bind1())
      return function(f_S_1241)
        return function(a_S_1242)
          return bind_S_1240(f_S_1241)(function(fPrime_S_1243)
            return bind_S_1240(a_S_1242)(function(aPrime_S_1244)
              return M.Control_Applicative_pure((M.Control_Monad_Except_Trans_monadExceptT(dictMonad)).Applicative0())(fPrime_S_1243(aPrime_S_1244))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return {
        map = function(f_S_1225)
          return function(v_S_1227)
            return M.Data_Functor_map(((dictMonad.Bind1()).Apply0()).Functor0())(M.Data_Functor_map({
              map = function(f_S_1234)
                return function(m_S_1235)
                  if "Data.Either∷Either.Left" == m_S_1235["$ctor"] then
                    return M.Data_Either_Left(m_S_1235.value0)
                  else
                    if "Data.Either∷Either.Right" == m_S_1235["$ctor"] then
                      return M.Data_Either_Right(f_S_1234(m_S_1235.value0))
                    else
                      return error("No patterns matched")
                    end
                  end
                end
              end
            })(f_S_1225))(v_S_1227)
          end
        end
      }
    end
  }
end
M.Control_Monad_Except_Trans_applicativeExceptT = function(dictMonad)
  return {
    pure = M.Control_Monad_Except_Trans_compose(M.Control_Monad_Except_Trans_ExceptT)(M.Control_Monad_Except_Trans_compose(M.Control_Applicative_pure(dictMonad.Applicative0()))(M.Data_Either_Right)),
    Apply0 = function()
      return M.Control_Monad_Except_Trans_applyExceptT(dictMonad)
    end
  }
end
M.Golden_LongExceptBind_Test_bind = M.Control_Bind_bind(M.Control_Monad_Except_Trans_bindExceptT(M.Data_Identity_monadIdentity))
M.Golden_LongExceptBind_Test_except = M.Control_Monad_Except_Trans_compose(M.Control_Monad_Except_Trans_ExceptT)(M.Control_Applicative_pure(M.Data_Identity_applicativeIdentity))
M.Golden_LongExceptBind_Test_add = M.Data_Semiring_foreign.intAdd
M.Golden_LongExceptBind_Test_go = (function()
  local _S_kont1247 = function(x1_S_1248)
    return function(x160_S_1249)
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x160_S_1249)(1))))(function( x161 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x161)(1))))(function( x162 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x162)(1))))(function( x163 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x163)(1))))(function( x164 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x164)(1))))(function( x165 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x165)(1))))(function( x166 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x166)(1))))(function( x167 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x167)(1))))(function( x168 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x168)(1))))(function( x169 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x169)(1))))(function( x170 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x170)(1))))(function( x171 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x171)(1))))(function( x172 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x172)(1))))(function( x173 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x173)(1))))(function( x174 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x174)(1))))(function( x175 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x175)(1))))(function( x176 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x176)(1))))(function( x177 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x177)(1))))(function( x178 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x178)(1))))(function( x179 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x179)(1))))(function( x180 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x180)(1))))(function( x181 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x181)(1))))(function( x182 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x182)(1))))(function( x183 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x183)(1))))(function( x184 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x184)(1))))(function( x185 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x185)(1))))(function( x186 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x186)(1))))(function( x187 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x187)(1))))(function( x188 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x188)(1))))(function( x189 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x189)(1))))(function( x190 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x190)(1))))(function( x191 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x191)(1))))(function( x192 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x192)(1))))(function( x193 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x193)(1))))(function( x194 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x194)(1))))(function( x195 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x195)(1))))(function( x196 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x196)(1))))(function( x197 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x197)(1))))(function( x198 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x198)(1))))(function( x199 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x199)(1))))(function( x200 )
                                                                                      return M.Control_Applicative_pure(M.Control_Monad_Except_Trans_applicativeExceptT(M.Data_Identity_monadIdentity))(M.Golden_LongExceptBind_Test_add(x1_S_1248)(x200))
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
  local _S_kont1250 = function(x1_S_1251)
    return function(x120_S_1252)
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x120_S_1252)(1))))(function( x121 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x121)(1))))(function( x122 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x122)(1))))(function( x123 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x123)(1))))(function( x124 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x124)(1))))(function( x125 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x125)(1))))(function( x126 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x126)(1))))(function( x127 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x127)(1))))(function( x128 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x128)(1))))(function( x129 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x129)(1))))(function( x130 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x130)(1))))(function( x131 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x131)(1))))(function( x132 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x132)(1))))(function( x133 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x133)(1))))(function( x134 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x134)(1))))(function( x135 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x135)(1))))(function( x136 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x136)(1))))(function( x137 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x137)(1))))(function( x138 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x138)(1))))(function( x139 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x139)(1))))(function( x140 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x140)(1))))(function( x141 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x141)(1))))(function( x142 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x142)(1))))(function( x143 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x143)(1))))(function( x144 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x144)(1))))(function( x145 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x145)(1))))(function( x146 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x146)(1))))(function( x147 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x147)(1))))(function( x148 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x148)(1))))(function( x149 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x149)(1))))(function( x150 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x150)(1))))(function( x151 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x151)(1))))(function( x152 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x152)(1))))(function( x153 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x153)(1))))(function( x154 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x154)(1))))(function( x155 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x155)(1))))(function( x156 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x156)(1))))(function( x157 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x157)(1))))(function( x158 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x158)(1))))(function( x159 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x159)(1))))(function( x160 )
                                                                                      return _S_kont1247(x1_S_1251)(x160)
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
  local _S_kont1253 = function(x1_S_1254)
    return function(x80_S_1255)
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x80_S_1255)(1))))(function( x81 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x81)(1))))(function( x82 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x82)(1))))(function( x83 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x83)(1))))(function( x84 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x84)(1))))(function( x85 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x85)(1))))(function( x86 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x86)(1))))(function( x87 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x87)(1))))(function( x88 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x88)(1))))(function( x89 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x89)(1))))(function( x90 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x90)(1))))(function( x91 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x91)(1))))(function( x92 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x92)(1))))(function( x93 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x93)(1))))(function( x94 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x94)(1))))(function( x95 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x95)(1))))(function( x96 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x96)(1))))(function( x97 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x97)(1))))(function( x98 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x98)(1))))(function( x99 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x99)(1))))(function( x100 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x100)(1))))(function( x101 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x101)(1))))(function( x102 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x102)(1))))(function( x103 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x103)(1))))(function( x104 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x104)(1))))(function( x105 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x105)(1))))(function( x106 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x106)(1))))(function( x107 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x107)(1))))(function( x108 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x108)(1))))(function( x109 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x109)(1))))(function( x110 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x110)(1))))(function( x111 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x111)(1))))(function( x112 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x112)(1))))(function( x113 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x113)(1))))(function( x114 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x114)(1))))(function( x115 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x115)(1))))(function( x116 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x116)(1))))(function( x117 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x117)(1))))(function( x118 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x118)(1))))(function( x119 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x119)(1))))(function( x120 )
                                                                                      return _S_kont1250(x1_S_1254)(x120)
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
  local _S_kont1256 = function(x1_S_1257)
    return function(x40_S_1258)
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x40_S_1258)(1))))(function( x41 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x41)(1))))(function( x42 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x42)(1))))(function( x43 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x43)(1))))(function( x44 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x44)(1))))(function( x45 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x45)(1))))(function( x46 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x46)(1))))(function( x47 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x47)(1))))(function( x48 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x48)(1))))(function( x49 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x49)(1))))(function( x50 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x50)(1))))(function( x51 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x51)(1))))(function( x52 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x52)(1))))(function( x53 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x53)(1))))(function( x54 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x54)(1))))(function( x55 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x55)(1))))(function( x56 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x56)(1))))(function( x57 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x57)(1))))(function( x58 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x58)(1))))(function( x59 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x59)(1))))(function( x60 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x60)(1))))(function( x61 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x61)(1))))(function( x62 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x62)(1))))(function( x63 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x63)(1))))(function( x64 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x64)(1))))(function( x65 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x65)(1))))(function( x66 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x66)(1))))(function( x67 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x67)(1))))(function( x68 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x68)(1))))(function( x69 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x69)(1))))(function( x70 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x70)(1))))(function( x71 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x71)(1))))(function( x72 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x72)(1))))(function( x73 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x73)(1))))(function( x74 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x74)(1))))(function( x75 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x75)(1))))(function( x76 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x76)(1))))(function( x77 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x77)(1))))(function( x78 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x78)(1))))(function( x79 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x79)(1))))(function( x80 )
                                                                                      return _S_kont1253(x1_S_1257)(x80)
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
    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x1)(1))))(function( x2 )
      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x2)(1))))(function( x3 )
        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x3)(1))))(function( x4 )
          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x4)(1))))(function( x5 )
            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x5)(1))))(function( x6 )
              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x6)(1))))(function( x7 )
                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x7)(1))))(function( x8 )
                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x8)(1))))(function( x9 )
                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x9)(1))))(function( x10 )
                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x10)(1))))(function( x11 )
                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x11)(1))))(function( x12 )
                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x12)(1))))(function( x13 )
                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x13)(1))))(function( x14 )
                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x14)(1))))(function( x15 )
                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x15)(1))))(function( x16 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x16)(1))))(function( x17 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x17)(1))))(function( x18 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x18)(1))))(function( x19 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x19)(1))))(function( x20 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x20)(1))))(function( x21 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x21)(1))))(function( x22 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x22)(1))))(function( x23 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x23)(1))))(function( x24 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x24)(1))))(function( x25 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x25)(1))))(function( x26 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x26)(1))))(function( x27 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x27)(1))))(function( x28 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x28)(1))))(function( x29 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x29)(1))))(function( x30 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x30)(1))))(function( x31 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x31)(1))))(function( x32 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x32)(1))))(function( x33 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x33)(1))))(function( x34 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x34)(1))))(function( x35 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x35)(1))))(function( x36 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x36)(1))))(function( x37 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x37)(1))))(function( x38 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x38)(1))))(function( x39 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Golden_LongExceptBind_Test_except(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add(x39)(1))))(function( x40 )
                                                                                  return _S_kont1256(x1)(x40)
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
M.Golden_LongExceptBind_Test_compute = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)(function(x) return x end)(function( v_S_50 )
  return v_S_50
end)(M.Golden_LongExceptBind_Test_go)
return (function(s) return function() print(s) end end)(M.Data_Show_show({
  show = function(v_S_1238)
    if "Data.Either∷Either.Left" == v_S_1238["$ctor"] then
      return M.Data_Either_append("(Left ")(M.Data_Either_append(M.Data_Show_show({
        show = M.Data_Show_foreign.showStringImpl
      })(v_S_1238.value0))(")"))
    else
      if "Data.Either∷Either.Right" == v_S_1238["$ctor"] then
        return M.Data_Either_append("(Right ")(M.Data_Either_append(M.Data_Show_show({
          show = M.Data_Show_foreign.showIntImpl
        })(v_S_1238.value0))(")"))
      else
        return error("No patterns matched")
      end
    end
  end
})(M.Golden_LongExceptBind_Test_compute))()
