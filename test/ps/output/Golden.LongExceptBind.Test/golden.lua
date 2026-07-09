local M = {}
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
M.Unsafe_Coerce_foreign = { unsafeCoerce = function(x) return x end }
M.Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
M.Data_Either_append_S_w = function(s1_S_513_S_554, s2_S_514_S_555)
  return s1_S_513_S_554 .. s2_S_514_S_555
end
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
      map = function(f_S_534)
        return function(m_S_535) return f_S_534(m_S_535) end
      end
    }
  end
}
M.Data_Identity_applicativeIdentity = {
  pure = function(x_S_536) return x_S_536 end,
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
        return (dictMonad.Bind1()).bind(v)(function(v2_S_539)
          if "Data.Either∷Either.Left" == v2_S_539["$ctor"] then
            return (dictMonad.Applicative0()).pure(M.Data_Either_Left(v2_S_539.value0))
          elseif "Data.Either∷Either.Right" == v2_S_539["$ctor"] then
            return k(v2_S_539.value0)
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
      local dictMonad_S_542 = M.Control_Monad_Except_Trans_monadExceptT(dictMonad)
      local bind_S_543 = (dictMonad_S_542.Bind1()).bind
      return function(f_S_544)
        return function(a_S_545)
          return bind_S_543(f_S_544)(function(fPrime_S_546)
            return bind_S_543(a_S_545)(function(aPrime_S_547)
              return (dictMonad_S_542.Applicative0()).pure(fPrime_S_546(aPrime_S_547))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return {
        map = function(f_S_531)
          return function(v_S_533)
            return (((dictMonad.Bind1()).Apply0()).Functor0()).map(function( m_S_541 )
              if "Data.Either∷Either.Left" == m_S_541["$ctor"] then
                return M.Data_Either_Left(m_S_541.value0)
              elseif "Data.Either∷Either.Right" == m_S_541["$ctor"] then
                return M.Data_Either_Right(f_S_531(m_S_541.value0))
              else
                return error("No patterns matched")
              end
            end)(v_S_533)
          end
        end
      }
    end
  }
end
M.Control_Monad_Except_Trans_applicativeExceptT = function(dictMonad)
  return {
    pure = function(x_S_575_S_588)
      return (dictMonad.Applicative0()).pure(M.Data_Either_Right(x_S_575_S_588))
    end,
    Apply0 = function()
      return M.Control_Monad_Except_Trans_applyExceptT(dictMonad)
    end
  }
end
M.Golden_LongExceptBind_Test_bind = (M.Control_Monad_Except_Trans_bindExceptT(M.Data_Identity_monadIdentity)).bind
M.Golden_LongExceptBind_Test_add_S_w = function(x_S_511_S_549, y_S_512_S_550)
  return x_S_511_S_549 + y_S_512_S_550
end
M.Golden_LongExceptBind_Test_go = (function()
  local _S_kont793 = function(x1_S_794)
    return function(x160_S_795)
      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x160_S_795, 1)))(function( x161 )
        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x161, 1)))(function( x162 )
          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x162, 1)))(function( x163 )
            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x163, 1)))(function( x164 )
              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x164, 1)))(function( x165 )
                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x165, 1)))(function( x166 )
                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x166, 1)))(function( x167 )
                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x167, 1)))(function( x168 )
                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x168, 1)))(function( x169 )
                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x169, 1)))(function( x170 )
                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x170, 1)))(function( x171 )
                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x171, 1)))(function( x172 )
                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x172, 1)))(function( x173 )
                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x173, 1)))(function( x174 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x174, 1)))(function( x175 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x175, 1)))(function( x176 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x176, 1)))(function( x177 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x177, 1)))(function( x178 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x178, 1)))(function( x179 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x179, 1)))(function( x180 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x180, 1)))(function( x181 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x181, 1)))(function( x182 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x182, 1)))(function( x183 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x183, 1)))(function( x184 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x184, 1)))(function( x185 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x185, 1)))(function( x186 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x186, 1)))(function( x187 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x187, 1)))(function( x188 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x188, 1)))(function( x189 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x189, 1)))(function( x190 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x190, 1)))(function( x191 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x191, 1)))(function( x192 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x192, 1)))(function( x193 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x193, 1)))(function( x194 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x194, 1)))(function( x195 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x195, 1)))(function( x196 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x196, 1)))(function( x197 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x197, 1)))(function( x198 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x198, 1)))(function( x199 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x199, 1)))(function( x200 )
                                                                                      return (M.Control_Monad_Except_Trans_applicativeExceptT(M.Data_Identity_monadIdentity)).pure(M.Golden_LongExceptBind_Test_add_S_w(x1_S_794, x200))
                                                                                    end)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
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
  local _S_kont796 = function(x1_S_797)
    return function(x120_S_798)
      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x120_S_798, 1)))(function( x121 )
        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x121, 1)))(function( x122 )
          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x122, 1)))(function( x123 )
            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x123, 1)))(function( x124 )
              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x124, 1)))(function( x125 )
                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x125, 1)))(function( x126 )
                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x126, 1)))(function( x127 )
                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x127, 1)))(function( x128 )
                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x128, 1)))(function( x129 )
                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x129, 1)))(function( x130 )
                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x130, 1)))(function( x131 )
                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x131, 1)))(function( x132 )
                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x132, 1)))(function( x133 )
                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x133, 1)))(function( x134 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x134, 1)))(function( x135 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x135, 1)))(function( x136 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x136, 1)))(function( x137 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x137, 1)))(function( x138 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x138, 1)))(function( x139 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x139, 1)))(function( x140 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x140, 1)))(function( x141 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x141, 1)))(function( x142 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x142, 1)))(function( x143 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x143, 1)))(function( x144 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x144, 1)))(function( x145 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x145, 1)))(function( x146 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x146, 1)))(function( x147 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x147, 1)))(function( x148 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x148, 1)))(function( x149 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x149, 1)))(function( x150 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x150, 1)))(function( x151 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x151, 1)))(function( x152 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x152, 1)))(function( x153 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x153, 1)))(function( x154 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x154, 1)))(function( x155 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x155, 1)))(function( x156 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x156, 1)))(function( x157 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x157, 1)))(function( x158 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x158, 1)))(function( x159 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x159, 1)))(function( x160 )
                                                                                      return _S_kont793(x1_S_797)(x160)
                                                                                    end)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
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
  local _S_kont799 = function(x1_S_800)
    return function(x80_S_801)
      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x80_S_801, 1)))(function( x81 )
        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x81, 1)))(function( x82 )
          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x82, 1)))(function( x83 )
            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x83, 1)))(function( x84 )
              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x84, 1)))(function( x85 )
                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x85, 1)))(function( x86 )
                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x86, 1)))(function( x87 )
                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x87, 1)))(function( x88 )
                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x88, 1)))(function( x89 )
                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x89, 1)))(function( x90 )
                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x90, 1)))(function( x91 )
                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x91, 1)))(function( x92 )
                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x92, 1)))(function( x93 )
                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x93, 1)))(function( x94 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x94, 1)))(function( x95 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x95, 1)))(function( x96 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x96, 1)))(function( x97 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x97, 1)))(function( x98 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x98, 1)))(function( x99 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x99, 1)))(function( x100 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x100, 1)))(function( x101 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x101, 1)))(function( x102 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x102, 1)))(function( x103 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x103, 1)))(function( x104 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x104, 1)))(function( x105 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x105, 1)))(function( x106 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x106, 1)))(function( x107 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x107, 1)))(function( x108 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x108, 1)))(function( x109 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x109, 1)))(function( x110 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x110, 1)))(function( x111 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x111, 1)))(function( x112 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x112, 1)))(function( x113 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x113, 1)))(function( x114 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x114, 1)))(function( x115 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x115, 1)))(function( x116 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x116, 1)))(function( x117 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x117, 1)))(function( x118 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x118, 1)))(function( x119 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x119, 1)))(function( x120 )
                                                                                      return _S_kont796(x1_S_800)(x120)
                                                                                    end)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
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
  local _S_kont802 = function(x1_S_803)
    return function(x40_S_804)
      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x40_S_804, 1)))(function( x41 )
        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x41, 1)))(function( x42 )
          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x42, 1)))(function( x43 )
            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x43, 1)))(function( x44 )
              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x44, 1)))(function( x45 )
                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x45, 1)))(function( x46 )
                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x46, 1)))(function( x47 )
                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x47, 1)))(function( x48 )
                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x48, 1)))(function( x49 )
                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x49, 1)))(function( x50 )
                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x50, 1)))(function( x51 )
                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x51, 1)))(function( x52 )
                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x52, 1)))(function( x53 )
                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x53, 1)))(function( x54 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x54, 1)))(function( x55 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x55, 1)))(function( x56 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x56, 1)))(function( x57 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x57, 1)))(function( x58 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x58, 1)))(function( x59 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x59, 1)))(function( x60 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x60, 1)))(function( x61 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x61, 1)))(function( x62 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x62, 1)))(function( x63 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x63, 1)))(function( x64 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x64, 1)))(function( x65 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x65, 1)))(function( x66 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x66, 1)))(function( x67 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x67, 1)))(function( x68 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x68, 1)))(function( x69 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x69, 1)))(function( x70 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x70, 1)))(function( x71 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x71, 1)))(function( x72 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x72, 1)))(function( x73 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x73, 1)))(function( x74 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x74, 1)))(function( x75 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x75, 1)))(function( x76 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x76, 1)))(function( x77 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x77, 1)))(function( x78 )
                                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x78, 1)))(function( x79 )
                                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x79, 1)))(function( x80 )
                                                                                      return _S_kont799(x1_S_803)(x80)
                                                                                    end)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
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
  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(1))(function(x1)
    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x1, 1)))(function( x2 )
      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x2, 1)))(function( x3 )
        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x3, 1)))(function( x4 )
          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x4, 1)))(function( x5 )
            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x5, 1)))(function( x6 )
              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x6, 1)))(function( x7 )
                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x7, 1)))(function( x8 )
                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x8, 1)))(function( x9 )
                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x9, 1)))(function( x10 )
                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x10, 1)))(function( x11 )
                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x11, 1)))(function( x12 )
                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x12, 1)))(function( x13 )
                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x13, 1)))(function( x14 )
                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x14, 1)))(function( x15 )
                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x15, 1)))(function( x16 )
                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x16, 1)))(function( x17 )
                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x17, 1)))(function( x18 )
                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x18, 1)))(function( x19 )
                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x19, 1)))(function( x20 )
                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x20, 1)))(function( x21 )
                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x21, 1)))(function( x22 )
                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x22, 1)))(function( x23 )
                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x23, 1)))(function( x24 )
                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x24, 1)))(function( x25 )
                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x25, 1)))(function( x26 )
                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x26, 1)))(function( x27 )
                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x27, 1)))(function( x28 )
                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x28, 1)))(function( x29 )
                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x29, 1)))(function( x30 )
                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x30, 1)))(function( x31 )
                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x31, 1)))(function( x32 )
                                                                  return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x32, 1)))(function( x33 )
                                                                    return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x33, 1)))(function( x34 )
                                                                      return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x34, 1)))(function( x35 )
                                                                        return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x35, 1)))(function( x36 )
                                                                          return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x36, 1)))(function( x37 )
                                                                            return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x37, 1)))(function( x38 )
                                                                              return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x38, 1)))(function( x39 )
                                                                                return M.Golden_LongExceptBind_Test_bind(M.Data_Either_Right(M.Golden_LongExceptBind_Test_add_S_w(x39, 1)))(function( x40 )
                                                                                  return _S_kont802(x1)(x40)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
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
M.Golden_LongExceptBind_Test_compute = M.Unsafe_Coerce_foreign.unsafeCoerce(M.Golden_LongExceptBind_Test_go)
return M.Effect_Console_foreign.log((function()
  if "Data.Either∷Either.Left" == M.Golden_LongExceptBind_Test_compute["$ctor"] then
    return M.Data_Either_append_S_w("(Left ", M.Data_Either_append_S_w(M.Data_Show_foreign.showStringImpl(M.Golden_LongExceptBind_Test_compute.value0), ")"))
  elseif "Data.Either∷Either.Right" == M.Golden_LongExceptBind_Test_compute["$ctor"] then
    return M.Data_Either_append_S_w("(Right ", M.Data_Either_append_S_w(M.Data_Show_foreign.showIntImpl(M.Golden_LongExceptBind_Test_compute.value0), ")"))
  else
    return error("No patterns matched")
  end
end)())()
