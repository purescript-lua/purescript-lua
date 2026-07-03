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
M.Control_Monad_ap = function(dictMonad)
  local bind = M.Control_Bind_bind(dictMonad.Bind1())
  return function(f)
    return function(a)
      return bind(f)(function(fPrime)
        return bind(a)(function(aPrime)
          return M.Control_Applicative_pure(dictMonad.Applicative0())(fPrime(aPrime))
        end)
      end)
    end
  end
end
M.Data_Either_append = function(s1) return function(s2) return s1 .. s2 end end
M.Data_Either_Left = function(value0)
  return { ["$ctor"] = "Data.Either∷Either.Left", value0 = value0 }
end
M.Data_Either_Right = function(value0)
  return { ["$ctor"] = "Data.Either∷Either.Right", value0 = value0 }
end
M.Data_Tuple_Tuple = function(value0)
  return function(value1)
    return {
      ["$ctor"] = "Data.Tuple∷Tuple.Tuple",
      value0 = value0,
      value1 = value1
    }
  end
end
M.Data_Identity_functorIdentity = {
  map = function(f) return function(m) return f(m) end end
}
M.Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function() return M.Data_Identity_functorIdentity end
}
M.Control_Monad_State_Class_state = function(dict) return dict.state end
M.Control_Monad_Except_Trans_compose = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)
M.Control_Monad_Except_Trans_functorExceptT = function(dictFunctor)
  return {
    map = function(f)
      return function(v_S_2897)
        return M.Data_Functor_map(dictFunctor)(M.Data_Functor_map({
          map = function(f_S_2906)
            return function(m_S_2907)
              if "Data.Either∷Either.Left" == m_S_2907["$ctor"] then
                return M.Data_Either_Left(m_S_2907.value0)
              else
                if "Data.Either∷Either.Right" == m_S_2907["$ctor"] then
                  return M.Data_Either_Right(f_S_2906(m_S_2907.value0))
                else
                  return error("No patterns matched")
                end
              end
            end
          end
        })(f))(v_S_2897)
      end
    end
  }
end
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
        return M.Control_Bind_bind(dictMonad.Bind1())(v)(function(v2_S_2905)
          if "Data.Either∷Either.Left" == v2_S_2905["$ctor"] then
            return M.Control_Monad_Except_Trans_compose(M.Control_Applicative_pure(dictMonad.Applicative0()))(M.Data_Either_Left)(v2_S_2905.value0)
          else
            if "Data.Either∷Either.Right" == v2_S_2905["$ctor"] then
              return k(v2_S_2905.value0)
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
    apply = M.Control_Monad_ap(M.Control_Monad_Except_Trans_monadExceptT(dictMonad)),
    Functor0 = function()
      return M.Control_Monad_Except_Trans_functorExceptT(((dictMonad.Bind1()).Apply0()).Functor0())
    end
  }
end
M.Control_Monad_Except_Trans_applicativeExceptT = function(dictMonad)
  return {
    pure = M.Control_Monad_Except_Trans_compose(function(x_S_2898)
      return x_S_2898
    end)(M.Control_Monad_Except_Trans_compose(M.Control_Applicative_pure(dictMonad.Applicative0()))(M.Data_Either_Right)),
    Apply0 = function()
      return M.Control_Monad_Except_Trans_applyExceptT(dictMonad)
    end
  }
end
M.Control_Monad_State_Trans_monadStateT = function(dictMonad)
  return {
    Applicative0 = function()
      return M.Control_Monad_State_Trans_applicativeStateT(dictMonad)
    end,
    Bind1 = function()
      return M.Control_Monad_State_Trans_bindStateT(dictMonad)
    end
  }
end
M.Control_Monad_State_Trans_bindStateT = function(dictMonad)
  return {
    bind = function(v)
      return function(f)
        return function(s)
          return M.Control_Bind_bind(dictMonad.Bind1())(v(s))(function(v1)
            return f(v1.value0)(v1.value1)
          end)
        end
      end
    end,
    Apply0 = function()
      return M.Control_Monad_State_Trans_applyStateT(dictMonad)
    end
  }
end
M.Control_Monad_State_Trans_applyStateT = function(dictMonad)
  return {
    apply = M.Control_Monad_ap(M.Control_Monad_State_Trans_monadStateT(dictMonad)),
    Functor0 = function()
      return {
        map = function(f_S_2892)
          return function(v_S_2893)
            return function(s_S_2894)
              return M.Data_Functor_map(((dictMonad.Bind1()).Apply0()).Functor0())(function( v1_S_2895 )
                return M.Data_Tuple_Tuple(f_S_2892(v1_S_2895.value0))(v1_S_2895.value1)
              end)(v_S_2893(s_S_2894))
            end
          end
        end
      }
    end
  }
