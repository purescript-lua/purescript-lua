local Data_Show_foreign = {
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
local Unsafe_Coerce_foreign = { unsafeCoerce = function(x) return x end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Either_append_S_w = function(s1_S_557, s2_S_558)
  return s1_S_557 .. s2_S_558
end
local Data_Either_Left = function(value0)
  return { "Data.Either∷Either.Left", value0 }
end
local Data_Either_Right = function(value0)
  return { "Data.Either∷Either.Right", value0 }
end
local Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function()
    return {
      map = function(f_S_537)
        return function(m_S_538) return f_S_537(m_S_538) end
      end
    }
  end
}
local Data_Identity_applicativeIdentity = {
  pure = function(x_S_539) return x_S_539 end,
  Apply0 = function() return Data_Identity_applyIdentity end
}
local Data_Identity_monadIdentity = {
  Applicative0 = function() return Data_Identity_applicativeIdentity end,
  Bind1 = function()
    return {
      bind = function(v_S_87)
        return function(f_S_88) return f_S_88(v_S_87) end
      end,
      Apply0 = function() return Data_Identity_applyIdentity end
    }
  end
}
local Control_Monad_Except_Trans_bindExceptT
local Control_Monad_Except_Trans_applicativeExceptT
local Control_Monad_Except_Trans_monadExceptT = function(dictMonad)
  return {
    Applicative0 = function()
      return Control_Monad_Except_Trans_applicativeExceptT(dictMonad)
    end,
    Bind1 = function()
      return Control_Monad_Except_Trans_bindExceptT(dictMonad)
    end
  }
end
local Control_Monad_Except_Trans_applyExceptT
Control_Monad_Except_Trans_bindExceptT = function(dictMonad)
  return {
    bind = function(v)
      return function(k)
        return (dictMonad.Bind1()).bind(v)(function(v2_S_542)
          local _S_cse797 = v2_S_542[2]
          local _S_cse796 = v2_S_542[1]
          if "Data.Either∷Either.Left" == _S_cse796 then
            return (dictMonad.Applicative0()).pure(Data_Either_Left(_S_cse797))
          elseif "Data.Either∷Either.Right" == _S_cse796 then
            return k(_S_cse797)
          else
            return error("No patterns matched")
          end
        end)
      end
    end,
    Apply0 = function()
      return Control_Monad_Except_Trans_applyExceptT(dictMonad)
    end
  }
end
Control_Monad_Except_Trans_applyExceptT = function(dictMonad)
  return {
    apply = (function()
      local dictMonad_S_545 = Control_Monad_Except_Trans_monadExceptT(dictMonad)
      local bind_S_546 = (dictMonad_S_545.Bind1()).bind
      return function(f_S_547)
        return function(a_S_548)
          return bind_S_546(f_S_547)(function(fPrime_S_549)
            return bind_S_546(a_S_548)(function(aPrime_S_550)
              return (dictMonad_S_545.Applicative0()).pure(fPrime_S_549(aPrime_S_550))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return {
        map = function(f_S_534)
          return function(v_S_536)
            return (((dictMonad.Bind1()).Apply0()).Functor0()).map(function( m_S_544 )
              local _S_cse799 = m_S_544[2]
              local _S_cse798 = m_S_544[1]
              if "Data.Either∷Either.Left" == _S_cse798 then
                return Data_Either_Left(_S_cse799)
              elseif "Data.Either∷Either.Right" == _S_cse798 then
                return Data_Either_Right(f_S_534(_S_cse799))
              else
                return error("No patterns matched")
              end
            end)(v_S_536)
          end
        end
      }
    end
  }
end
Control_Monad_Except_Trans_applicativeExceptT = function(dictMonad)
  return {
    pure = function(x_S_591)
      return (dictMonad.Applicative0()).pure(Data_Either_Right(x_S_591))
    end,
    Apply0 = function()
      return Control_Monad_Except_Trans_applyExceptT(dictMonad)
    end
  }
end
local Golden_LongExceptBind_Test_bind = (Control_Monad_Except_Trans_bindExceptT(Data_Identity_monadIdentity)).bind
local Golden_LongExceptBind_Test_add_S_w = function(x_S_552, y_S_553)
  return x_S_552 + y_S_553
end
local Golden_LongExceptBind_Test_go = (function()
  local _S_kont802_S_w = function(x1_S_803, x160_S_804)
    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x160_S_804, 1)))(function( x161 )
      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x161, 1)))(function( x162 )
        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x162, 1)))(function( x163 )
          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x163, 1)))(function( x164 )
            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x164, 1)))(function( x165 )
              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x165, 1)))(function( x166 )
                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x166, 1)))(function( x167 )
                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x167, 1)))(function( x168 )
                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x168, 1)))(function( x169 )
                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x169, 1)))(function( x170 )
                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x170, 1)))(function( x171 )
                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x171, 1)))(function( x172 )
                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x172, 1)))(function( x173 )
                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x173, 1)))(function( x174 )
                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x174, 1)))(function( x175 )
                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x175, 1)))(function( x176 )
                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x176, 1)))(function( x177 )
                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x177, 1)))(function( x178 )
                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x178, 1)))(function( x179 )
                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x179, 1)))(function( x180 )
                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x180, 1)))(function( x181 )
                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x181, 1)))(function( x182 )
                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x182, 1)))(function( x183 )
                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x183, 1)))(function( x184 )
                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x184, 1)))(function( x185 )
                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x185, 1)))(function( x186 )
                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x186, 1)))(function( x187 )
                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x187, 1)))(function( x188 )
                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x188, 1)))(function( x189 )
                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x189, 1)))(function( x190 )
                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x190, 1)))(function( x191 )
                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x191, 1)))(function( x192 )
                                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x192, 1)))(function( x193 )
                                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x193, 1)))(function( x194 )
                                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x194, 1)))(function( x195 )
                                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x195, 1)))(function( x196 )
                                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x196, 1)))(function( x197 )
                                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x197, 1)))(function( x198 )
                                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x198, 1)))(function( x199 )
                                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x199, 1)))(function( x200 )
                                                                                    return (Control_Monad_Except_Trans_applicativeExceptT(Data_Identity_monadIdentity)).pure(Golden_LongExceptBind_Test_add_S_w(x1_S_803, x200))
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont805_S_w = function(x1_S_806, x120_S_807)
    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x120_S_807, 1)))(function( x121 )
      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x121, 1)))(function( x122 )
        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x122, 1)))(function( x123 )
          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x123, 1)))(function( x124 )
            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x124, 1)))(function( x125 )
              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x125, 1)))(function( x126 )
                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x126, 1)))(function( x127 )
                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x127, 1)))(function( x128 )
                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x128, 1)))(function( x129 )
                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x129, 1)))(function( x130 )
                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x130, 1)))(function( x131 )
                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x131, 1)))(function( x132 )
                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x132, 1)))(function( x133 )
                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x133, 1)))(function( x134 )
                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x134, 1)))(function( x135 )
                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x135, 1)))(function( x136 )
                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x136, 1)))(function( x137 )
                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x137, 1)))(function( x138 )
                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x138, 1)))(function( x139 )
                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x139, 1)))(function( x140 )
                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x140, 1)))(function( x141 )
                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x141, 1)))(function( x142 )
                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x142, 1)))(function( x143 )
                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x143, 1)))(function( x144 )
                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x144, 1)))(function( x145 )
                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x145, 1)))(function( x146 )
                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x146, 1)))(function( x147 )
                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x147, 1)))(function( x148 )
                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x148, 1)))(function( x149 )
                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x149, 1)))(function( x150 )
                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x150, 1)))(function( x151 )
                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x151, 1)))(function( x152 )
                                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x152, 1)))(function( x153 )
                                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x153, 1)))(function( x154 )
                                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x154, 1)))(function( x155 )
                                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x155, 1)))(function( x156 )
                                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x156, 1)))(function( x157 )
                                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x157, 1)))(function( x158 )
                                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x158, 1)))(function( x159 )
                                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x159, 1)))(function( x160 )
                                                                                    return _S_kont802_S_w(x1_S_806, x160)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont808_S_w = function(x1_S_809, x80_S_810)
    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x80_S_810, 1)))(function( x81 )
      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x81, 1)))(function( x82 )
        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x82, 1)))(function( x83 )
          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x83, 1)))(function( x84 )
            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x84, 1)))(function( x85 )
              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x85, 1)))(function( x86 )
                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x86, 1)))(function( x87 )
                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x87, 1)))(function( x88 )
                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x88, 1)))(function( x89 )
                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x89, 1)))(function( x90 )
                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x90, 1)))(function( x91 )
                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x91, 1)))(function( x92 )
                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x92, 1)))(function( x93 )
                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x93, 1)))(function( x94 )
                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x94, 1)))(function( x95 )
                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x95, 1)))(function( x96 )
                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x96, 1)))(function( x97 )
                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x97, 1)))(function( x98 )
                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x98, 1)))(function( x99 )
                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x99, 1)))(function( x100 )
                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x100, 1)))(function( x101 )
                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x101, 1)))(function( x102 )
                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x102, 1)))(function( x103 )
                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x103, 1)))(function( x104 )
                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x104, 1)))(function( x105 )
                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x105, 1)))(function( x106 )
                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x106, 1)))(function( x107 )
                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x107, 1)))(function( x108 )
                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x108, 1)))(function( x109 )
                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x109, 1)))(function( x110 )
                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x110, 1)))(function( x111 )
                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x111, 1)))(function( x112 )
                                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x112, 1)))(function( x113 )
                                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x113, 1)))(function( x114 )
                                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x114, 1)))(function( x115 )
                                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x115, 1)))(function( x116 )
                                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x116, 1)))(function( x117 )
                                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x117, 1)))(function( x118 )
                                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x118, 1)))(function( x119 )
                                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x119, 1)))(function( x120 )
                                                                                    return _S_kont805_S_w(x1_S_809, x120)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont811_S_w = function(x1_S_812, x40_S_813)
    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x40_S_813, 1)))(function( x41 )
      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x41, 1)))(function( x42 )
        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x42, 1)))(function( x43 )
          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x43, 1)))(function( x44 )
            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x44, 1)))(function( x45 )
              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x45, 1)))(function( x46 )
                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x46, 1)))(function( x47 )
                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x47, 1)))(function( x48 )
                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x48, 1)))(function( x49 )
                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x49, 1)))(function( x50 )
                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x50, 1)))(function( x51 )
                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x51, 1)))(function( x52 )
                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x52, 1)))(function( x53 )
                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x53, 1)))(function( x54 )
                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x54, 1)))(function( x55 )
                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x55, 1)))(function( x56 )
                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x56, 1)))(function( x57 )
                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x57, 1)))(function( x58 )
                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x58, 1)))(function( x59 )
                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x59, 1)))(function( x60 )
                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x60, 1)))(function( x61 )
                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x61, 1)))(function( x62 )
                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x62, 1)))(function( x63 )
                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x63, 1)))(function( x64 )
                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x64, 1)))(function( x65 )
                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x65, 1)))(function( x66 )
                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x66, 1)))(function( x67 )
                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x67, 1)))(function( x68 )
                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x68, 1)))(function( x69 )
                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x69, 1)))(function( x70 )
                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x70, 1)))(function( x71 )
                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x71, 1)))(function( x72 )
                                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x72, 1)))(function( x73 )
                                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x73, 1)))(function( x74 )
                                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x74, 1)))(function( x75 )
                                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x75, 1)))(function( x76 )
                                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x76, 1)))(function( x77 )
                                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x77, 1)))(function( x78 )
                                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x78, 1)))(function( x79 )
                                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x79, 1)))(function( x80 )
                                                                                    return _S_kont808_S_w(x1_S_812, x80)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  return Golden_LongExceptBind_Test_bind(Data_Either_Right(1))(function(x1)
    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x1, 1)))(function( x2 )
      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x2, 1)))(function( x3 )
        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x3, 1)))(function( x4 )
          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x4, 1)))(function( x5 )
            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x5, 1)))(function( x6 )
              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x6, 1)))(function( x7 )
                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x7, 1)))(function( x8 )
                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x8, 1)))(function( x9 )
                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x9, 1)))(function( x10 )
                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x10, 1)))(function( x11 )
                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x11, 1)))(function( x12 )
                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x12, 1)))(function( x13 )
                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x13, 1)))(function( x14 )
                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x14, 1)))(function( x15 )
                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x15, 1)))(function( x16 )
                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x16, 1)))(function( x17 )
                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x17, 1)))(function( x18 )
                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x18, 1)))(function( x19 )
                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x19, 1)))(function( x20 )
                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x20, 1)))(function( x21 )
                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x21, 1)))(function( x22 )
                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x22, 1)))(function( x23 )
                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x23, 1)))(function( x24 )
                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x24, 1)))(function( x25 )
                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x25, 1)))(function( x26 )
                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x26, 1)))(function( x27 )
                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x27, 1)))(function( x28 )
                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x28, 1)))(function( x29 )
                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x29, 1)))(function( x30 )
                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x30, 1)))(function( x31 )
                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x31, 1)))(function( x32 )
                                                                  return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x32, 1)))(function( x33 )
                                                                    return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x33, 1)))(function( x34 )
                                                                      return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x34, 1)))(function( x35 )
                                                                        return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x35, 1)))(function( x36 )
                                                                          return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x36, 1)))(function( x37 )
                                                                            return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x37, 1)))(function( x38 )
                                                                              return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x38, 1)))(function( x39 )
                                                                                return Golden_LongExceptBind_Test_bind(Data_Either_Right(Golden_LongExceptBind_Test_add_S_w(x39, 1)))(function( x40 )
                                                                                  return _S_kont811_S_w(x1, x40)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
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
local Golden_LongExceptBind_Test_compute = Unsafe_Coerce_foreign.unsafeCoerce(Golden_LongExceptBind_Test_go)
return (function()
  local _S_cse801 = Golden_LongExceptBind_Test_compute[2]
  local _S_cse800 = Golden_LongExceptBind_Test_compute[1]
  return Effect_Console_foreign.log((function()
    if "Data.Either∷Either.Left" == _S_cse800 then
      return Data_Either_append_S_w("(Left ", Data_Either_append_S_w(Data_Show_foreign.showStringImpl(_S_cse801), ")"))
    elseif "Data.Either∷Either.Right" == _S_cse800 then
      return Data_Either_append_S_w("(Right ", Data_Either_append_S_w(Data_Show_foreign.showIntImpl(_S_cse801), ")"))
    else
      return error("No patterns matched")
    end
  end)())
end)()()
