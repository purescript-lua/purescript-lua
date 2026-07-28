local Data_Unit_foreign = { unit = {} }
local Data_Unit_unit = Data_Unit_foreign.unit
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function()
    return {
      map = function(f_S_0) return function(m_S_0) return f_S_0(m_S_0) end end
    }
  end
}
local Data_Identity_monadIdentity = {
  Applicative0 = function()
    return {
      pure = function(x_S_0) return x_S_0 end,
      Apply0 = function() return Data_Identity_applyIdentity end
    }
  end,
  Bind1 = function()
    return {
      bind = function(v_S_0) return function(f_S_1) return f_S_1(v_S_0) end end,
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
      local dictMonad_S_0 = Control_Monad_State_Trans_monadStateT(dictMonad)
      local bind_S_0 = (dictMonad_S_0.Bind1()).bind
      return function(f_S_2)
        return function(a_S_0)
          return bind_S_0(f_S_2)(function(fPrime_S_0)
            return bind_S_0(a_S_0)(function(aPrime_S_0)
              return (dictMonad_S_0.Applicative0()).pure(fPrime_S_0(aPrime_S_0))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return {
        map = function(f_S_3)
          return function(v_S_1)
            return function(s_S_0)
              return (((dictMonad.Bind1()).Apply0()).Functor0()).map(function( v1_S_0 )
                return { f_S_3(v1_S_0[1]), v1_S_0[2] }
              end)(v_S_1(s_S_0))
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
      return function(s) return (dictMonad.Applicative0()).pure({ a, s }) end
    end,
    Apply0 = function()
      return Control_Monad_State_Trans_applyStateT(dictMonad)
    end
  }
end
local Golden_CprState_Test_bindStateT = Control_Monad_State_Trans_bindStateT(Data_Identity_monadIdentity)
local Golden_CprState_Test_get = function(x_S_1) return { x_S_1, x_S_1 } end
local Golden_CprState_Test_go = Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x1 )
  return Golden_CprState_Test_bindStateT.bind(function()
    return { Data_Unit_unit, x1 + 1 }
  end)(function()
    return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x2 )
      return Golden_CprState_Test_bindStateT.bind(function()
        return { Data_Unit_unit, x2 + 1 }
      end)(function()
        return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x3 )
          return Golden_CprState_Test_bindStateT.bind(function()
            return { Data_Unit_unit, x3 + 1 }
          end)(function()
            return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x4 )
              return Golden_CprState_Test_bindStateT.bind(function()
                return { Data_Unit_unit, x4 + 1 }
              end)(function()
                return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x5 )
                  return Golden_CprState_Test_bindStateT.bind(function()
                    return { Data_Unit_unit, x5 + 1 }
                  end)(function()
                    return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x6 )
                      return Golden_CprState_Test_bindStateT.bind(function()
                        return { Data_Unit_unit, x6 + 1 }
                      end)(function()
                        return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x7 )
                          return Golden_CprState_Test_bindStateT.bind(function()
                            return { Data_Unit_unit, x7 + 1 }
                          end)(function()
                            return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x8 )
                              return Golden_CprState_Test_bindStateT.bind(function(  )
                                return { Data_Unit_unit, x8 + 1 }
                              end)(function()
                                return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x9 )
                                  return Golden_CprState_Test_bindStateT.bind(function(  )
                                    return { Data_Unit_unit, x9 + 1 }
                                  end)(function()
                                    return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( x10 )
                                      return Golden_CprState_Test_bindStateT.bind(function(  )
                                        return { Data_Unit_unit, x10 + 1 }
                                      end)(function()
                                        return Golden_CprState_Test_bindStateT.bind(Golden_CprState_Test_get)(function( final )
                                          return (Control_Monad_State_Trans_applicativeStateT(Data_Identity_monadIdentity)).pure(x1 + x5 + final)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
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