end
M.Control_Monad_State_Trans_applicativeStateT = function(dictMonad)
  return {
    pure = function(a)
      return function(s)
        return M.Control_Applicative_pure(dictMonad.Applicative0())(M.Data_Tuple_Tuple(a)(s))
      end
    end,
    Apply0 = function()
      return M.Control_Monad_State_Trans_applyStateT(dictMonad)
    end
  }
end
M.Golden_LongStackBind_Test_monadExceptT = M.Control_Monad_Except_Trans_monadExceptT({
  Applicative0 = function()
    return {
      pure = function(x_S_2901) return x_S_2901 end,
      Apply0 = function() return M.Data_Identity_applyIdentity end
    }
  end,
  Bind1 = function()
    return {
      bind = function(v_S_870_S_2899)
        return function(f_S_871_S_2900)
          return f_S_871_S_2900(v_S_870_S_2899)
        end
      end,
      Apply0 = function() return M.Data_Identity_applyIdentity end
    }
  end
})
M.Golden_LongStackBind_Test_bindStateT = M.Control_Monad_State_Trans_bindStateT(M.Golden_LongStackBind_Test_monadExceptT)
M.Golden_LongStackBind_Test_bind = M.Control_Bind_bind(M.Golden_LongStackBind_Test_bindStateT)
M.Golden_LongStackBind_Test_monadStateStateT = {
  state = function(f_S_231)
    return M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)(M.Control_Applicative_pure(M.Golden_LongStackBind_Test_monadExceptT.Applicative0()))(f_S_231)
  end,
  Monad0 = function()
    return M.Control_Monad_State_Trans_monadStateT(M.Golden_LongStackBind_Test_monadExceptT)
  end
}
M.Golden_LongStackBind_Test_get = M.Control_Monad_State_Class_state(M.Golden_LongStackBind_Test_monadStateStateT)(function( s_S_846 )
  return M.Data_Tuple_Tuple(s_S_846)(s_S_846)
end)
M.Golden_LongStackBind_Test_discard = (function(dictBind_S_2911)
  return M.Control_Bind_bind(dictBind_S_2911)
end)(M.Golden_LongStackBind_Test_bindStateT)
M.Golden_LongStackBind_Test_put = function(s_S_849)
  return M.Control_Monad_State_Class_state(M.Golden_LongStackBind_Test_monadStateStateT)(function(  )
    return M.Data_Tuple_Tuple({})(s_S_849)
  end)
