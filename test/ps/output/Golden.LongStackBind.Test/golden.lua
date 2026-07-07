local M = {}
M.Data_Unit_foreign = { unit = {} }
M.Data_Semigroup_foreign = {
  concatString = function(s1) return function(s2) return s1 .. s2 end end
}
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
M.Data_Either_Left = function(value0)
  return { ["$ctor"] = "Data.Either∷Either.Left", value0 = value0 }
end
M.Data_Either_Right = function(value0)
  return { ["$ctor"] = "Data.Either∷Either.Right", value0 = value0 }
end
M.Data_Tuple_Tuple = function(value0)
  return function(value1) return { value0 = value0, value1 = value1 } end
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
      return function(v_S_542)
        return M.Data_Functor_map(dictFunctor)(M.Data_Functor_map({
          map = function(f_S_551)
            return function(m_S_552)
              if "Data.Either∷Either.Left" == m_S_552["$ctor"] then
                return M.Data_Either_Left(m_S_552.value0)
              else
                if "Data.Either∷Either.Right" == m_S_552["$ctor"] then
                  return M.Data_Either_Right(f_S_551(m_S_552.value0))
                else
                  return error("No patterns matched")
                end
              end
            end
          end
        })(f))(v_S_542)
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
        return M.Control_Bind_bind(dictMonad.Bind1())(v)(function(v2_S_550)
          if "Data.Either∷Either.Left" == v2_S_550["$ctor"] then
            return M.Control_Monad_Except_Trans_compose(M.Control_Applicative_pure(dictMonad.Applicative0()))(M.Data_Either_Left)(v2_S_550.value0)
          else
            if "Data.Either∷Either.Right" == v2_S_550["$ctor"] then
              return k(v2_S_550.value0)
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
    pure = M.Control_Monad_Except_Trans_compose(function(x_S_543)
      return x_S_543
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
        map = function(f_S_537)
          return function(v_S_538)
            return function(s_S_539)
              return M.Data_Functor_map(((dictMonad.Bind1()).Apply0()).Functor0())(function( v1_S_540 )
                return M.Data_Tuple_Tuple(f_S_537(v1_S_540.value0))(v1_S_540.value1)
              end)(v_S_538(s_S_539))
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
      pure = function(x_S_546) return x_S_546 end,
      Apply0 = function() return M.Data_Identity_applyIdentity end
    }
  end,
  Bind1 = function()
    return {
      bind = function(v_S_128_S_544)
        return function(f_S_129_S_545) return f_S_129_S_545(v_S_128_S_544) end
      end,
      Apply0 = function() return M.Data_Identity_applyIdentity end
    }
  end
})
M.Golden_LongStackBind_Test_bindStateT = M.Control_Monad_State_Trans_bindStateT(M.Golden_LongStackBind_Test_monadExceptT)
M.Golden_LongStackBind_Test_bind = M.Control_Bind_bind(M.Golden_LongStackBind_Test_bindStateT)
M.Golden_LongStackBind_Test_monadStateStateT = {
  state = function(f_S_21)
    return M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)(M.Control_Applicative_pure(M.Golden_LongStackBind_Test_monadExceptT.Applicative0()))(f_S_21)
  end,
  Monad0 = function()
    return M.Control_Monad_State_Trans_monadStateT(M.Golden_LongStackBind_Test_monadExceptT)
  end
}
M.Golden_LongStackBind_Test_get = M.Control_Monad_State_Class_state(M.Golden_LongStackBind_Test_monadStateStateT)(function( s_S_106 )
  return M.Data_Tuple_Tuple(s_S_106)(s_S_106)
end)
M.Golden_LongStackBind_Test_discard = M.Control_Bind_bind(M.Golden_LongStackBind_Test_bindStateT)
M.Golden_LongStackBind_Test_put = function(s_S_109)
  return M.Control_Monad_State_Class_state(M.Golden_LongStackBind_Test_monadStateStateT)(function(  )
    return M.Data_Tuple_Tuple(M.Data_Unit_foreign.unit)(s_S_109)
  end)
