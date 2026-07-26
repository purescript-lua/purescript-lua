local M = {}
local Data_Unit_foreign = { unit = {} }
local Data_Unit_unit = Data_Unit_foreign.unit
local Data_Semigroup_foreign = {
  concatArray = function(xs)
    return function(ys)
      if #(xs) == 0 then return ys end
      if #(ys) == 0 then return xs end
      local result = {}
      for index, value in ipairs(xs) do result[index] = value end
      local offset = #(result)
      for index, value in ipairs(ys) do result[index + offset] = value end
      return result
    end
  end
}
local Data_Semigroup_concatArray = Data_Semigroup_foreign.concatArray
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Semigroup_semigroupArray = { append = Data_Semigroup_concatArray }
local Data_Tuple_Tuple_S_w = function(value0, value1)
  return { value0, value1 }
end
local Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function()
    return {
      map = function(f_S_0) return function(m_S_0) return f_S_0(m_S_0) end end
    }
  end
}
local Data_Identity_applicativeIdentity = {
  pure = function(x_S_0) return x_S_0 end,
  Apply0 = function() return Data_Identity_applyIdentity end
}
M.Control_Monad_Writer_Trans_applyWriterT_S_w = function( dictSemigroup
, dictApply )
  local Functor0 = dictApply.Functor0()
  return {
    apply = function(v)
      return function(v1)
        return dictApply.apply(Functor0.map(function(v3_S_0)
          return function(v4_S_0)
            return Data_Tuple_Tuple_S_w(v3_S_0[1](v4_S_0[1]), dictSemigroup.append(v3_S_0[2])(v4_S_0[2]))
          end
        end)(v))(v1)
      end
    end,
    Functor0 = function()
      return {
        map = function(f_S_1)
          return function(v_S_0)
            return Functor0.map(function(v_S_1)
              return Data_Tuple_Tuple_S_w(f_S_1(v_S_1[1]), v_S_1[2])
            end)(v_S_0)
          end
        end
      }
    end
  }