end
M.Golden_LongStackBind_Test_add = M.Data_Semiring_foreign.intAdd
M.Golden_LongStackBind_Test_go = (function()
  local _S_kont2915 = function(x1_S_2916)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x141 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x141)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x142 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x142)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x143 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x143)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x144 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x144)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x145 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x145)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x146 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x146)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x147 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x147)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x148 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x148)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x149 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x149)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x150 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x150)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( final )
                                              return M.Control_Applicative_pure(M.Control_Monad_State_Trans_applicativeStateT(M.Golden_LongStackBind_Test_monadExceptT))(M.Golden_LongStackBind_Test_add(x1_S_2916)(final))
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont2917 = function(x1_S_2918)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x121 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x121)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x122 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x122)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x123 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x123)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x124 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x124)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x125 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x125)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x126 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x126)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x127 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x127)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x128 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x128)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x129 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x129)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x130 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x130)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x131 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x131)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x132 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x132)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x133 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x133)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x134 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x134)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x135 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x135)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x136 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x136)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x137 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x137)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x138 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x138)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x139 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x139)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x140 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x140)(1)))(function(  )
                                                                                    return _S_kont2915(x1_S_2918)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont2919 = function(x1_S_2920)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x101 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x101)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x102 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x102)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x103 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x103)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x104 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x104)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x105 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x105)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x106 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x106)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x107 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x107)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x108 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x108)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x109 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x109)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x110 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x110)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x111 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x111)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x112 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x112)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x113 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x113)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x114 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x114)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x115 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x115)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x116 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x116)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x117 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x117)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x118 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x118)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x119 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x119)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x120 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x120)(1)))(function(  )
                                                                                    return _S_kont2917(x1_S_2920)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont2921 = function(x1_S_2922)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x81 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x81)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x82 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x82)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x83 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x83)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x84 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x84)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x85 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x85)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x86 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x86)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x87 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x87)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x88 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x88)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x89 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x89)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x90 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x90)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x91 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x91)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x92 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x92)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x93 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x93)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x94 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x94)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x95 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x95)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x96 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x96)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x97 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x97)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x98 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x98)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x99 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x99)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x100 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x100)(1)))(function(  )
                                                                                    return _S_kont2919(x1_S_2922)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont2923 = function(x1_S_2924)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x61 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x61)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x62 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x62)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x63 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x63)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x64 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x64)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x65 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x65)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x66 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x66)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x67 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x67)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x68 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x68)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x69 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x69)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x70 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x70)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x71 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x71)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x72 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x72)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x73 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x73)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x74 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x74)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x75 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x75)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x76 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x76)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x77 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x77)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x78 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x78)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x79 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x79)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x80 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x80)(1)))(function(  )
                                                                                    return _S_kont2921(x1_S_2924)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont2925 = function(x1_S_2926)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x41 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x41)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x42 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x42)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x43 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x43)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x44 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x44)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x45 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x45)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x46 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x46)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x47 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x47)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x48 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x48)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x49 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x49)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x50 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x50)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x51 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x51)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x52 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x52)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x53 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x53)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x54 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x54)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x55 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x55)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x56 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x56)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x57 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x57)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x58 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x58)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x59 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x59)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x60 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x60)(1)))(function(  )
                                                                                    return _S_kont2923(x1_S_2926)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont2927 = function(x1_S_2928)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x21 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x21)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x22 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x22)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x23 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x23)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x24 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x24)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x25 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x25)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x26 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x26)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x27 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x27)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x28 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x28)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x29 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x29)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x30 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x30)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x31 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x31)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x32 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x32)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x33 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x33)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x34 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x34)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x35 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x35)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x36 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x36)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x37 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x37)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x38 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x38)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x39 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x39)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x40 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x40)(1)))(function(  )
                                                                                    return _S_kont2925(x1_S_2928)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x1 )
    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x1)(1)))(function(  )
      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x2 )
        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x2)(1)))(function(  )
          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x3 )
            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x3)(1)))(function(  )
              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x4 )
                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x4)(1)))(function(  )
                  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x5 )
                    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x5)(1)))(function(  )
                      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x6 )
                        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x6)(1)))(function(  )
                          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x7 )
                            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x7)(1)))(function(  )
                              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x8 )
                                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x8)(1)))(function(  )
                                  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x9 )
                                    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x9)(1)))(function(  )
                                      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x10 )
                                        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x10)(1)))(function(  )
                                          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x11 )
                                            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x11)(1)))(function(  )
                                              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x12 )
                                                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x12)(1)))(function(  )
                                                  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x13 )
                                                    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x13)(1)))(function(  )
                                                      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x14 )
                                                        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x14)(1)))(function(  )
                                                          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x15 )
                                                            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x15)(1)))(function(  )
                                                              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x16 )
                                                                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x16)(1)))(function(  )
                                                                  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x17 )
                                                                    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x17)(1)))(function(  )
                                                                      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x18 )
                                                                        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x18)(1)))(function(  )
                                                                          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x19 )
                                                                            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x19)(1)))(function(  )
                                                                              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x20 )
                                                                                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Golden_LongStackBind_Test_add(x20)(1)))(function(  )
                                                                                  return _S_kont2927(x1)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
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
M.Golden_LongStackBind_Test_compute = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)(function(x) return x end)(function( v_S_822 )
  return v_S_822
end)(M.Data_Functor_map(M.Control_Monad_Except_Trans_functorExceptT(M.Data_Identity_functorIdentity))(function( v_S_2902 )
  return v_S_2902.value0
end)(M.Golden_LongStackBind_Test_go(0)))
return (function(s) return function() print(s) end end)(M.Data_Show_show({
  show = function(v_S_2910)
    if "Data.Either∷Either.Left" == v_S_2910["$ctor"] then
      return M.Data_Either_append("(Left ")(M.Data_Either_append(M.Data_Show_show({
        show = M.Data_Show_foreign.showStringImpl
      })(v_S_2910.value0))(")"))
    else
      if "Data.Either∷Either.Right" == v_S_2910["$ctor"] then
        return M.Data_Either_append("(Right ")(M.Data_Either_append(M.Data_Show_show({
          show = M.Data_Show_foreign.showIntImpl
        })(v_S_2910.value0))(")"))
      else
        return error("No patterns matched")
      end
    end
  end
})(M.Golden_LongStackBind_Test_compute))()
