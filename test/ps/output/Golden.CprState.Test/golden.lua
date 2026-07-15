local Data_Unit_foreign = { unit = {} }
local Data_Unit_unit = Data_Unit_foreign.unit
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Tuple_Tuple_S_w = function(value0, value1)
  return { value0, value1 }
end
local Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function()
    return {
      map = function(f_S_521)
        return function(m_S_522) return f_S_521(m_S_522) end
      end
    }
  end
}
local Data_Identity_monadIdentity = {
  Applicative0 = function()
    return {
      pure = function(x_S_523) return x_S_523 end,
      Apply0 = function() return Data_Identity_applyIdentity end
    }
  end,
  Bind1 = function()
    return {
      bind = function(v_S_78)
        return function(f_S_79) return f_S_79(v_S_78) end
      end,
      Apply0 = function() return Data_Identity_applyIdentity end
    }
  end
}
local Control_Monad_State_Trans_bindStateT
local Control_Monad_State_Trans_applicativeStateT
local Control_Monad_State_Trans_monadStateT = function(dictMonad)
  return {
    Applicative0 = function()
      return Control_Monad_State_Trans_applicativeStateT(dictMonad)
    end,
    Bind1 = function()
      return Control_Monad_State_Trans_bindStateT(dictMonad)
    end
  }
end
local Control_Monad_State_Trans_applyStateT
Control_Monad_State_Trans_bindStateT = function(dictMonad)
  return {
    bind = function(v)
      return function(f)
        return function(s)
          return (dictMonad.Bind1()).bind(v(s))(function(v1)
            return f(v1[1])(v1[2])
          end)
        end
      end
    end,
    Apply0 = function()
      return Control_Monad_State_Trans_applyStateT(dictMonad)
    end
  }
end
Control_Monad_State_Trans_applyStateT = function(dictMonad)
  return {
    apply = (function()
      local dictMonad_S_524 = Control_Monad_State_Trans_monadStateT(dictMonad)
      local bind_S_525 = (dictMonad_S_524.Bind1()).bind
      return function(f_S_526)
        return function(a_S_527)
          return bind_S_525(f_S_526)(function(fPrime_S_528)
            return bind_S_525(a_S_527)(function(aPrime_S_529)
              return (dictMonad_S_524.Applicative0()).pure(fPrime_S_528(aPrime_S_529))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return {
        map = function(f_S_517)
          return function(v_S_518)
            return function(s_S_519)
              return (((dictMonad.Bind1()).Apply0()).Functor0()).map(function( v1_S_520 )
                return Data_Tuple_Tuple_S_w(f_S_517(v1_S_520[1]), v1_S_520[2])
              end)(v_S_518(s_S_519))
            end
          end
        end
      }
    end
  }
end
Control_Monad_State_Trans_applicativeStateT = function(dictMonad)
  return {
    pure = function(a)
      return function(s)
        return (dictMonad.Applicative0()).pure(Data_Tuple_Tuple_S_w(a, s))
      end
    end,
    Apply0 = function()
      return Control_Monad_State_Trans_applyStateT(dictMonad)
    end
  }
end
local Golden_CprState_Test_bindStateT = Control_Monad_State_Trans_bindStateT(Data_Identity_monadIdentity)
local Golden_CprState_Test_bind = Golden_CprState_Test_bindStateT.bind
local Golden_CprState_Test_get = function(x_S_612)
  return Data_Tuple_Tuple_S_w(x_S_612, x_S_612)
end
local Golden_CprState_Test_discard = Golden_CprState_Test_bindStateT.bind
local Golden_CprState_Test_add_S_w = function(x_S_534, y_S_535)
  return x_S_534 + y_S_535
end
local Golden_CprState_Test_go = Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( x1 )
  return Golden_CprState_Test_discard(function()
    return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x1, 1))
  end)(function()
    return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function(x2)
      return Golden_CprState_Test_discard(function()
        return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x2, 1))
      end)(function()
        return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function(x3)
          return Golden_CprState_Test_discard(function()
            return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x3, 1))
          end)(function()
            return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( x4 )
              return Golden_CprState_Test_discard(function()
                return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x4, 1))
              end)(function()
                return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( x5 )
                  return Golden_CprState_Test_discard(function()
                    return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x5, 1))
                  end)(function()
                    return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( x6 )
                      return Golden_CprState_Test_discard(function()
                        return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x6, 1))
                      end)(function()
                        return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( x7 )
                          return Golden_CprState_Test_discard(function()
                            return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x7, 1))
                          end)(function()
                            return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( x8 )
                              return Golden_CprState_Test_discard(function()
                                return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x8, 1))
                              end)(function()
                                return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( x9 )
                                  return Golden_CprState_Test_discard(function()
                                    return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x9, 1))
                                  end)(function()
                                    return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( x10 )
                                      return Golden_CprState_Test_discard(function(  )
                                        return Data_Tuple_Tuple_S_w(Data_Unit_unit, Golden_CprState_Test_add_S_w(x10, 1))
                                      end)(function()
                                        return Golden_CprState_Test_bind(Golden_CprState_Test_get)(function( final )
                                          return (Control_Monad_State_Trans_applicativeStateT(Data_Identity_monadIdentity)).pure(Golden_CprState_Test_add_S_w(Golden_CprState_Test_add_S_w(x1, x5), final))
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end)
return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl((Golden_CprState_Test_go(0))[1]))()
