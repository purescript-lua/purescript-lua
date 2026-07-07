local M = {}
M.Data_Unit_foreign = { unit = {} }
M.Data_Semigroup_foreign = {
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
M.Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
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
M.Data_Semigroup_semigroupArray = {
  append = M.Data_Semigroup_foreign.concatArray
}
M.Data_Semigroup_append = function(dict) return dict.append end
M.Data_Functor_map = function(dict) return dict.map end
M.Control_Applicative_pure = function(dict) return dict.pure end
M.Control_Bind_bind = function(dict) return dict.bind end
M.Data_Monoid_monoidArray = {
  mempty = {},
  Semigroup0 = function() return M.Data_Semigroup_semigroupArray end
}
M.Data_Tuple_Tuple = function(value0)
  return function(value1) return { value0 = value0, value1 = value1 } end
end
M.Data_Identity_applyIdentity = {
  apply = function(v) return function(v1) return v(v1) end end,
  Functor0 = function()
    return {
      map = function(f_S_468)
        return function(m_S_469) return f_S_468(m_S_469) end
      end
    }
  end
}
M.Data_Identity_bindIdentity = {
  bind = function(v) return function(f) return f(v) end end,
  Apply0 = function() return M.Data_Identity_applyIdentity end
}
M.Data_Identity_applicativeIdentity = {
  pure = function(x_S_470) return x_S_470 end,
  Apply0 = function() return M.Data_Identity_applyIdentity end
}
M.Control_Monad_Writer_Trans_compose = M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)
M.Control_Monad_Writer_Trans_applyWriterT = function(dictSemigroup)
  return function(dictApply)
    local Functor0 = dictApply.Functor0()
    return {
      apply = function(v)
        return function(v1)
          return dictApply.apply(M.Data_Functor_map(Functor0)(function(v3_S_33)
            return function(v4_S_34)
              return M.Data_Tuple_Tuple(v3_S_33.value0(v4_S_34.value0))(M.Data_Semigroup_append(dictSemigroup)(v3_S_33.value1)(v4_S_34.value1))
            end
          end)(v))(v1)
        end
      end,
      Functor0 = function()
        return {
          map = function(f_S_463)
            return function(v_S_466)
              return M.Data_Functor_map(Functor0)(function(v_S_464)
                return M.Data_Tuple_Tuple(f_S_463(v_S_464.value0))(v_S_464.value1)
              end)(v_S_466)
            end
          end
        }
      end
    }
  end
end
M.Control_Monad_Writer_Trans_bindWriterT = function(dictSemigroup)
  return function(dictBind)
    local Apply0 = dictBind.Apply0()
    return {
      bind = function(v)
        return function(k)
          return M.Control_Bind_bind(dictBind)(v)(function(v1)
            return M.Data_Functor_map(Apply0.Functor0())(function(v3)
              return M.Data_Tuple_Tuple(v3.value0)(M.Data_Semigroup_append(dictSemigroup)(v1.value1)(v3.value1))
            end)(k(v1.value0))
          end)
        end
      end,
      Apply0 = function()
        return M.Control_Monad_Writer_Trans_applyWriterT(dictSemigroup)(Apply0)
      end
    }
  end
end
M.Control_Monad_Writer_Trans_applicativeWriterT = function(dictMonoid)
  return function(dictApplicative)
    return {
      pure = function(a)
        return M.Control_Applicative_pure(dictApplicative)(M.Data_Tuple_Tuple(a)(dictMonoid.mempty))
      end,
      Apply0 = function()
        return M.Control_Monad_Writer_Trans_applyWriterT(dictMonoid.Semigroup0())(dictApplicative.Apply0())
      end
    }
  end
