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
local Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function()
    return {
      map = function(f_S_539)
        return function(m_S_540) return f_S_539(m_S_540) end
      end
    }
  end
}
local Data_Identity_applicativeIdentity = {
  pure = function(x_S_541) return x_S_541 end,
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
        return (dictMonad.Bind1()).bind(v)(function(v2_S_544)
          local _S_cse1411 = v2_S_544[2]
          local _S_cse1410 = v2_S_544[1]
          if "Data.Either∷Either.Left" == _S_cse1410 then
            return (dictMonad.Applicative0()).pure({
              "Data.Either∷Either.Left",
              _S_cse1411
            })
          elseif "Data.Either∷Either.Right" == _S_cse1410 then
            return k(_S_cse1411)
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
      local dictMonad_S_547 = Control_Monad_Except_Trans_monadExceptT(dictMonad)
      local bind_S_548 = (dictMonad_S_547.Bind1()).bind
      return function(f_S_549)
        return function(a_S_550)
          return bind_S_548(f_S_549)(function(fPrime_S_551)
            return bind_S_548(a_S_550)(function(aPrime_S_552)
              return (dictMonad_S_547.Applicative0()).pure(fPrime_S_551(aPrime_S_552))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return {
        map = function(f_S_536)
          return function(v_S_538)
            return (((dictMonad.Bind1()).Apply0()).Functor0()).map(function( m_S_546 )
              local _S_cse1413 = m_S_546[2]
              local _S_cse1412 = m_S_546[1]
              if "Data.Either∷Either.Left" == _S_cse1412 then
                return { "Data.Either∷Either.Left", _S_cse1413 }
              elseif "Data.Either∷Either.Right" == _S_cse1412 then
                return { "Data.Either∷Either.Right", (f_S_536(_S_cse1413)) }
              else
                return error("No patterns matched")
              end
            end)(v_S_538)
          end
        end
      }
    end
  }
end
Control_Monad_Except_Trans_applicativeExceptT = function(dictMonad)
  return {
    pure = function(x_S_1204)
      return (dictMonad.Applicative0()).pure({
        "Data.Either∷Either.Right",
        x_S_1204
      })
    end,
    Apply0 = function()
      return Control_Monad_Except_Trans_applyExceptT(dictMonad)
    end
  }
end
local Golden_LongExceptBind_Test_bind = (Control_Monad_Except_Trans_bindExceptT(Data_Identity_monadIdentity)).bind
local Golden_LongExceptBind_Test_go = (function()
  local _S_kont1416_S_w = function(x1_S_1417, x160_S_1418)
    return Golden_LongExceptBind_Test_bind({
      "Data.Either∷Either.Right",
      x160_S_1418 + 1
    })(function(x161)
      return Golden_LongExceptBind_Test_bind({
        "Data.Either∷Either.Right",
        x161 + 1
      })(function(x162)
        return Golden_LongExceptBind_Test_bind({
          "Data.Either∷Either.Right",
          x162 + 1
        })(function(x163)
          return Golden_LongExceptBind_Test_bind({
            "Data.Either∷Either.Right",
            x163 + 1
          })(function(x164)
            return Golden_LongExceptBind_Test_bind({
              "Data.Either∷Either.Right",
              x164 + 1
            })(function(x165)
              return Golden_LongExceptBind_Test_bind({
                "Data.Either∷Either.Right",
                x165 + 1
              })(function(x166)
                return Golden_LongExceptBind_Test_bind({
                  "Data.Either∷Either.Right",
                  x166 + 1
                })(function(x167)
                  return Golden_LongExceptBind_Test_bind({
                    "Data.Either∷Either.Right",
                    x167 + 1
                  })(function(x168)
                    return Golden_LongExceptBind_Test_bind({
                      "Data.Either∷Either.Right",
                      x168 + 1
                    })(function(x169)
                      return Golden_LongExceptBind_Test_bind({
                        "Data.Either∷Either.Right",
                        x169 + 1
                      })(function(x170)
                        return Golden_LongExceptBind_Test_bind({
                          "Data.Either∷Either.Right",
                          x170 + 1
                        })(function(x171)
                          return Golden_LongExceptBind_Test_bind({
                            "Data.Either∷Either.Right",
                            x171 + 1
                          })(function(x172)
                            return Golden_LongExceptBind_Test_bind({
                              "Data.Either∷Either.Right",
                              x172 + 1
                            })(function(x173)
                              return Golden_LongExceptBind_Test_bind({
                                "Data.Either∷Either.Right",
                                x173 + 1
                              })(function(x174)
                                return Golden_LongExceptBind_Test_bind({
                                  "Data.Either∷Either.Right",
                                  x174 + 1
                                })(function(x175)
                                  return Golden_LongExceptBind_Test_bind({
                                    "Data.Either∷Either.Right",
                                    x175 + 1
                                  })(function(x176)
                                    return Golden_LongExceptBind_Test_bind({
                                      "Data.Either∷Either.Right",
                                      x176 + 1
                                    })(function(x177)
                                      return Golden_LongExceptBind_Test_bind({
                                        "Data.Either∷Either.Right",
                                        x177 + 1
                                      })(function(x178)
                                        return Golden_LongExceptBind_Test_bind({
                                          "Data.Either∷Either.Right",
                                          x178 + 1
                                        })(function(x179)
                                          return Golden_LongExceptBind_Test_bind({
                                            "Data.Either∷Either.Right",
                                            x179 + 1
                                          })(function(x180)
                                            return Golden_LongExceptBind_Test_bind({
                                              "Data.Either∷Either.Right",
                                              x180 + 1
                                            })(function(x181)
                                              return Golden_LongExceptBind_Test_bind({
                                                "Data.Either∷Either.Right",
                                                x181 + 1
                                              })(function(x182)
                                                return Golden_LongExceptBind_Test_bind({
                                                  "Data.Either∷Either.Right",
                                                  x182 + 1
                                                })(function(x183)
                                                  return Golden_LongExceptBind_Test_bind({
                                                    "Data.Either∷Either.Right",
                                                    x183 + 1
                                                  })(function(x184)
                                                    return Golden_LongExceptBind_Test_bind({
                                                      "Data.Either∷Either.Right",
                                                      x184 + 1
                                                    })(function(x185)
                                                      return Golden_LongExceptBind_Test_bind({
                                                        "Data.Either∷Either.Right",
                                                        x185 + 1
                                                      })(function(x186)
                                                        return Golden_LongExceptBind_Test_bind({
                                                          "Data.Either∷Either.Right",
                                                          x186 + 1
                                                        })(function(x187)
                                                          return Golden_LongExceptBind_Test_bind({
                                                            "Data.Either∷Either.Right",
                                                            x187 + 1
                                                          })(function(x188)
                                                            return Golden_LongExceptBind_Test_bind({
                                                              "Data.Either∷Either.Right",
                                                              x188 + 1
                                                            })(function(x189)
                                                              return Golden_LongExceptBind_Test_bind({
                                                                "Data.Either∷Either.Right",
                                                                x189 + 1
                                                              })(function(x190)
                                                                return Golden_LongExceptBind_Test_bind({
                                                                  "Data.Either∷Either.Right",
                                                                  x190 + 1
                                                                })(function( x191 )
                                                                  return Golden_LongExceptBind_Test_bind({
                                                                    "Data.Either∷Either.Right",
                                                                    x191 + 1
                                                                  })(function( x192 )
                                                                    return Golden_LongExceptBind_Test_bind({
                                                                      "Data.Either∷Either.Right",
                                                                      x192 + 1
                                                                    })(function( x193 )
                                                                      return Golden_LongExceptBind_Test_bind({
                                                                        "Data.Either∷Either.Right",
                                                                        x193 + 1
                                                                      })(function( x194 )
                                                                        return Golden_LongExceptBind_Test_bind({
                                                                          "Data.Either∷Either.Right",
                                                                          x194 + 1
                                                                        })(function( x195 )
                                                                          return Golden_LongExceptBind_Test_bind({
                                                                            "Data.Either∷Either.Right",
                                                                            x195 + 1
                                                                          })(function( x196 )
                                                                            return Golden_LongExceptBind_Test_bind({
                                                                              "Data.Either∷Either.Right",
                                                                              x196 + 1
                                                                            })(function( x197 )
                                                                              return Golden_LongExceptBind_Test_bind({
                                                                                "Data.Either∷Either.Right",
                                                                                x197 + 1
                                                                              })(function( x198 )
                                                                                return Golden_LongExceptBind_Test_bind({
                                                                                  "Data.Either∷Either.Right",
                                                                                  x198 + 1
                                                                                })(function( x199 )
                                                                                  return Golden_LongExceptBind_Test_bind({
                                                                                    "Data.Either∷Either.Right",
                                                                                    x199 + 1
                                                                                  })(function( x200 )
                                                                                    return (Control_Monad_Except_Trans_applicativeExceptT(Data_Identity_monadIdentity)).pure(x1_S_1417 + x200)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1419_S_w = function(x1_S_1420, x120_S_1421)
    return Golden_LongExceptBind_Test_bind({
      "Data.Either∷Either.Right",
      x120_S_1421 + 1
    })(function(x121)
      return Golden_LongExceptBind_Test_bind({
        "Data.Either∷Either.Right",
        x121 + 1
      })(function(x122)
        return Golden_LongExceptBind_Test_bind({
          "Data.Either∷Either.Right",
          x122 + 1
        })(function(x123)
          return Golden_LongExceptBind_Test_bind({
            "Data.Either∷Either.Right",
            x123 + 1
          })(function(x124)
            return Golden_LongExceptBind_Test_bind({
              "Data.Either∷Either.Right",
              x124 + 1
            })(function(x125)
              return Golden_LongExceptBind_Test_bind({
                "Data.Either∷Either.Right",
                x125 + 1
              })(function(x126)
                return Golden_LongExceptBind_Test_bind({
                  "Data.Either∷Either.Right",
                  x126 + 1
                })(function(x127)
                  return Golden_LongExceptBind_Test_bind({
                    "Data.Either∷Either.Right",
                    x127 + 1
                  })(function(x128)
                    return Golden_LongExceptBind_Test_bind({
                      "Data.Either∷Either.Right",
                      x128 + 1
                    })(function(x129)
                      return Golden_LongExceptBind_Test_bind({
                        "Data.Either∷Either.Right",
                        x129 + 1
                      })(function(x130)
                        return Golden_LongExceptBind_Test_bind({
                          "Data.Either∷Either.Right",
                          x130 + 1
                        })(function(x131)
                          return Golden_LongExceptBind_Test_bind({
                            "Data.Either∷Either.Right",
                            x131 + 1
                          })(function(x132)
                            return Golden_LongExceptBind_Test_bind({
                              "Data.Either∷Either.Right",
                              x132 + 1
                            })(function(x133)
                              return Golden_LongExceptBind_Test_bind({
                                "Data.Either∷Either.Right",
                                x133 + 1
                              })(function(x134)
                                return Golden_LongExceptBind_Test_bind({
                                  "Data.Either∷Either.Right",
                                  x134 + 1
                                })(function(x135)
                                  return Golden_LongExceptBind_Test_bind({
                                    "Data.Either∷Either.Right",
                                    x135 + 1
                                  })(function(x136)
                                    return Golden_LongExceptBind_Test_bind({
                                      "Data.Either∷Either.Right",
                                      x136 + 1
                                    })(function(x137)
                                      return Golden_LongExceptBind_Test_bind({
                                        "Data.Either∷Either.Right",
                                        x137 + 1
                                      })(function(x138)
                                        return Golden_LongExceptBind_Test_bind({
                                          "Data.Either∷Either.Right",
                                          x138 + 1
                                        })(function(x139)
                                          return Golden_LongExceptBind_Test_bind({
                                            "Data.Either∷Either.Right",
                                            x139 + 1
                                          })(function(x140)
                                            return Golden_LongExceptBind_Test_bind({
                                              "Data.Either∷Either.Right",
                                              x140 + 1
                                            })(function(x141)
                                              return Golden_LongExceptBind_Test_bind({
                                                "Data.Either∷Either.Right",
                                                x141 + 1
                                              })(function(x142)
                                                return Golden_LongExceptBind_Test_bind({
                                                  "Data.Either∷Either.Right",
                                                  x142 + 1
                                                })(function(x143)
                                                  return Golden_LongExceptBind_Test_bind({
                                                    "Data.Either∷Either.Right",
                                                    x143 + 1
                                                  })(function(x144)
                                                    return Golden_LongExceptBind_Test_bind({
                                                      "Data.Either∷Either.Right",
                                                      x144 + 1
                                                    })(function(x145)
                                                      return Golden_LongExceptBind_Test_bind({
                                                        "Data.Either∷Either.Right",
                                                        x145 + 1
                                                      })(function(x146)
                                                        return Golden_LongExceptBind_Test_bind({
                                                          "Data.Either∷Either.Right",
                                                          x146 + 1
                                                        })(function(x147)
                                                          return Golden_LongExceptBind_Test_bind({
                                                            "Data.Either∷Either.Right",
                                                            x147 + 1
                                                          })(function(x148)
                                                            return Golden_LongExceptBind_Test_bind({
                                                              "Data.Either∷Either.Right",
                                                              x148 + 1
                                                            })(function(x149)
                                                              return Golden_LongExceptBind_Test_bind({
                                                                "Data.Either∷Either.Right",
                                                                x149 + 1
                                                              })(function(x150)
                                                                return Golden_LongExceptBind_Test_bind({
                                                                  "Data.Either∷Either.Right",
                                                                  x150 + 1
                                                                })(function( x151 )
                                                                  return Golden_LongExceptBind_Test_bind({
                                                                    "Data.Either∷Either.Right",
                                                                    x151 + 1
                                                                  })(function( x152 )
                                                                    return Golden_LongExceptBind_Test_bind({
                                                                      "Data.Either∷Either.Right",
                                                                      x152 + 1
                                                                    })(function( x153 )
                                                                      return Golden_LongExceptBind_Test_bind({
                                                                        "Data.Either∷Either.Right",
                                                                        x153 + 1
                                                                      })(function( x154 )
                                                                        return Golden_LongExceptBind_Test_bind({
                                                                          "Data.Either∷Either.Right",
                                                                          x154 + 1
                                                                        })(function( x155 )
                                                                          return Golden_LongExceptBind_Test_bind({
                                                                            "Data.Either∷Either.Right",
                                                                            x155 + 1
                                                                          })(function( x156 )
                                                                            return Golden_LongExceptBind_Test_bind({
                                                                              "Data.Either∷Either.Right",
                                                                              x156 + 1
                                                                            })(function( x157 )
                                                                              return Golden_LongExceptBind_Test_bind({
                                                                                "Data.Either∷Either.Right",
                                                                                x157 + 1
                                                                              })(function( x158 )
                                                                                return Golden_LongExceptBind_Test_bind({
                                                                                  "Data.Either∷Either.Right",
                                                                                  x158 + 1
                                                                                })(function( x159 )
                                                                                  return Golden_LongExceptBind_Test_bind({
                                                                                    "Data.Either∷Either.Right",
                                                                                    x159 + 1
                                                                                  })(function( x160 )
                                                                                    return _S_kont1416_S_w(x1_S_1420, x160)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1422_S_w = function(x1_S_1423, x80_S_1424)
    return Golden_LongExceptBind_Test_bind({
      "Data.Either∷Either.Right",
      x80_S_1424 + 1
    })(function(x81)
      return Golden_LongExceptBind_Test_bind({
        "Data.Either∷Either.Right",
        x81 + 1
      })(function(x82)
        return Golden_LongExceptBind_Test_bind({
          "Data.Either∷Either.Right",
          x82 + 1
        })(function(x83)
          return Golden_LongExceptBind_Test_bind({
            "Data.Either∷Either.Right",
            x83 + 1
          })(function(x84)
            return Golden_LongExceptBind_Test_bind({
              "Data.Either∷Either.Right",
              x84 + 1
            })(function(x85)
              return Golden_LongExceptBind_Test_bind({
                "Data.Either∷Either.Right",
                x85 + 1
              })(function(x86)
                return Golden_LongExceptBind_Test_bind({
                  "Data.Either∷Either.Right",
                  x86 + 1
                })(function(x87)
                  return Golden_LongExceptBind_Test_bind({
                    "Data.Either∷Either.Right",
                    x87 + 1
                  })(function(x88)
                    return Golden_LongExceptBind_Test_bind({
                      "Data.Either∷Either.Right",
                      x88 + 1
                    })(function(x89)
                      return Golden_LongExceptBind_Test_bind({
                        "Data.Either∷Either.Right",
                        x89 + 1
                      })(function(x90)
                        return Golden_LongExceptBind_Test_bind({
                          "Data.Either∷Either.Right",
                          x90 + 1
                        })(function(x91)
                          return Golden_LongExceptBind_Test_bind({
                            "Data.Either∷Either.Right",
                            x91 + 1
                          })(function(x92)
                            return Golden_LongExceptBind_Test_bind({
                              "Data.Either∷Either.Right",
                              x92 + 1
                            })(function(x93)
                              return Golden_LongExceptBind_Test_bind({
                                "Data.Either∷Either.Right",
                                x93 + 1
                              })(function(x94)
                                return Golden_LongExceptBind_Test_bind({
                                  "Data.Either∷Either.Right",
                                  x94 + 1
                                })(function(x95)
                                  return Golden_LongExceptBind_Test_bind({
                                    "Data.Either∷Either.Right",
                                    x95 + 1
                                  })(function(x96)
                                    return Golden_LongExceptBind_Test_bind({
                                      "Data.Either∷Either.Right",
                                      x96 + 1
                                    })(function(x97)
                                      return Golden_LongExceptBind_Test_bind({
                                        "Data.Either∷Either.Right",
                                        x97 + 1
                                      })(function(x98)
                                        return Golden_LongExceptBind_Test_bind({
                                          "Data.Either∷Either.Right",
                                          x98 + 1
                                        })(function(x99)
                                          return Golden_LongExceptBind_Test_bind({
                                            "Data.Either∷Either.Right",
                                            x99 + 1
                                          })(function(x100)
                                            return Golden_LongExceptBind_Test_bind({
                                              "Data.Either∷Either.Right",
                                              x100 + 1
                                            })(function(x101)
                                              return Golden_LongExceptBind_Test_bind({
                                                "Data.Either∷Either.Right",
                                                x101 + 1
                                              })(function(x102)
                                                return Golden_LongExceptBind_Test_bind({
                                                  "Data.Either∷Either.Right",
                                                  x102 + 1
                                                })(function(x103)
                                                  return Golden_LongExceptBind_Test_bind({
                                                    "Data.Either∷Either.Right",
                                                    x103 + 1
                                                  })(function(x104)
                                                    return Golden_LongExceptBind_Test_bind({
                                                      "Data.Either∷Either.Right",
                                                      x104 + 1
                                                    })(function(x105)
                                                      return Golden_LongExceptBind_Test_bind({
                                                        "Data.Either∷Either.Right",
                                                        x105 + 1
                                                      })(function(x106)
                                                        return Golden_LongExceptBind_Test_bind({
                                                          "Data.Either∷Either.Right",
                                                          x106 + 1
                                                        })(function(x107)
                                                          return Golden_LongExceptBind_Test_bind({
                                                            "Data.Either∷Either.Right",
                                                            x107 + 1
                                                          })(function(x108)
                                                            return Golden_LongExceptBind_Test_bind({
                                                              "Data.Either∷Either.Right",
                                                              x108 + 1
                                                            })(function(x109)
                                                              return Golden_LongExceptBind_Test_bind({
                                                                "Data.Either∷Either.Right",
                                                                x109 + 1
                                                              })(function(x110)
                                                                return Golden_LongExceptBind_Test_bind({
                                                                  "Data.Either∷Either.Right",
                                                                  x110 + 1
                                                                })(function( x111 )
                                                                  return Golden_LongExceptBind_Test_bind({
                                                                    "Data.Either∷Either.Right",
                                                                    x111 + 1
                                                                  })(function( x112 )
                                                                    return Golden_LongExceptBind_Test_bind({
                                                                      "Data.Either∷Either.Right",
                                                                      x112 + 1
                                                                    })(function( x113 )
                                                                      return Golden_LongExceptBind_Test_bind({
                                                                        "Data.Either∷Either.Right",
                                                                        x113 + 1
                                                                      })(function( x114 )
                                                                        return Golden_LongExceptBind_Test_bind({
                                                                          "Data.Either∷Either.Right",
                                                                          x114 + 1
                                                                        })(function( x115 )
                                                                          return Golden_LongExceptBind_Test_bind({
                                                                            "Data.Either∷Either.Right",
                                                                            x115 + 1
                                                                          })(function( x116 )
                                                                            return Golden_LongExceptBind_Test_bind({
                                                                              "Data.Either∷Either.Right",
                                                                              x116 + 1
                                                                            })(function( x117 )
                                                                              return Golden_LongExceptBind_Test_bind({
                                                                                "Data.Either∷Either.Right",
                                                                                x117 + 1
                                                                              })(function( x118 )
                                                                                return Golden_LongExceptBind_Test_bind({
                                                                                  "Data.Either∷Either.Right",
                                                                                  x118 + 1
                                                                                })(function( x119 )
                                                                                  return Golden_LongExceptBind_Test_bind({
                                                                                    "Data.Either∷Either.Right",
                                                                                    x119 + 1
                                                                                  })(function( x120 )
                                                                                    return _S_kont1419_S_w(x1_S_1423, x120)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1425_S_w = function(x1_S_1426, x40_S_1427)
    return Golden_LongExceptBind_Test_bind({
      "Data.Either∷Either.Right",
      x40_S_1427 + 1
    })(function(x41)
      return Golden_LongExceptBind_Test_bind({
        "Data.Either∷Either.Right",
        x41 + 1
      })(function(x42)
        return Golden_LongExceptBind_Test_bind({
          "Data.Either∷Either.Right",
          x42 + 1
        })(function(x43)
          return Golden_LongExceptBind_Test_bind({
            "Data.Either∷Either.Right",
            x43 + 1
          })(function(x44)
            return Golden_LongExceptBind_Test_bind({
              "Data.Either∷Either.Right",
              x44 + 1
            })(function(x45)
              return Golden_LongExceptBind_Test_bind({
                "Data.Either∷Either.Right",
                x45 + 1
              })(function(x46)
                return Golden_LongExceptBind_Test_bind({
                  "Data.Either∷Either.Right",
                  x46 + 1
                })(function(x47)
                  return Golden_LongExceptBind_Test_bind({
                    "Data.Either∷Either.Right",
                    x47 + 1
                  })(function(x48)
                    return Golden_LongExceptBind_Test_bind({
                      "Data.Either∷Either.Right",
                      x48 + 1
                    })(function(x49)
                      return Golden_LongExceptBind_Test_bind({
                        "Data.Either∷Either.Right",
                        x49 + 1
                      })(function(x50)
                        return Golden_LongExceptBind_Test_bind({
                          "Data.Either∷Either.Right",
                          x50 + 1
                        })(function(x51)
                          return Golden_LongExceptBind_Test_bind({
                            "Data.Either∷Either.Right",
                            x51 + 1
                          })(function(x52)
                            return Golden_LongExceptBind_Test_bind({
                              "Data.Either∷Either.Right",
                              x52 + 1
                            })(function(x53)
                              return Golden_LongExceptBind_Test_bind({
                                "Data.Either∷Either.Right",
                                x53 + 1
                              })(function(x54)
                                return Golden_LongExceptBind_Test_bind({
                                  "Data.Either∷Either.Right",
                                  x54 + 1
                                })(function(x55)
                                  return Golden_LongExceptBind_Test_bind({
                                    "Data.Either∷Either.Right",
                                    x55 + 1
                                  })(function(x56)
                                    return Golden_LongExceptBind_Test_bind({
                                      "Data.Either∷Either.Right",
                                      x56 + 1
                                    })(function(x57)
                                      return Golden_LongExceptBind_Test_bind({
                                        "Data.Either∷Either.Right",
                                        x57 + 1
                                      })(function(x58)
                                        return Golden_LongExceptBind_Test_bind({
                                          "Data.Either∷Either.Right",
                                          x58 + 1
                                        })(function(x59)
                                          return Golden_LongExceptBind_Test_bind({
                                            "Data.Either∷Either.Right",
                                            x59 + 1
                                          })(function(x60)
                                            return Golden_LongExceptBind_Test_bind({
                                              "Data.Either∷Either.Right",
                                              x60 + 1
                                            })(function(x61)
                                              return Golden_LongExceptBind_Test_bind({
                                                "Data.Either∷Either.Right",
                                                x61 + 1
                                              })(function(x62)
                                                return Golden_LongExceptBind_Test_bind({
                                                  "Data.Either∷Either.Right",
                                                  x62 + 1
                                                })(function(x63)
                                                  return Golden_LongExceptBind_Test_bind({
                                                    "Data.Either∷Either.Right",
                                                    x63 + 1
                                                  })(function(x64)
                                                    return Golden_LongExceptBind_Test_bind({
                                                      "Data.Either∷Either.Right",
                                                      x64 + 1
                                                    })(function(x65)
                                                      return Golden_LongExceptBind_Test_bind({
                                                        "Data.Either∷Either.Right",
                                                        x65 + 1
                                                      })(function(x66)
                                                        return Golden_LongExceptBind_Test_bind({
                                                          "Data.Either∷Either.Right",
                                                          x66 + 1
                                                        })(function(x67)
                                                          return Golden_LongExceptBind_Test_bind({
                                                            "Data.Either∷Either.Right",
                                                            x67 + 1
                                                          })(function(x68)
                                                            return Golden_LongExceptBind_Test_bind({
                                                              "Data.Either∷Either.Right",
                                                              x68 + 1
                                                            })(function(x69)
                                                              return Golden_LongExceptBind_Test_bind({
                                                                "Data.Either∷Either.Right",
                                                                x69 + 1
                                                              })(function(x70)
                                                                return Golden_LongExceptBind_Test_bind({
                                                                  "Data.Either∷Either.Right",
                                                                  x70 + 1
                                                                })(function(x71)
                                                                  return Golden_LongExceptBind_Test_bind({
                                                                    "Data.Either∷Either.Right",
                                                                    x71 + 1
                                                                  })(function( x72 )
                                                                    return Golden_LongExceptBind_Test_bind({
                                                                      "Data.Either∷Either.Right",
                                                                      x72 + 1
                                                                    })(function( x73 )
                                                                      return Golden_LongExceptBind_Test_bind({
                                                                        "Data.Either∷Either.Right",
                                                                        x73 + 1
                                                                      })(function( x74 )
                                                                        return Golden_LongExceptBind_Test_bind({
                                                                          "Data.Either∷Either.Right",
                                                                          x74 + 1
                                                                        })(function( x75 )
                                                                          return Golden_LongExceptBind_Test_bind({
                                                                            "Data.Either∷Either.Right",
                                                                            x75 + 1
                                                                          })(function( x76 )
                                                                            return Golden_LongExceptBind_Test_bind({
                                                                              "Data.Either∷Either.Right",
                                                                              x76 + 1
                                                                            })(function( x77 )
                                                                              return Golden_LongExceptBind_Test_bind({
                                                                                "Data.Either∷Either.Right",
                                                                                x77 + 1
                                                                              })(function( x78 )
                                                                                return Golden_LongExceptBind_Test_bind({
                                                                                  "Data.Either∷Either.Right",
                                                                                  x78 + 1
                                                                                })(function( x79 )
                                                                                  return Golden_LongExceptBind_Test_bind({
                                                                                    "Data.Either∷Either.Right",
                                                                                    x79 + 1
                                                                                  })(function( x80 )
                                                                                    return _S_kont1422_S_w(x1_S_1426, x80)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  return Golden_LongExceptBind_Test_bind({
    "Data.Either∷Either.Right",
    1
  })(function(x1)
    return Golden_LongExceptBind_Test_bind({
      "Data.Either∷Either.Right",
      x1 + 1
    })(function(x2)
      return Golden_LongExceptBind_Test_bind({
        "Data.Either∷Either.Right",
        x2 + 1
      })(function(x3)
        return Golden_LongExceptBind_Test_bind({
          "Data.Either∷Either.Right",
          x3 + 1
        })(function(x4)
          return Golden_LongExceptBind_Test_bind({
            "Data.Either∷Either.Right",
            x4 + 1
          })(function(x5)
            return Golden_LongExceptBind_Test_bind({
              "Data.Either∷Either.Right",
              x5 + 1
            })(function(x6)
              return Golden_LongExceptBind_Test_bind({
                "Data.Either∷Either.Right",
                x6 + 1
              })(function(x7)
                return Golden_LongExceptBind_Test_bind({
                  "Data.Either∷Either.Right",
                  x7 + 1
                })(function(x8)
                  return Golden_LongExceptBind_Test_bind({
                    "Data.Either∷Either.Right",
                    x8 + 1
                  })(function(x9)
                    return Golden_LongExceptBind_Test_bind({
                      "Data.Either∷Either.Right",
                      x9 + 1
                    })(function(x10)
                      return Golden_LongExceptBind_Test_bind({
                        "Data.Either∷Either.Right",
                        x10 + 1
                      })(function(x11)
                        return Golden_LongExceptBind_Test_bind({
                          "Data.Either∷Either.Right",
                          x11 + 1
                        })(function(x12)
                          return Golden_LongExceptBind_Test_bind({
                            "Data.Either∷Either.Right",
                            x12 + 1
                          })(function(x13)
                            return Golden_LongExceptBind_Test_bind({
                              "Data.Either∷Either.Right",
                              x13 + 1
                            })(function(x14)
                              return Golden_LongExceptBind_Test_bind({
                                "Data.Either∷Either.Right",
                                x14 + 1
                              })(function(x15)
                                return Golden_LongExceptBind_Test_bind({
                                  "Data.Either∷Either.Right",
                                  x15 + 1
                                })(function(x16)
                                  return Golden_LongExceptBind_Test_bind({
                                    "Data.Either∷Either.Right",
                                    x16 + 1
                                  })(function(x17)
                                    return Golden_LongExceptBind_Test_bind({
                                      "Data.Either∷Either.Right",
                                      x17 + 1
                                    })(function(x18)
                                      return Golden_LongExceptBind_Test_bind({
                                        "Data.Either∷Either.Right",
                                        x18 + 1
                                      })(function(x19)
                                        return Golden_LongExceptBind_Test_bind({
                                          "Data.Either∷Either.Right",
                                          x19 + 1
                                        })(function(x20)
                                          return Golden_LongExceptBind_Test_bind({
                                            "Data.Either∷Either.Right",
                                            x20 + 1
                                          })(function(x21)
                                            return Golden_LongExceptBind_Test_bind({
                                              "Data.Either∷Either.Right",
                                              x21 + 1
                                            })(function(x22)
                                              return Golden_LongExceptBind_Test_bind({
                                                "Data.Either∷Either.Right",
                                                x22 + 1
                                              })(function(x23)
                                                return Golden_LongExceptBind_Test_bind({
                                                  "Data.Either∷Either.Right",
                                                  x23 + 1
                                                })(function(x24)
                                                  return Golden_LongExceptBind_Test_bind({
                                                    "Data.Either∷Either.Right",
                                                    x24 + 1
                                                  })(function(x25)
                                                    return Golden_LongExceptBind_Test_bind({
                                                      "Data.Either∷Either.Right",
                                                      x25 + 1
                                                    })(function(x26)
                                                      return Golden_LongExceptBind_Test_bind({
                                                        "Data.Either∷Either.Right",
                                                        x26 + 1
                                                      })(function(x27)
                                                        return Golden_LongExceptBind_Test_bind({
                                                          "Data.Either∷Either.Right",
                                                          x27 + 1
                                                        })(function(x28)
                                                          return Golden_LongExceptBind_Test_bind({
                                                            "Data.Either∷Either.Right",
                                                            x28 + 1
                                                          })(function(x29)
                                                            return Golden_LongExceptBind_Test_bind({
                                                              "Data.Either∷Either.Right",
                                                              x29 + 1
                                                            })(function(x30)
                                                              return Golden_LongExceptBind_Test_bind({
                                                                "Data.Either∷Either.Right",
                                                                x30 + 1
                                                              })(function(x31)
                                                                return Golden_LongExceptBind_Test_bind({
                                                                  "Data.Either∷Either.Right",
                                                                  x31 + 1
                                                                })(function(x32)
                                                                  return Golden_LongExceptBind_Test_bind({
                                                                    "Data.Either∷Either.Right",
                                                                    x32 + 1
                                                                  })(function( x33 )
                                                                    return Golden_LongExceptBind_Test_bind({
                                                                      "Data.Either∷Either.Right",
                                                                      x33 + 1
                                                                    })(function( x34 )
                                                                      return Golden_LongExceptBind_Test_bind({
                                                                        "Data.Either∷Either.Right",
                                                                        x34 + 1
                                                                      })(function( x35 )
                                                                        return Golden_LongExceptBind_Test_bind({
                                                                          "Data.Either∷Either.Right",
                                                                          x35 + 1
                                                                        })(function( x36 )
                                                                          return Golden_LongExceptBind_Test_bind({
                                                                            "Data.Either∷Either.Right",
                                                                            x36 + 1
                                                                          })(function( x37 )
                                                                            return Golden_LongExceptBind_Test_bind({
                                                                              "Data.Either∷Either.Right",
                                                                              x37 + 1
                                                                            })(function( x38 )
                                                                              return Golden_LongExceptBind_Test_bind({
                                                                                "Data.Either∷Either.Right",
                                                                                x38 + 1
                                                                              })(function( x39 )
                                                                                return Golden_LongExceptBind_Test_bind({
                                                                                  "Data.Either∷Either.Right",
                                                                                  x39 + 1
                                                                                })(function( x40 )
                                                                                  return _S_kont1425_S_w(x1, x40)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
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
  local _S_cse1415 = Golden_LongExceptBind_Test_compute[2]
  local _S_cse1414 = Golden_LongExceptBind_Test_compute[1]
  return Effect_Console_foreign.log((function()
    if "Data.Either∷Either.Left" == _S_cse1414 then
      return "(Left " .. Data_Show_foreign.showStringImpl(_S_cse1415) .. ")"
    elseif "Data.Either∷Either.Right" == _S_cse1414 then
      return "(Right " .. Data_Show_foreign.showIntImpl(_S_cse1415) .. ")"
    else
      return error("No patterns matched")
    end
  end)())
end)()()