end
M.Golden_LongStackBind_Test_go = (function()
  local _S_kont558 = function(x1_S_559)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x141 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x141)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x142 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x142)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x143 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x143)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x144 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x144)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x145 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x145)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x146 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x146)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x147 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x147)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x148 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x148)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x149 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x149)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x150 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x150)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( final )
                                              return M.Control_Applicative_pure(M.Control_Monad_State_Trans_applicativeStateT(M.Golden_LongStackBind_Test_monadExceptT))(M.Data_Semiring_foreign.intAdd(x1_S_559)(final))
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont560 = function(x1_S_561)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x121 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x121)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x122 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x122)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x123 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x123)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x124 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x124)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x125 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x125)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x126 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x126)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x127 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x127)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x128 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x128)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x129 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x129)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x130 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x130)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x131 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x131)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x132 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x132)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x133 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x133)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x134 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x134)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x135 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x135)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x136 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x136)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x137 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x137)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x138 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x138)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x139 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x139)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x140 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x140)(1)))(function(  )
                                                                                    return _S_kont558(x1_S_561)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont562 = function(x1_S_563)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x101 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x101)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x102 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x102)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x103 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x103)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x104 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x104)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x105 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x105)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x106 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x106)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x107 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x107)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x108 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x108)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x109 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x109)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x110 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x110)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x111 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x111)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x112 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x112)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x113 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x113)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x114 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x114)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x115 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x115)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x116 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x116)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x117 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x117)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x118 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x118)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x119 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x119)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x120 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x120)(1)))(function(  )
                                                                                    return _S_kont560(x1_S_563)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont564 = function(x1_S_565)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x81 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x81)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x82 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x82)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x83 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x83)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x84 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x84)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x85 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x85)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x86 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x86)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x87 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x87)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x88 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x88)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x89 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x89)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x90 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x90)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x91 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x91)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x92 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x92)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x93 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x93)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x94 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x94)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x95 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x95)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x96 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x96)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x97 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x97)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x98 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x98)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x99 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x99)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x100 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x100)(1)))(function(  )
                                                                                    return _S_kont562(x1_S_565)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont566 = function(x1_S_567)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x61 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x61)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x62 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x62)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x63 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x63)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x64 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x64)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x65 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x65)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x66 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x66)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x67 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x67)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x68 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x68)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x69 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x69)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x70 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x70)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x71 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x71)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x72 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x72)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x73 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x73)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x74 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x74)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x75 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x75)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x76 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x76)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x77 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x77)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x78 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x78)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x79 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x79)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x80 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x80)(1)))(function(  )
                                                                                    return _S_kont564(x1_S_567)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont568 = function(x1_S_569)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x41 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x41)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x42 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x42)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x43 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x43)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x44 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x44)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x45 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x45)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x46 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x46)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x47 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x47)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x48 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x48)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x49 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x49)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x50 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x50)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x51 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x51)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x52 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x52)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x53 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x53)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x54 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x54)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x55 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x55)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x56 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x56)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x57 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x57)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x58 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x58)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x59 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x59)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x60 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x60)(1)))(function(  )
                                                                                    return _S_kont566(x1_S_569)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont570 = function(x1_S_571)
    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x21 )
      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x21)(1)))(function(  )
        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x22 )
          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x22)(1)))(function(  )
            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x23 )
              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x23)(1)))(function(  )
                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x24 )
                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x24)(1)))(function(  )
                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x25 )
                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x25)(1)))(function(  )
                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x26 )
                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x26)(1)))(function(  )
                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x27 )
                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x27)(1)))(function(  )
                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x28 )
                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x28)(1)))(function(  )
                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x29 )
                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x29)(1)))(function(  )
                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x30 )
                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x30)(1)))(function(  )
                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x31 )
                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x31)(1)))(function(  )
                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x32 )
                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x32)(1)))(function(  )
                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x33 )
                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x33)(1)))(function(  )
                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x34 )
                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x34)(1)))(function(  )
                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x35 )
                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x35)(1)))(function(  )
                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x36 )
                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x36)(1)))(function(  )
                                                                    return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x37 )
                                                                      return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x37)(1)))(function(  )
                                                                        return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x38 )
                                                                          return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x38)(1)))(function(  )
                                                                            return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x39 )
                                                                              return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x39)(1)))(function(  )
                                                                                return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x40 )
                                                                                  return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x40)(1)))(function(  )
                                                                                    return _S_kont568(x1_S_571)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x1)(1)))(function(  )
      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x2 )
        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x2)(1)))(function(  )
          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x3 )
            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x3)(1)))(function(  )
              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x4 )
                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x4)(1)))(function(  )
                  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x5 )
                    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x5)(1)))(function(  )
                      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x6 )
                        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x6)(1)))(function(  )
                          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x7 )
                            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x7)(1)))(function(  )
                              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x8 )
                                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x8)(1)))(function(  )
                                  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x9 )
                                    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x9)(1)))(function(  )
                                      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x10 )
                                        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x10)(1)))(function(  )
                                          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x11 )
                                            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x11)(1)))(function(  )
                                              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x12 )
                                                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x12)(1)))(function(  )
                                                  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x13 )
                                                    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x13)(1)))(function(  )
                                                      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x14 )
                                                        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x14)(1)))(function(  )
                                                          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x15 )
                                                            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x15)(1)))(function(  )
                                                              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x16 )
                                                                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x16)(1)))(function(  )
                                                                  return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x17 )
                                                                    return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x17)(1)))(function(  )
                                                                      return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x18 )
                                                                        return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x18)(1)))(function(  )
                                                                          return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x19 )
                                                                            return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x19)(1)))(function(  )
                                                                              return M.Golden_LongStackBind_Test_bind(M.Golden_LongStackBind_Test_get)(function( x20 )
                                                                                return M.Golden_LongStackBind_Test_discard(M.Golden_LongStackBind_Test_put(M.Data_Semiring_foreign.intAdd(x20)(1)))(function(  )
                                                                                  return _S_kont570(x1)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
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
M.Golden_LongStackBind_Test_compute = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)(M.Unsafe_Coerce_foreign.unsafeCoerce)(function( v_S_82 )
  return v_S_82
end)(M.Data_Functor_map(M.Control_Monad_Except_Trans_functorExceptT(M.Data_Identity_functorIdentity))(function( v_S_547 )
  return v_S_547.value0
end)(M.Golden_LongStackBind_Test_go(0)))
return M.Effect_Console_foreign.log(M.Data_Show_show({
  show = function(v_S_228_S_557)
    if "Data.Either∷Either.Left" == v_S_228_S_557["$ctor"] then
      return M.Data_Semigroup_foreign.concatString("(Left ")(M.Data_Semigroup_foreign.concatString(M.Data_Show_show({
        show = M.Data_Show_foreign.showStringImpl
      })(v_S_228_S_557.value0))(")"))
    else
      if "Data.Either∷Either.Right" == v_S_228_S_557["$ctor"] then
        return M.Data_Semigroup_foreign.concatString("(Right ")(M.Data_Semigroup_foreign.concatString(M.Data_Show_show({
          show = M.Data_Show_foreign.showIntImpl
        })(v_S_228_S_557.value0))(")"))
      else
        return error("No patterns matched")
      end
    end
  end
})(M.Golden_LongStackBind_Test_compute))()