end
local Golden_LongWriterBind_Test_discard = (function()
  local dictBind_S_0 = {
    bind = function(v_S_2) return function(f_S_2) return f_S_2(v_S_2) end end,
    Apply0 = function() return Data_Identity_applyIdentity end
  }
  return function(v_S_3)
    return function(k_S_0)
      return dictBind_S_0.bind(v_S_3)(function(v1_S_0)
        return ((dictBind_S_0.Apply0()).Functor0()).map(function(v3_S_1)
          return Data_Tuple_Tuple_S_w(v3_S_1[1], Data_Semigroup_concatArray(v1_S_0[2])(v3_S_1[2]))
        end)(k_S_0(v1_S_0[1]))
      end)
    end
  end
end)()
local Golden_LongWriterBind_Test_go = (function()
  local _S_kont0 = Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
    [1] = 161
  }))(function()
    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
      [1] = 162
    }))(function()
      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
        [1] = 163
      }))(function()
        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
          [1] = 164
        }))(function()
          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
            [1] = 165
          }))(function()
            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
              [1] = 166
            }))(function()
              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                [1] = 167
              }))(function()
                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                  [1] = 168
                }))(function()
                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                    [1] = 169
                  }))(function()
                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                      [1] = 170
                    }))(function()
                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                        [1] = 171
                      }))(function()
                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                          [1] = 172
                        }))(function()
                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                            [1] = 173
                          }))(function()
                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                              [1] = 174
                            }))(function()
                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                [1] = 175
                              }))(function()
                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                  [1] = 176
                                }))(function()
                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                    [1] = 177
                                  }))(function()
                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                      [1] = 178
                                    }))(function()
                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                        [1] = 179
                                      }))(function()
                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                          [1] = 180
                                        }))(function()
                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                            [1] = 181
                                          }))(function()
                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                              [1] = 182
                                            }))(function()
                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                [1] = 183
                                              }))(function()
                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                  [1] = 184
                                                }))(function()
                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                    [1] = 185
                                                  }))(function()
                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                      [1] = 186
                                                    }))(function()
                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                        [1] = 187
                                                      }))(function()
                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                          [1] = 188
                                                        }))(function()
                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                            [1] = 189
                                                          }))(function()
                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                              [1] = 190
                                                            }))(function()
                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                [1] = 191
                                                              }))(function()
                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                  [1] = 192
                                                                }))(function()
                                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                    [1] = 193
                                                                  }))(function()
                                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                      [1] = 194
                                                                    }))(function(  )
                                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                        [1] = 195
                                                                      }))(function(  )
                                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                          [1] = 196
                                                                        }))(function(  )
                                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                            [1] = 197
                                                                          }))(function(  )
                                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                              [1] = 198
                                                                            }))(function(  )
                                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                [1] = 199
                                                                              }))(function(  )
                                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                  [1] = 200
                                                                                }))(function(  )
                                                                                  local dictMonoid_S_0 = {
                                                                                    mempty = {},
                                                                                    Semigroup0 = function(  )
                                                                                      return Data_Semigroup_semigroupArray
                                                                                    end
                                                                                  }
                                                                                  local dictApplicative_S_0 = Data_Identity_applicativeIdentity
                                                                                  local a_S_0 = 42
                                                                                  return dictApplicative_S_0.pure(Data_Tuple_Tuple_S_w(a_S_0, dictMonoid_S_0.mempty))
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  local _S_kont1 = Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
    [1] = 121
  }))(function()
    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
      [1] = 122
    }))(function()
      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
        [1] = 123
      }))(function()
        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
          [1] = 124
        }))(function()
          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
            [1] = 125
          }))(function()
            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
              [1] = 126
            }))(function()
              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                [1] = 127
              }))(function()
                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                  [1] = 128
                }))(function()
                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                    [1] = 129
                  }))(function()
                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                      [1] = 130
                    }))(function()
                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                        [1] = 131
                      }))(function()
                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                          [1] = 132
                        }))(function()
                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                            [1] = 133
                          }))(function()
                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                              [1] = 134
                            }))(function()
                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                [1] = 135
                              }))(function()
                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                  [1] = 136
                                }))(function()
                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                    [1] = 137
                                  }))(function()
                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                      [1] = 138
                                    }))(function()
                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                        [1] = 139
                                      }))(function()
                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                          [1] = 140
                                        }))(function()
                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                            [1] = 141
                                          }))(function()
                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                              [1] = 142
                                            }))(function()
                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                [1] = 143
                                              }))(function()
                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                  [1] = 144
                                                }))(function()
                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                    [1] = 145
                                                  }))(function()
                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                      [1] = 146
                                                    }))(function()
                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                        [1] = 147
                                                      }))(function()
                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                          [1] = 148
                                                        }))(function()
                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                            [1] = 149
                                                          }))(function()
                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                              [1] = 150
                                                            }))(function()
                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                [1] = 151
                                                              }))(function()
                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                  [1] = 152
                                                                }))(function()
                                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                    [1] = 153
                                                                  }))(function()
                                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                      [1] = 154
                                                                    }))(function(  )
                                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                        [1] = 155
                                                                      }))(function(  )
                                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                          [1] = 156
                                                                        }))(function(  )
                                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                            [1] = 157
                                                                          }))(function(  )
                                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                              [1] = 158
                                                                            }))(function(  )
                                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                [1] = 159
                                                                              }))(function(  )
                                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                  [1] = 160
                                                                                }))(function(  )
                                                                                  return _S_kont0
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  local _S_kont2 = Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
    [1] = 81
  }))(function()
    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
      [1] = 82
    }))(function()
      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
        [1] = 83
      }))(function()
        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
          [1] = 84
        }))(function()
          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
            [1] = 85
          }))(function()
            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
              [1] = 86
            }))(function()
              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                [1] = 87
              }))(function()
                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                  [1] = 88
                }))(function()
                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                    [1] = 89
                  }))(function()
                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                      [1] = 90
                    }))(function()
                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                        [1] = 91
                      }))(function()
                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                          [1] = 92
                        }))(function()
                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                            [1] = 93
                          }))(function()
                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                              [1] = 94
                            }))(function()
                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                [1] = 95
                              }))(function()
                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                  [1] = 96
                                }))(function()
                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                    [1] = 97
                                  }))(function()
                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                      [1] = 98
                                    }))(function()
                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                        [1] = 99
                                      }))(function()
                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                          [1] = 100
                                        }))(function()
                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                            [1] = 101
                                          }))(function()
                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                              [1] = 102
                                            }))(function()
                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                [1] = 103
                                              }))(function()
                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                  [1] = 104
                                                }))(function()
                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                    [1] = 105
                                                  }))(function()
                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                      [1] = 106
                                                    }))(function()
                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                        [1] = 107
                                                      }))(function()
                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                          [1] = 108
                                                        }))(function()
                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                            [1] = 109
                                                          }))(function()
                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                              [1] = 110
                                                            }))(function()
                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                [1] = 111
                                                              }))(function()
                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                  [1] = 112
                                                                }))(function()
                                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                    [1] = 113
                                                                  }))(function()
                                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                      [1] = 114
                                                                    }))(function(  )
                                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                        [1] = 115
                                                                      }))(function(  )
                                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                          [1] = 116
                                                                        }))(function(  )
                                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                            [1] = 117
                                                                          }))(function(  )
                                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                              [1] = 118
                                                                            }))(function(  )
                                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                [1] = 119
                                                                              }))(function(  )
                                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                  [1] = 120
                                                                                }))(function(  )
                                                                                  return _S_kont1
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  local _S_kont3 = Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
    [1] = 41
  }))(function()
    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
      [1] = 42
    }))(function()
      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
        [1] = 43
      }))(function()
        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
          [1] = 44
        }))(function()
          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
            [1] = 45
          }))(function()
            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
              [1] = 46
            }))(function()
              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                [1] = 47
              }))(function()
                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                  [1] = 48
                }))(function()
                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                    [1] = 49
                  }))(function()
                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                      [1] = 50
                    }))(function()
                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                        [1] = 51
                      }))(function()
                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                          [1] = 52
                        }))(function()
                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                            [1] = 53
                          }))(function()
                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                              [1] = 54
                            }))(function()
                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                [1] = 55
                              }))(function()
                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                  [1] = 56
                                }))(function()
                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                    [1] = 57
                                  }))(function()
                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                      [1] = 58
                                    }))(function()
                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                        [1] = 59
                                      }))(function()
                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                          [1] = 60
                                        }))(function()
                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                            [1] = 61
                                          }))(function()
                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                              [1] = 62
                                            }))(function()
                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                [1] = 63
                                              }))(function()
                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                  [1] = 64
                                                }))(function()
                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                    [1] = 65
                                                  }))(function()
                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                      [1] = 66
                                                    }))(function()
                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                        [1] = 67
                                                      }))(function()
                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                          [1] = 68
                                                        }))(function()
                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                            [1] = 69
                                                          }))(function()
                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                              [1] = 70
                                                            }))(function()
                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                [1] = 71
                                                              }))(function()
                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                  [1] = 72
                                                                }))(function()
                                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                    [1] = 73
                                                                  }))(function()
                                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                      [1] = 74
                                                                    }))(function(  )
                                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                        [1] = 75
                                                                      }))(function(  )
                                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                          [1] = 76
                                                                        }))(function(  )
                                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                            [1] = 77
                                                                          }))(function(  )
                                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                              [1] = 78
                                                                            }))(function(  )
                                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                [1] = 79
                                                                              }))(function(  )
                                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                  [1] = 80
                                                                                }))(function(  )
                                                                                  return _S_kont2
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
    [1] = 1
  }))(function()
    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
      [1] = 2
    }))(function()
      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
        [1] = 3
      }))(function()
        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
          [1] = 4
        }))(function()
          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
            [1] = 5
          }))(function()
            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
              [1] = 6
            }))(function()
              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                [1] = 7
              }))(function()
                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                  [1] = 8
                }))(function()
                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                    [1] = 9
                  }))(function()
                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                      [1] = 10
                    }))(function()
                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                        [1] = 11
                      }))(function()
                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                          [1] = 12
                        }))(function()
                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                            [1] = 13
                          }))(function()
                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                              [1] = 14
                            }))(function()
                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                [1] = 15
                              }))(function()
                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                  [1] = 16
                                }))(function()
                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                    [1] = 17
                                  }))(function()
                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                      [1] = 18
                                    }))(function()
                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                        [1] = 19
                                      }))(function()
                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                          [1] = 20
                                        }))(function()
                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                            [1] = 21
                                          }))(function()
                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                              [1] = 22
                                            }))(function()
                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                [1] = 23
                                              }))(function()
                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                  [1] = 24
                                                }))(function()
                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                    [1] = 25
                                                  }))(function()
                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                      [1] = 26
                                                    }))(function()
                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                        [1] = 27
                                                      }))(function()
                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                          [1] = 28
                                                        }))(function()
                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                            [1] = 29
                                                          }))(function()
                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                              [1] = 30
                                                            }))(function()
                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                [1] = 31
                                                              }))(function()
                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                  [1] = 32
                                                                }))(function()
                                                                  return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                    [1] = 33
                                                                  }))(function()
                                                                    return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                      [1] = 34
                                                                    }))(function(  )
                                                                      return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                        [1] = 35
                                                                      }))(function(  )
                                                                        return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                          [1] = 36
                                                                        }))(function(  )
                                                                          return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                            [1] = 37
                                                                          }))(function(  )
                                                                            return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                              [1] = 38
                                                                            }))(function(  )
                                                                              return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                [1] = 39
                                                                              }))(function(  )
                                                                                return Golden_LongWriterBind_Test_discard(Data_Tuple_Tuple_S_w(Data_Unit_unit, {
                                                                                  [1] = 40
                                                                                }))(function(  )
                                                                                  return _S_kont3
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
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
local Golden_LongWriterBind_Test_compute = Golden_LongWriterBind_Test_go[1]
return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Golden_LongWriterBind_Test_compute))()