end
M.Golden_LongWriterBind_Test_discard = M.Control_Bind_bind(M.Control_Monad_Writer_Trans_bindWriterT(M.Data_Semigroup_semigroupArray)(M.Data_Identity_bindIdentity))
M.Golden_LongWriterBind_Test_tell = (function()
  local dictMonad_S_478 = {
    Applicative0 = function() return M.Data_Identity_applicativeIdentity end,
    Bind1 = function() return M.Data_Identity_bindIdentity end
  }
  return M.Control_Monad_Writer_Trans_compose(function(x_S_467_S_479)
    return x_S_467_S_479
  end)(M.Control_Monad_Writer_Trans_compose(M.Control_Applicative_pure(dictMonad_S_478.Applicative0()))(M.Data_Tuple_Tuple(M.Data_Unit_foreign.unit)))
end)()
M.Golden_LongWriterBind_Test_go = (function()
  local _S_kont482 = M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
    [1] = 161
  }))(function()
    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
      [1] = 162
    }))(function()
      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
        [1] = 163
      }))(function()
        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
          [1] = 164
        }))(function()
          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
            [1] = 165
          }))(function()
            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
              [1] = 166
            }))(function()
              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                [1] = 167
              }))(function()
                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                  [1] = 168
                }))(function()
                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                    [1] = 169
                  }))(function()
                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                      [1] = 170
                    }))(function()
                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                        [1] = 171
                      }))(function()
                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                          [1] = 172
                        }))(function()
                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                            [1] = 173
                          }))(function()
                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                              [1] = 174
                            }))(function()
                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                [1] = 175
                              }))(function()
                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                  [1] = 176
                                }))(function()
                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                    [1] = 177
                                  }))(function()
                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                      [1] = 178
                                    }))(function()
                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                        [1] = 179
                                      }))(function()
                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                          [1] = 180
                                        }))(function()
                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                            [1] = 181
                                          }))(function()
                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                              [1] = 182
                                            }))(function()
                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                [1] = 183
                                              }))(function()
                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                  [1] = 184
                                                }))(function()
                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                    [1] = 185
                                                  }))(function()
                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                      [1] = 186
                                                    }))(function()
                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                        [1] = 187
                                                      }))(function()
                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                          [1] = 188
                                                        }))(function()
                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                            [1] = 189
                                                          }))(function()
                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                              [1] = 190
                                                            }))(function()
                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                [1] = 191
                                                              }))(function()
                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                  [1] = 192
                                                                }))(function()
                                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                    [1] = 193
                                                                  }))(function()
                                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                      [1] = 194
                                                                    }))(function(  )
                                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                        [1] = 195
                                                                      }))(function(  )
                                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                          [1] = 196
                                                                        }))(function(  )
                                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                            [1] = 197
                                                                          }))(function(  )
                                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                              [1] = 198
                                                                            }))(function(  )
                                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                [1] = 199
                                                                              }))(function(  )
                                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                  [1] = 200
                                                                                }))(function(  )
                                                                                  return M.Control_Applicative_pure(M.Control_Monad_Writer_Trans_applicativeWriterT(M.Data_Monoid_monoidArray)(M.Data_Identity_applicativeIdentity))(42)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  local _S_kont483 = M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
    [1] = 121
  }))(function()
    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
      [1] = 122
    }))(function()
      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
        [1] = 123
      }))(function()
        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
          [1] = 124
        }))(function()
          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
            [1] = 125
          }))(function()
            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
              [1] = 126
            }))(function()
              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                [1] = 127
              }))(function()
                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                  [1] = 128
                }))(function()
                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                    [1] = 129
                  }))(function()
                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                      [1] = 130
                    }))(function()
                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                        [1] = 131
                      }))(function()
                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                          [1] = 132
                        }))(function()
                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                            [1] = 133
                          }))(function()
                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                              [1] = 134
                            }))(function()
                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                [1] = 135
                              }))(function()
                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                  [1] = 136
                                }))(function()
                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                    [1] = 137
                                  }))(function()
                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                      [1] = 138
                                    }))(function()
                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                        [1] = 139
                                      }))(function()
                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                          [1] = 140
                                        }))(function()
                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                            [1] = 141
                                          }))(function()
                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                              [1] = 142
                                            }))(function()
                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                [1] = 143
                                              }))(function()
                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                  [1] = 144
                                                }))(function()
                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                    [1] = 145
                                                  }))(function()
                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                      [1] = 146
                                                    }))(function()
                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                        [1] = 147
                                                      }))(function()
                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                          [1] = 148
                                                        }))(function()
                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                            [1] = 149
                                                          }))(function()
                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                              [1] = 150
                                                            }))(function()
                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                [1] = 151
                                                              }))(function()
                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                  [1] = 152
                                                                }))(function()
                                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                    [1] = 153
                                                                  }))(function()
                                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                      [1] = 154
                                                                    }))(function(  )
                                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                        [1] = 155
                                                                      }))(function(  )
                                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                          [1] = 156
                                                                        }))(function(  )
                                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                            [1] = 157
                                                                          }))(function(  )
                                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                              [1] = 158
                                                                            }))(function(  )
                                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                [1] = 159
                                                                              }))(function(  )
                                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                  [1] = 160
                                                                                }))(function(  )
                                                                                  return _S_kont482
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  local _S_kont484 = M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
    [1] = 81
  }))(function()
    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
      [1] = 82
    }))(function()
      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
        [1] = 83
      }))(function()
        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
          [1] = 84
        }))(function()
          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
            [1] = 85
          }))(function()
            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
              [1] = 86
            }))(function()
              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                [1] = 87
              }))(function()
                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                  [1] = 88
                }))(function()
                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                    [1] = 89
                  }))(function()
                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                      [1] = 90
                    }))(function()
                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                        [1] = 91
                      }))(function()
                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                          [1] = 92
                        }))(function()
                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                            [1] = 93
                          }))(function()
                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                              [1] = 94
                            }))(function()
                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                [1] = 95
                              }))(function()
                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                  [1] = 96
                                }))(function()
                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                    [1] = 97
                                  }))(function()
                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                      [1] = 98
                                    }))(function()
                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                        [1] = 99
                                      }))(function()
                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                          [1] = 100
                                        }))(function()
                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                            [1] = 101
                                          }))(function()
                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                              [1] = 102
                                            }))(function()
                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                [1] = 103
                                              }))(function()
                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                  [1] = 104
                                                }))(function()
                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                    [1] = 105
                                                  }))(function()
                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                      [1] = 106
                                                    }))(function()
                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                        [1] = 107
                                                      }))(function()
                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                          [1] = 108
                                                        }))(function()
                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                            [1] = 109
                                                          }))(function()
                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                              [1] = 110
                                                            }))(function()
                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                [1] = 111
                                                              }))(function()
                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                  [1] = 112
                                                                }))(function()
                                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                    [1] = 113
                                                                  }))(function()
                                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                      [1] = 114
                                                                    }))(function(  )
                                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                        [1] = 115
                                                                      }))(function(  )
                                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                          [1] = 116
                                                                        }))(function(  )
                                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                            [1] = 117
                                                                          }))(function(  )
                                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                              [1] = 118
                                                                            }))(function(  )
                                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                [1] = 119
                                                                              }))(function(  )
                                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                  [1] = 120
                                                                                }))(function(  )
                                                                                  return _S_kont483
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  local _S_kont485 = M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
    [1] = 41
  }))(function()
    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
      [1] = 42
    }))(function()
      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
        [1] = 43
      }))(function()
        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
          [1] = 44
        }))(function()
          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
            [1] = 45
          }))(function()
            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
              [1] = 46
            }))(function()
              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                [1] = 47
              }))(function()
                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                  [1] = 48
                }))(function()
                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                    [1] = 49
                  }))(function()
                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                      [1] = 50
                    }))(function()
                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                        [1] = 51
                      }))(function()
                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                          [1] = 52
                        }))(function()
                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                            [1] = 53
                          }))(function()
                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                              [1] = 54
                            }))(function()
                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                [1] = 55
                              }))(function()
                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                  [1] = 56
                                }))(function()
                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                    [1] = 57
                                  }))(function()
                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                      [1] = 58
                                    }))(function()
                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                        [1] = 59
                                      }))(function()
                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                          [1] = 60
                                        }))(function()
                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                            [1] = 61
                                          }))(function()
                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                              [1] = 62
                                            }))(function()
                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                [1] = 63
                                              }))(function()
                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                  [1] = 64
                                                }))(function()
                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                    [1] = 65
                                                  }))(function()
                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                      [1] = 66
                                                    }))(function()
                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                        [1] = 67
                                                      }))(function()
                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                          [1] = 68
                                                        }))(function()
                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                            [1] = 69
                                                          }))(function()
                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                              [1] = 70
                                                            }))(function()
                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                [1] = 71
                                                              }))(function()
                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                  [1] = 72
                                                                }))(function()
                                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                    [1] = 73
                                                                  }))(function()
                                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                      [1] = 74
                                                                    }))(function(  )
                                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                        [1] = 75
                                                                      }))(function(  )
                                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                          [1] = 76
                                                                        }))(function(  )
                                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                            [1] = 77
                                                                          }))(function(  )
                                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                              [1] = 78
                                                                            }))(function(  )
                                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                [1] = 79
                                                                              }))(function(  )
                                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                  [1] = 80
                                                                                }))(function(  )
                                                                                  return _S_kont484
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
    [1] = 1
  }))(function()
    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
      [1] = 2
    }))(function()
      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
        [1] = 3
      }))(function()
        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
          [1] = 4
        }))(function()
          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
            [1] = 5
          }))(function()
            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
              [1] = 6
            }))(function()
              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                [1] = 7
              }))(function()
                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                  [1] = 8
                }))(function()
                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                    [1] = 9
                  }))(function()
                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                      [1] = 10
                    }))(function()
                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                        [1] = 11
                      }))(function()
                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                          [1] = 12
                        }))(function()
                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                            [1] = 13
                          }))(function()
                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                              [1] = 14
                            }))(function()
                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                [1] = 15
                              }))(function()
                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                  [1] = 16
                                }))(function()
                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                    [1] = 17
                                  }))(function()
                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                      [1] = 18
                                    }))(function()
                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                        [1] = 19
                                      }))(function()
                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                          [1] = 20
                                        }))(function()
                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                            [1] = 21
                                          }))(function()
                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                              [1] = 22
                                            }))(function()
                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                [1] = 23
                                              }))(function()
                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                  [1] = 24
                                                }))(function()
                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                    [1] = 25
                                                  }))(function()
                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                      [1] = 26
                                                    }))(function()
                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                        [1] = 27
                                                      }))(function()
                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                          [1] = 28
                                                        }))(function()
                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                            [1] = 29
                                                          }))(function()
                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                              [1] = 30
                                                            }))(function()
                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                [1] = 31
                                                              }))(function()
                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                  [1] = 32
                                                                }))(function()
                                                                  return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                    [1] = 33
                                                                  }))(function()
                                                                    return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                      [1] = 34
                                                                    }))(function(  )
                                                                      return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                        [1] = 35
                                                                      }))(function(  )
                                                                        return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                          [1] = 36
                                                                        }))(function(  )
                                                                          return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                            [1] = 37
                                                                          }))(function(  )
                                                                            return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                              [1] = 38
                                                                            }))(function(  )
                                                                              return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                [1] = 39
                                                                              }))(function(  )
                                                                                return M.Golden_LongWriterBind_Test_discard(M.Golden_LongWriterBind_Test_tell({
                                                                                  [1] = 40
                                                                                }))(function(  )
                                                                                  return _S_kont485
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
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
M.Golden_LongWriterBind_Test_compute = (M.Control_Semigroupoid_compose(M.Control_Semigroupoid_semigroupoidFn)(M.Unsafe_Coerce_foreign.unsafeCoerce)(function( v_S_39_S_461 )
  return v_S_39_S_461
end)(M.Golden_LongWriterBind_Test_go)).value0
return M.Effect_Console_foreign.log(M.Data_Show_foreign.showIntImpl(M.Golden_LongWriterBind_Test_compute))()
