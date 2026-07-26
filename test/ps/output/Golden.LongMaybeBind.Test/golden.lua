local Data_Unit_foreign = { unit = {} }
local Data_Unit_unit = Data_Unit_foreign.unit
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Golden_LongMaybeBind_Test_bind_S_w = function(v_S_306, v1_S_307)
  if "Data.Maybe∷Maybe.Just" == v_S_306[1] then
    return v1_S_307(v_S_306[2])
  else
    return { "Data.Maybe∷Maybe.Nothing" }
  end
end
local Golden_LongMaybeBind_Test_compute = (function()
  local _S_kont1231_S_w = function(x1_S_1232, x277_S_1233)
    return Golden_LongMaybeBind_Test_bind_S_w({
      "Data.Maybe∷Maybe.Just",
      x277_S_1233 + 1
    }, function(x278)
      return Golden_LongMaybeBind_Test_bind_S_w({
        "Data.Maybe∷Maybe.Just",
        x278 + 1
      }, function(x279)
        return Golden_LongMaybeBind_Test_bind_S_w({
          "Data.Maybe∷Maybe.Just",
          x279 + 1
        }, function(x280)
          return Golden_LongMaybeBind_Test_bind_S_w({
            "Data.Maybe∷Maybe.Just",
            x280 + 1
          }, function(x281)
            return Golden_LongMaybeBind_Test_bind_S_w({
              "Data.Maybe∷Maybe.Just",
              x281 + 1
            }, function(x282)
              return Golden_LongMaybeBind_Test_bind_S_w({
                "Data.Maybe∷Maybe.Just",
                x282 + 1
              }, function(x283)
                return Golden_LongMaybeBind_Test_bind_S_w({
                  "Data.Maybe∷Maybe.Just",
                  x283 + 1
                }, function(x284)
                  return Golden_LongMaybeBind_Test_bind_S_w({
                    "Data.Maybe∷Maybe.Just",
                    x284 + 1
                  }, function(x285)
                    return Golden_LongMaybeBind_Test_bind_S_w({
                      "Data.Maybe∷Maybe.Just",
                      x285 + 1
                    }, function(x286)
                      return Golden_LongMaybeBind_Test_bind_S_w({
                        "Data.Maybe∷Maybe.Just",
                        x286 + 1
                      }, function(x287)
                        return Golden_LongMaybeBind_Test_bind_S_w({
                          "Data.Maybe∷Maybe.Just",
                          x287 + 1
                        }, function(x288)
                          return Golden_LongMaybeBind_Test_bind_S_w({
                            "Data.Maybe∷Maybe.Just",
                            x288 + 1
                          }, function(x289)
                            return Golden_LongMaybeBind_Test_bind_S_w({
                              "Data.Maybe∷Maybe.Just",
                              x289 + 1
                            }, function(x290)
                              return Golden_LongMaybeBind_Test_bind_S_w({
                                "Data.Maybe∷Maybe.Just",
                                x290 + 1
                              }, function(x291)
                                return Golden_LongMaybeBind_Test_bind_S_w({
                                  "Data.Maybe∷Maybe.Just",
                                  x291 + 1
                                }, function(x292)
                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                    "Data.Maybe∷Maybe.Just",
                                    x292 + 1
                                  }, function(x293)
                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                      "Data.Maybe∷Maybe.Just",
                                      x293 + 1
                                    }, function(x294)
                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                        "Data.Maybe∷Maybe.Just",
                                        x294 + 1
                                      }, function(x295)
                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                          "Data.Maybe∷Maybe.Just",
                                          x295 + 1
                                        }, function(x296)
                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                            "Data.Maybe∷Maybe.Just",
                                            x296 + 1
                                          }, function(x297)
                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                              "Data.Maybe∷Maybe.Just",
                                              x297 + 1
                                            }, function(x298)
                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                "Data.Maybe∷Maybe.Just",
                                                x298 + 1
                                              }, function(x299)
                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                  "Data.Maybe∷Maybe.Just",
                                                  x299 + 1
                                                }, function(x300)
                                                  return {
                                                    "Data.Maybe∷Maybe.Just",
                                                    x1_S_1232 + x300
                                                  }
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1234_S_w = function(x1_S_1235, x238_S_1236)
    return Golden_LongMaybeBind_Test_bind_S_w({
      "Data.Maybe∷Maybe.Just",
      x238_S_1236 + 1
    }, function(x239)
      return Golden_LongMaybeBind_Test_bind_S_w({
        "Data.Maybe∷Maybe.Just",
        x239 + 1
      }, function(x240)
        return Golden_LongMaybeBind_Test_bind_S_w({
          "Data.Maybe∷Maybe.Just",
          x240 + 1
        }, function(x241)
          return Golden_LongMaybeBind_Test_bind_S_w({
            "Data.Maybe∷Maybe.Just",
            x241 + 1
          }, function(x242)
            return Golden_LongMaybeBind_Test_bind_S_w({
              "Data.Maybe∷Maybe.Just",
              x242 + 1
            }, function(x243)
              return Golden_LongMaybeBind_Test_bind_S_w({
                "Data.Maybe∷Maybe.Just",
                x243 + 1
              }, function(x244)
                return Golden_LongMaybeBind_Test_bind_S_w({
                  "Data.Maybe∷Maybe.Just",
                  x244 + 1
                }, function(x245)
                  return Golden_LongMaybeBind_Test_bind_S_w({
                    "Data.Maybe∷Maybe.Just",
                    x245 + 1
                  }, function(x246)
                    return Golden_LongMaybeBind_Test_bind_S_w({
                      "Data.Maybe∷Maybe.Just",
                      x246 + 1
                    }, function(x247)
                      return Golden_LongMaybeBind_Test_bind_S_w({
                        "Data.Maybe∷Maybe.Just",
                        x247 + 1
                      }, function(x248)
                        return Golden_LongMaybeBind_Test_bind_S_w({
                          "Data.Maybe∷Maybe.Just",
                          x248 + 1
                        }, function(x249)
                          return Golden_LongMaybeBind_Test_bind_S_w({
                            "Data.Maybe∷Maybe.Just",
                            x249 + 1
                          }, function(x250)
                            return Golden_LongMaybeBind_Test_bind_S_w({
                              "Data.Maybe∷Maybe.Just",
                              Data_Unit_unit
                            }, function()
                              return Golden_LongMaybeBind_Test_bind_S_w({
                                "Data.Maybe∷Maybe.Just",
                                x250 + 1
                              }, function(x251)
                                return Golden_LongMaybeBind_Test_bind_S_w({
                                  "Data.Maybe∷Maybe.Just",
                                  x251 + 1
                                }, function(x252)
                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                    "Data.Maybe∷Maybe.Just",
                                    x252 + 1
                                  }, function(x253)
                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                      "Data.Maybe∷Maybe.Just",
                                      x253 + 1
                                    }, function(x254)
                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                        "Data.Maybe∷Maybe.Just",
                                        x254 + 1
                                      }, function(x255)
                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                          "Data.Maybe∷Maybe.Just",
                                          x255 + 1
                                        }, function(x256)
                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                            "Data.Maybe∷Maybe.Just",
                                            x256 + 1
                                          }, function(x257)
                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                              "Data.Maybe∷Maybe.Just",
                                              x257 + 1
                                            }, function(x258)
                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                "Data.Maybe∷Maybe.Just",
                                                x258 + 1
                                              }, function(x259)
                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                  "Data.Maybe∷Maybe.Just",
                                                  x259 + 1
                                                }, function(x260)
                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                    "Data.Maybe∷Maybe.Just",
                                                    x260 + 1
                                                  }, function(x261)
                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                      "Data.Maybe∷Maybe.Just",
                                                      x261 + 1
                                                    }, function(x262)
                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                        "Data.Maybe∷Maybe.Just",
                                                        x262 + 1
                                                      }, function(x263)
                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                          "Data.Maybe∷Maybe.Just",
                                                          x263 + 1
                                                        }, function(x264)
                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                            "Data.Maybe∷Maybe.Just",
                                                            x264 + 1
                                                          }, function(x265)
                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                              "Data.Maybe∷Maybe.Just",
                                                              x265 + 1
                                                            }, function(x266)
                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                "Data.Maybe∷Maybe.Just",
                                                                x266 + 1
                                                              }, function(x267)
                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                  "Data.Maybe∷Maybe.Just",
                                                                  x267 + 1
                                                                }, function( x268 )
                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                    "Data.Maybe∷Maybe.Just",
                                                                    x268 + 1
                                                                  }, function( x269 )
                                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                                      "Data.Maybe∷Maybe.Just",
                                                                      x269 + 1
                                                                    }, function( x270 )
                                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                                        "Data.Maybe∷Maybe.Just",
                                                                        x270 + 1
                                                                      }, function( x271 )
                                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                                          "Data.Maybe∷Maybe.Just",
                                                                          x271 + 1
                                                                        }, function( x272 )
                                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                                            "Data.Maybe∷Maybe.Just",
                                                                            x272 + 1
                                                                          }, function( x273 )
                                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                                              "Data.Maybe∷Maybe.Just",
                                                                              x273 + 1
                                                                            }, function( x274 )
                                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                "Data.Maybe∷Maybe.Just",
                                                                                x274 + 1
                                                                              }, function( x275 )
                                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                  "Data.Maybe∷Maybe.Just",
                                                                                  x275 + 1
                                                                                }, function( x276 )
                                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                    "Data.Maybe∷Maybe.Just",
                                                                                    x276 + 1
                                                                                  }, function( x277 )
                                                                                    return _S_kont1231_S_w(x1_S_1235, x277)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1237_S_w = function(x1_S_1238, x198_S_1239)
    return Golden_LongMaybeBind_Test_bind_S_w({
      "Data.Maybe∷Maybe.Just",
      x198_S_1239 + 1
    }, function(x199)
      return Golden_LongMaybeBind_Test_bind_S_w({
        "Data.Maybe∷Maybe.Just",
        x199 + 1
      }, function(x200)
        return Golden_LongMaybeBind_Test_bind_S_w({
          "Data.Maybe∷Maybe.Just",
          x200 + 1
        }, function(x201)
          return Golden_LongMaybeBind_Test_bind_S_w({
            "Data.Maybe∷Maybe.Just",
            x201 + 1
          }, function(x202)
            return Golden_LongMaybeBind_Test_bind_S_w({
              "Data.Maybe∷Maybe.Just",
              x202 + 1
            }, function(x203)
              return Golden_LongMaybeBind_Test_bind_S_w({
                "Data.Maybe∷Maybe.Just",
                x203 + 1
              }, function(x204)
                return Golden_LongMaybeBind_Test_bind_S_w({
                  "Data.Maybe∷Maybe.Just",
                  x204 + 1
                }, function(x205)
                  return Golden_LongMaybeBind_Test_bind_S_w({
                    "Data.Maybe∷Maybe.Just",
                    x205 + 1
                  }, function(x206)
                    return Golden_LongMaybeBind_Test_bind_S_w({
                      "Data.Maybe∷Maybe.Just",
                      x206 + 1
                    }, function(x207)
                      return Golden_LongMaybeBind_Test_bind_S_w({
                        "Data.Maybe∷Maybe.Just",
                        x207 + 1
                      }, function(x208)
                        return Golden_LongMaybeBind_Test_bind_S_w({
                          "Data.Maybe∷Maybe.Just",
                          x208 + 1
                        }, function(x209)
                          return Golden_LongMaybeBind_Test_bind_S_w({
                            "Data.Maybe∷Maybe.Just",
                            x209 + 1
                          }, function(x210)
                            return Golden_LongMaybeBind_Test_bind_S_w({
                              "Data.Maybe∷Maybe.Just",
                              x210 + 1
                            }, function(x211)
                              return Golden_LongMaybeBind_Test_bind_S_w({
                                "Data.Maybe∷Maybe.Just",
                                x211 + 1
                              }, function(x212)
                                return Golden_LongMaybeBind_Test_bind_S_w({
                                  "Data.Maybe∷Maybe.Just",
                                  x212 + 1
                                }, function(x213)
                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                    "Data.Maybe∷Maybe.Just",
                                    x213 + 1
                                  }, function(x214)
                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                      "Data.Maybe∷Maybe.Just",
                                      x214 + 1
                                    }, function(x215)
                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                        "Data.Maybe∷Maybe.Just",
                                        x215 + 1
                                      }, function(x216)
                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                          "Data.Maybe∷Maybe.Just",
                                          x216 + 1
                                        }, function(x217)
                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                            "Data.Maybe∷Maybe.Just",
                                            x217 + 1
                                          }, function(x218)
                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                              "Data.Maybe∷Maybe.Just",
                                              x218 + 1
                                            }, function(x219)
                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                "Data.Maybe∷Maybe.Just",
                                                x219 + 1
                                              }, function(x220)
                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                  "Data.Maybe∷Maybe.Just",
                                                  x220 + 1
                                                }, function(x221)
                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                    "Data.Maybe∷Maybe.Just",
                                                    x221 + 1
                                                  }, function(x222)
                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                      "Data.Maybe∷Maybe.Just",
                                                      x222 + 1
                                                    }, function(x223)
                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                        "Data.Maybe∷Maybe.Just",
                                                        x223 + 1
                                                      }, function(x224)
                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                          "Data.Maybe∷Maybe.Just",
                                                          x224 + 1
                                                        }, function(x225)
                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                            "Data.Maybe∷Maybe.Just",
                                                            x225 + 1
                                                          }, function(x226)
                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                              "Data.Maybe∷Maybe.Just",
                                                              x226 + 1
                                                            }, function(x227)
                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                "Data.Maybe∷Maybe.Just",
                                                                x227 + 1
                                                              }, function(x228)
                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                  "Data.Maybe∷Maybe.Just",
                                                                  x228 + 1
                                                                }, function( x229 )
                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                    "Data.Maybe∷Maybe.Just",
                                                                    x229 + 1
                                                                  }, function( x230 )
                                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                                      "Data.Maybe∷Maybe.Just",
                                                                      x230 + 1
                                                                    }, function( x231 )
                                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                                        "Data.Maybe∷Maybe.Just",
                                                                        x231 + 1
                                                                      }, function( x232 )
                                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                                          "Data.Maybe∷Maybe.Just",
                                                                          x232 + 1
                                                                        }, function( x233 )
                                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                                            "Data.Maybe∷Maybe.Just",
                                                                            x233 + 1
                                                                          }, function( x234 )
                                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                                              "Data.Maybe∷Maybe.Just",
                                                                              x234 + 1
                                                                            }, function( x235 )
                                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                "Data.Maybe∷Maybe.Just",
                                                                                x235 + 1
                                                                              }, function( x236 )
                                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                  "Data.Maybe∷Maybe.Just",
                                                                                  x236 + 1
                                                                                }, function( x237 )
                                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                    "Data.Maybe∷Maybe.Just",
                                                                                    x237 + 1
                                                                                  }, function( x238 )
                                                                                    return _S_kont1234_S_w(x1_S_1238, x238)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1240_S_w = function(x1_S_1241, x158_S_1242)
    return Golden_LongMaybeBind_Test_bind_S_w({
      "Data.Maybe∷Maybe.Just",
      x158_S_1242 + 1
    }, function(x159)
      return Golden_LongMaybeBind_Test_bind_S_w({
        "Data.Maybe∷Maybe.Just",
        x159 + 1
      }, function(x160)
        return Golden_LongMaybeBind_Test_bind_S_w({
          "Data.Maybe∷Maybe.Just",
          x160 + 1
        }, function(x161)
          return Golden_LongMaybeBind_Test_bind_S_w({
            "Data.Maybe∷Maybe.Just",
            x161 + 1
          }, function(x162)
            return Golden_LongMaybeBind_Test_bind_S_w({
              "Data.Maybe∷Maybe.Just",
              x162 + 1
            }, function(x163)
              return Golden_LongMaybeBind_Test_bind_S_w({
                "Data.Maybe∷Maybe.Just",
                x163 + 1
              }, function(x164)
                return Golden_LongMaybeBind_Test_bind_S_w({
                  "Data.Maybe∷Maybe.Just",
                  x164 + 1
                }, function(x165)
                  return Golden_LongMaybeBind_Test_bind_S_w({
                    "Data.Maybe∷Maybe.Just",
                    x165 + 1
                  }, function(x166)
                    return Golden_LongMaybeBind_Test_bind_S_w({
                      "Data.Maybe∷Maybe.Just",
                      x166 + 1
                    }, function(x167)
                      return Golden_LongMaybeBind_Test_bind_S_w({
                        "Data.Maybe∷Maybe.Just",
                        x167 + 1
                      }, function(x168)
                        return Golden_LongMaybeBind_Test_bind_S_w({
                          "Data.Maybe∷Maybe.Just",
                          x168 + 1
                        }, function(x169)
                          return Golden_LongMaybeBind_Test_bind_S_w({
                            "Data.Maybe∷Maybe.Just",
                            x169 + 1
                          }, function(x170)
                            return Golden_LongMaybeBind_Test_bind_S_w({
                              "Data.Maybe∷Maybe.Just",
                              x170 + 1
                            }, function(x171)
                              return Golden_LongMaybeBind_Test_bind_S_w({
                                "Data.Maybe∷Maybe.Just",
                                x171 + 1
                              }, function(x172)
                                return Golden_LongMaybeBind_Test_bind_S_w({
                                  "Data.Maybe∷Maybe.Just",
                                  x172 + 1
                                }, function(x173)
                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                    "Data.Maybe∷Maybe.Just",
                                    x173 + 1
                                  }, function(x174)
                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                      "Data.Maybe∷Maybe.Just",
                                      x174 + 1
                                    }, function(x175)
                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                        "Data.Maybe∷Maybe.Just",
                                        x175 + 1
                                      }, function(x176)
                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                          "Data.Maybe∷Maybe.Just",
                                          x176 + 1
                                        }, function(x177)
                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                            "Data.Maybe∷Maybe.Just",
                                            x177 + 1
                                          }, function(x178)
                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                              "Data.Maybe∷Maybe.Just",
                                              x178 + 1
                                            }, function(x179)
                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                "Data.Maybe∷Maybe.Just",
                                                x179 + 1
                                              }, function(x180)
                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                  "Data.Maybe∷Maybe.Just",
                                                  x180 + 1
                                                }, function(x181)
                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                    "Data.Maybe∷Maybe.Just",
                                                    x181 + 1
                                                  }, function(x182)
                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                      "Data.Maybe∷Maybe.Just",
                                                      x182 + 1
                                                    }, function(x183)
                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                        "Data.Maybe∷Maybe.Just",
                                                        x183 + 1
                                                      }, function(x184)
                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                          "Data.Maybe∷Maybe.Just",
                                                          x184 + 1
                                                        }, function(x185)
                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                            "Data.Maybe∷Maybe.Just",
                                                            x185 + 1
                                                          }, function(x186)
                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                              "Data.Maybe∷Maybe.Just",
                                                              x186 + 1
                                                            }, function(x187)
                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                "Data.Maybe∷Maybe.Just",
                                                                x187 + 1
                                                              }, function(x188)
                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                  "Data.Maybe∷Maybe.Just",
                                                                  x188 + 1
                                                                }, function( x189 )
                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                    "Data.Maybe∷Maybe.Just",
                                                                    x189 + 1
                                                                  }, function( x190 )
                                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                                      "Data.Maybe∷Maybe.Just",
                                                                      x190 + 1
                                                                    }, function( x191 )
                                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                                        "Data.Maybe∷Maybe.Just",
                                                                        x191 + 1
                                                                      }, function( x192 )
                                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                                          "Data.Maybe∷Maybe.Just",
                                                                          x192 + 1
                                                                        }, function( x193 )
                                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                                            "Data.Maybe∷Maybe.Just",
                                                                            x193 + 1
                                                                          }, function( x194 )
                                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                                              "Data.Maybe∷Maybe.Just",
                                                                              x194 + 1
                                                                            }, function( x195 )
                                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                "Data.Maybe∷Maybe.Just",
                                                                                x195 + 1
                                                                              }, function( x196 )
                                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                  "Data.Maybe∷Maybe.Just",
                                                                                  x196 + 1
                                                                                }, function( x197 )
                                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                    "Data.Maybe∷Maybe.Just",
                                                                                    x197 + 1
                                                                                  }, function( x198 )
                                                                                    return _S_kont1237_S_w(x1_S_1241, x198)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1243_S_w = function(x1_S_1244, x119_S_1245)
    return Golden_LongMaybeBind_Test_bind_S_w({
      "Data.Maybe∷Maybe.Just",
      x119_S_1245 + 1
    }, function(x120)
      return Golden_LongMaybeBind_Test_bind_S_w({
        "Data.Maybe∷Maybe.Just",
        x120 + 1
      }, function(x121)
        return Golden_LongMaybeBind_Test_bind_S_w({
          "Data.Maybe∷Maybe.Just",
          x121 + 1
        }, function(x122)
          return Golden_LongMaybeBind_Test_bind_S_w({
            "Data.Maybe∷Maybe.Just",
            x122 + 1
          }, function(x123)
            return Golden_LongMaybeBind_Test_bind_S_w({
              "Data.Maybe∷Maybe.Just",
              x123 + 1
            }, function(x124)
              return Golden_LongMaybeBind_Test_bind_S_w({
                "Data.Maybe∷Maybe.Just",
                x124 + 1
              }, function(x125)
                return Golden_LongMaybeBind_Test_bind_S_w({
                  "Data.Maybe∷Maybe.Just",
                  x125 + 1
                }, function(x126)
                  return Golden_LongMaybeBind_Test_bind_S_w({
                    "Data.Maybe∷Maybe.Just",
                    x126 + 1
                  }, function(x127)
                    return Golden_LongMaybeBind_Test_bind_S_w({
                      "Data.Maybe∷Maybe.Just",
                      x127 + 1
                    }, function(x128)
                      return Golden_LongMaybeBind_Test_bind_S_w({
                        "Data.Maybe∷Maybe.Just",
                        x128 + 1
                      }, function(x129)
                        return Golden_LongMaybeBind_Test_bind_S_w({
                          "Data.Maybe∷Maybe.Just",
                          x129 + 1
                        }, function(x130)
                          return Golden_LongMaybeBind_Test_bind_S_w({
                            "Data.Maybe∷Maybe.Just",
                            x130 + 1
                          }, function(x131)
                            return Golden_LongMaybeBind_Test_bind_S_w({
                              "Data.Maybe∷Maybe.Just",
                              x131 + 1
                            }, function(x132)
                              return Golden_LongMaybeBind_Test_bind_S_w({
                                "Data.Maybe∷Maybe.Just",
                                x132 + 1
                              }, function(x133)
                                return Golden_LongMaybeBind_Test_bind_S_w({
                                  "Data.Maybe∷Maybe.Just",
                                  x133 + 1
                                }, function(x134)
                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                    "Data.Maybe∷Maybe.Just",
                                    x134 + 1
                                  }, function(x135)
                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                      "Data.Maybe∷Maybe.Just",
                                      x135 + 1
                                    }, function(x136)
                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                        "Data.Maybe∷Maybe.Just",
                                        x136 + 1
                                      }, function(x137)
                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                          "Data.Maybe∷Maybe.Just",
                                          x137 + 1
                                        }, function(x138)
                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                            "Data.Maybe∷Maybe.Just",
                                            x138 + 1
                                          }, function(x139)
                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                              "Data.Maybe∷Maybe.Just",
                                              x139 + 1
                                            }, function(x140)
                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                "Data.Maybe∷Maybe.Just",
                                                x140 + 1
                                              }, function(x141)
                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                  "Data.Maybe∷Maybe.Just",
                                                  x141 + 1
                                                }, function(x142)
                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                    "Data.Maybe∷Maybe.Just",
                                                    x142 + 1
                                                  }, function(x143)
                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                      "Data.Maybe∷Maybe.Just",
                                                      x143 + 1
                                                    }, function(x144)
                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                        "Data.Maybe∷Maybe.Just",
                                                        x144 + 1
                                                      }, function(x145)
                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                          "Data.Maybe∷Maybe.Just",
                                                          x145 + 1
                                                        }, function(x146)
                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                            "Data.Maybe∷Maybe.Just",
                                                            x146 + 1
                                                          }, function(x147)
                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                              "Data.Maybe∷Maybe.Just",
                                                              x147 + 1
                                                            }, function(x148)
                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                "Data.Maybe∷Maybe.Just",
                                                                x148 + 1
                                                              }, function(x149)
                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                  "Data.Maybe∷Maybe.Just",
                                                                  x149 + 1
                                                                }, function( x150 )
                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                    "Data.Maybe∷Maybe.Just",
                                                                    Data_Unit_unit
                                                                  }, function()
                                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                                      "Data.Maybe∷Maybe.Just",
                                                                      x150 + 1
                                                                    }, function( x151 )
                                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                                        "Data.Maybe∷Maybe.Just",
                                                                        x151 + 1
                                                                      }, function( x152 )
                                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                                          "Data.Maybe∷Maybe.Just",
                                                                          x152 + 1
                                                                        }, function( x153 )
                                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                                            "Data.Maybe∷Maybe.Just",
                                                                            x153 + 1
                                                                          }, function( x154 )
                                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                                              "Data.Maybe∷Maybe.Just",
                                                                              x154 + 1
                                                                            }, function( x155 )
                                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                "Data.Maybe∷Maybe.Just",
                                                                                x155 + 1
                                                                              }, function( x156 )
                                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                  "Data.Maybe∷Maybe.Just",
                                                                                  x156 + 1
                                                                                }, function( x157 )
                                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                    "Data.Maybe∷Maybe.Just",
                                                                                    x157 + 1
                                                                                  }, function( x158 )
                                                                                    return _S_kont1240_S_w(x1_S_1244, x158)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1246_S_w = function(x1_S_1247, x79_S_1248)
    return Golden_LongMaybeBind_Test_bind_S_w({
      "Data.Maybe∷Maybe.Just",
      x79_S_1248 + 1
    }, function(x80)
      return Golden_LongMaybeBind_Test_bind_S_w({
        "Data.Maybe∷Maybe.Just",
        x80 + 1
      }, function(x81)
        return Golden_LongMaybeBind_Test_bind_S_w({
          "Data.Maybe∷Maybe.Just",
          x81 + 1
        }, function(x82)
          return Golden_LongMaybeBind_Test_bind_S_w({
            "Data.Maybe∷Maybe.Just",
            x82 + 1
          }, function(x83)
            return Golden_LongMaybeBind_Test_bind_S_w({
              "Data.Maybe∷Maybe.Just",
              x83 + 1
            }, function(x84)
              return Golden_LongMaybeBind_Test_bind_S_w({
                "Data.Maybe∷Maybe.Just",
                x84 + 1
              }, function(x85)
                return Golden_LongMaybeBind_Test_bind_S_w({
                  "Data.Maybe∷Maybe.Just",
                  x85 + 1
                }, function(x86)
                  return Golden_LongMaybeBind_Test_bind_S_w({
                    "Data.Maybe∷Maybe.Just",
                    x86 + 1
                  }, function(x87)
                    return Golden_LongMaybeBind_Test_bind_S_w({
                      "Data.Maybe∷Maybe.Just",
                      x87 + 1
                    }, function(x88)
                      return Golden_LongMaybeBind_Test_bind_S_w({
                        "Data.Maybe∷Maybe.Just",
                        x88 + 1
                      }, function(x89)
                        return Golden_LongMaybeBind_Test_bind_S_w({
                          "Data.Maybe∷Maybe.Just",
                          x89 + 1
                        }, function(x90)
                          return Golden_LongMaybeBind_Test_bind_S_w({
                            "Data.Maybe∷Maybe.Just",
                            x90 + 1
                          }, function(x91)
                            return Golden_LongMaybeBind_Test_bind_S_w({
                              "Data.Maybe∷Maybe.Just",
                              x91 + 1
                            }, function(x92)
                              return Golden_LongMaybeBind_Test_bind_S_w({
                                "Data.Maybe∷Maybe.Just",
                                x92 + 1
                              }, function(x93)
                                return Golden_LongMaybeBind_Test_bind_S_w({
                                  "Data.Maybe∷Maybe.Just",
                                  x93 + 1
                                }, function(x94)
                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                    "Data.Maybe∷Maybe.Just",
                                    x94 + 1
                                  }, function(x95)
                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                      "Data.Maybe∷Maybe.Just",
                                      x95 + 1
                                    }, function(x96)
                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                        "Data.Maybe∷Maybe.Just",
                                        x96 + 1
                                      }, function(x97)
                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                          "Data.Maybe∷Maybe.Just",
                                          x97 + 1
                                        }, function(x98)
                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                            "Data.Maybe∷Maybe.Just",
                                            x98 + 1
                                          }, function(x99)
                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                              "Data.Maybe∷Maybe.Just",
                                              x99 + 1
                                            }, function(x100)
                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                "Data.Maybe∷Maybe.Just",
                                                x100 + 1
                                              }, function(x101)
                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                  "Data.Maybe∷Maybe.Just",
                                                  x101 + 1
                                                }, function(x102)
                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                    "Data.Maybe∷Maybe.Just",
                                                    x102 + 1
                                                  }, function(x103)
                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                      "Data.Maybe∷Maybe.Just",
                                                      x103 + 1
                                                    }, function(x104)
                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                        "Data.Maybe∷Maybe.Just",
                                                        x104 + 1
                                                      }, function(x105)
                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                          "Data.Maybe∷Maybe.Just",
                                                          x105 + 1
                                                        }, function(x106)
                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                            "Data.Maybe∷Maybe.Just",
                                                            x106 + 1
                                                          }, function(x107)
                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                              "Data.Maybe∷Maybe.Just",
                                                              x107 + 1
                                                            }, function(x108)
                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                "Data.Maybe∷Maybe.Just",
                                                                x108 + 1
                                                              }, function(x109)
                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                  "Data.Maybe∷Maybe.Just",
                                                                  x109 + 1
                                                                }, function( x110 )
                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                    "Data.Maybe∷Maybe.Just",
                                                                    x110 + 1
                                                                  }, function( x111 )
                                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                                      "Data.Maybe∷Maybe.Just",
                                                                      x111 + 1
                                                                    }, function( x112 )
                                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                                        "Data.Maybe∷Maybe.Just",
                                                                        x112 + 1
                                                                      }, function( x113 )
                                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                                          "Data.Maybe∷Maybe.Just",
                                                                          x113 + 1
                                                                        }, function( x114 )
                                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                                            "Data.Maybe∷Maybe.Just",
                                                                            x114 + 1
                                                                          }, function( x115 )
                                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                                              "Data.Maybe∷Maybe.Just",
                                                                              x115 + 1
                                                                            }, function( x116 )
                                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                "Data.Maybe∷Maybe.Just",
                                                                                x116 + 1
                                                                              }, function( x117 )
                                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                  "Data.Maybe∷Maybe.Just",
                                                                                  x117 + 1
                                                                                }, function( x118 )
                                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                    "Data.Maybe∷Maybe.Just",
                                                                                    x118 + 1
                                                                                  }, function( x119 )
                                                                                    return _S_kont1243_S_w(x1_S_1247, x119)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  local _S_kont1249_S_w = function(x1_S_1250, x40_S_1251)
    return Golden_LongMaybeBind_Test_bind_S_w({
      "Data.Maybe∷Maybe.Just",
      x40_S_1251 + 1
    }, function(x41)
      return Golden_LongMaybeBind_Test_bind_S_w({
        "Data.Maybe∷Maybe.Just",
        x41 + 1
      }, function(x42)
        return Golden_LongMaybeBind_Test_bind_S_w({
          "Data.Maybe∷Maybe.Just",
          x42 + 1
        }, function(x43)
          return Golden_LongMaybeBind_Test_bind_S_w({
            "Data.Maybe∷Maybe.Just",
            x43 + 1
          }, function(x44)
            return Golden_LongMaybeBind_Test_bind_S_w({
              "Data.Maybe∷Maybe.Just",
              x44 + 1
            }, function(x45)
              return Golden_LongMaybeBind_Test_bind_S_w({
                "Data.Maybe∷Maybe.Just",
                x45 + 1
              }, function(x46)
                return Golden_LongMaybeBind_Test_bind_S_w({
                  "Data.Maybe∷Maybe.Just",
                  x46 + 1
                }, function(x47)
                  return Golden_LongMaybeBind_Test_bind_S_w({
                    "Data.Maybe∷Maybe.Just",
                    x47 + 1
                  }, function(x48)
                    return Golden_LongMaybeBind_Test_bind_S_w({
                      "Data.Maybe∷Maybe.Just",
                      x48 + 1
                    }, function(x49)
                      return Golden_LongMaybeBind_Test_bind_S_w({
                        "Data.Maybe∷Maybe.Just",
                        x49 + 1
                      }, function(x50)
                        return Golden_LongMaybeBind_Test_bind_S_w({
                          "Data.Maybe∷Maybe.Just",
                          Data_Unit_unit
                        }, function()
                          return Golden_LongMaybeBind_Test_bind_S_w({
                            "Data.Maybe∷Maybe.Just",
                            x50 + 1
                          }, function(x51)
                            return Golden_LongMaybeBind_Test_bind_S_w({
                              "Data.Maybe∷Maybe.Just",
                              x51 + 1
                            }, function(x52)
                              return Golden_LongMaybeBind_Test_bind_S_w({
                                "Data.Maybe∷Maybe.Just",
                                x52 + 1
                              }, function(x53)
                                return Golden_LongMaybeBind_Test_bind_S_w({
                                  "Data.Maybe∷Maybe.Just",
                                  x53 + 1
                                }, function(x54)
                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                    "Data.Maybe∷Maybe.Just",
                                    x54 + 1
                                  }, function(x55)
                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                      "Data.Maybe∷Maybe.Just",
                                      x55 + 1
                                    }, function(x56)
                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                        "Data.Maybe∷Maybe.Just",
                                        x56 + 1
                                      }, function(x57)
                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                          "Data.Maybe∷Maybe.Just",
                                          x57 + 1
                                        }, function(x58)
                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                            "Data.Maybe∷Maybe.Just",
                                            x58 + 1
                                          }, function(x59)
                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                              "Data.Maybe∷Maybe.Just",
                                              x59 + 1
                                            }, function(x60)
                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                "Data.Maybe∷Maybe.Just",
                                                x60 + 1
                                              }, function(x61)
                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                  "Data.Maybe∷Maybe.Just",
                                                  x61 + 1
                                                }, function(x62)
                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                    "Data.Maybe∷Maybe.Just",
                                                    x62 + 1
                                                  }, function(x63)
                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                      "Data.Maybe∷Maybe.Just",
                                                      x63 + 1
                                                    }, function(x64)
                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                        "Data.Maybe∷Maybe.Just",
                                                        x64 + 1
                                                      }, function(x65)
                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                          "Data.Maybe∷Maybe.Just",
                                                          x65 + 1
                                                        }, function(x66)
                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                            "Data.Maybe∷Maybe.Just",
                                                            x66 + 1
                                                          }, function(x67)
                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                              "Data.Maybe∷Maybe.Just",
                                                              x67 + 1
                                                            }, function(x68)
                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                "Data.Maybe∷Maybe.Just",
                                                                x68 + 1
                                                              }, function(x69)
                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                  "Data.Maybe∷Maybe.Just",
                                                                  x69 + 1
                                                                }, function(x70)
                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                    "Data.Maybe∷Maybe.Just",
                                                                    x70 + 1
                                                                  }, function( x71 )
                                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                                      "Data.Maybe∷Maybe.Just",
                                                                      x71 + 1
                                                                    }, function( x72 )
                                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                                        "Data.Maybe∷Maybe.Just",
                                                                        x72 + 1
                                                                      }, function( x73 )
                                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                                          "Data.Maybe∷Maybe.Just",
                                                                          x73 + 1
                                                                        }, function( x74 )
                                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                                            "Data.Maybe∷Maybe.Just",
                                                                            x74 + 1
                                                                          }, function( x75 )
                                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                                              "Data.Maybe∷Maybe.Just",
                                                                              x75 + 1
                                                                            }, function( x76 )
                                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                "Data.Maybe∷Maybe.Just",
                                                                                x76 + 1
                                                                              }, function( x77 )
                                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                  "Data.Maybe∷Maybe.Just",
                                                                                  x77 + 1
                                                                                }, function( x78 )
                                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                    "Data.Maybe∷Maybe.Just",
                                                                                    x78 + 1
                                                                                  }, function( x79 )
                                                                                    return _S_kont1246_S_w(x1_S_1250, x79)
                                                                                  end)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
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
  return Golden_LongMaybeBind_Test_bind_S_w({
    "Data.Maybe∷Maybe.Just",
    1
  }, function(x1)
    return Golden_LongMaybeBind_Test_bind_S_w({
      "Data.Maybe∷Maybe.Just",
      x1 + 1
    }, function(x2)
      return Golden_LongMaybeBind_Test_bind_S_w({
        "Data.Maybe∷Maybe.Just",
        x2 + 1
      }, function(x3)
        return Golden_LongMaybeBind_Test_bind_S_w({
          "Data.Maybe∷Maybe.Just",
          x3 + 1
        }, function(x4)
          return Golden_LongMaybeBind_Test_bind_S_w({
            "Data.Maybe∷Maybe.Just",
            x4 + 1
          }, function(x5)
            return Golden_LongMaybeBind_Test_bind_S_w({
              "Data.Maybe∷Maybe.Just",
              x5 + 1
            }, function(x6)
              return Golden_LongMaybeBind_Test_bind_S_w({
                "Data.Maybe∷Maybe.Just",
                x6 + 1
              }, function(x7)
                return Golden_LongMaybeBind_Test_bind_S_w({
                  "Data.Maybe∷Maybe.Just",
                  x7 + 1
                }, function(x8)
                  return Golden_LongMaybeBind_Test_bind_S_w({
                    "Data.Maybe∷Maybe.Just",
                    x8 + 1
                  }, function(x9)
                    return Golden_LongMaybeBind_Test_bind_S_w({
                      "Data.Maybe∷Maybe.Just",
                      x9 + 1
                    }, function(x10)
                      return Golden_LongMaybeBind_Test_bind_S_w({
                        "Data.Maybe∷Maybe.Just",
                        x10 + 1
                      }, function(x11)
                        return Golden_LongMaybeBind_Test_bind_S_w({
                          "Data.Maybe∷Maybe.Just",
                          x11 + 1
                        }, function(x12)
                          return Golden_LongMaybeBind_Test_bind_S_w({
                            "Data.Maybe∷Maybe.Just",
                            x12 + 1
                          }, function(x13)
                            return Golden_LongMaybeBind_Test_bind_S_w({
                              "Data.Maybe∷Maybe.Just",
                              x13 + 1
                            }, function(x14)
                              return Golden_LongMaybeBind_Test_bind_S_w({
                                "Data.Maybe∷Maybe.Just",
                                x14 + 1
                              }, function(x15)
                                return Golden_LongMaybeBind_Test_bind_S_w({
                                  "Data.Maybe∷Maybe.Just",
                                  x15 + 1
                                }, function(x16)
                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                    "Data.Maybe∷Maybe.Just",
                                    x16 + 1
                                  }, function(x17)
                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                      "Data.Maybe∷Maybe.Just",
                                      x17 + 1
                                    }, function(x18)
                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                        "Data.Maybe∷Maybe.Just",
                                        x18 + 1
                                      }, function(x19)
                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                          "Data.Maybe∷Maybe.Just",
                                          x19 + 1
                                        }, function(x20)
                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                            "Data.Maybe∷Maybe.Just",
                                            x20 + 1
                                          }, function(x21)
                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                              "Data.Maybe∷Maybe.Just",
                                              x21 + 1
                                            }, function(x22)
                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                "Data.Maybe∷Maybe.Just",
                                                x22 + 1
                                              }, function(x23)
                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                  "Data.Maybe∷Maybe.Just",
                                                  x23 + 1
                                                }, function(x24)
                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                    "Data.Maybe∷Maybe.Just",
                                                    x24 + 1
                                                  }, function(x25)
                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                      "Data.Maybe∷Maybe.Just",
                                                      x25 + 1
                                                    }, function(x26)
                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                        "Data.Maybe∷Maybe.Just",
                                                        x26 + 1
                                                      }, function(x27)
                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                          "Data.Maybe∷Maybe.Just",
                                                          x27 + 1
                                                        }, function(x28)
                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                            "Data.Maybe∷Maybe.Just",
                                                            x28 + 1
                                                          }, function(x29)
                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                              "Data.Maybe∷Maybe.Just",
                                                              x29 + 1
                                                            }, function(x30)
                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                "Data.Maybe∷Maybe.Just",
                                                                x30 + 1
                                                              }, function(x31)
                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                  "Data.Maybe∷Maybe.Just",
                                                                  x31 + 1
                                                                }, function(x32)
                                                                  return Golden_LongMaybeBind_Test_bind_S_w({
                                                                    "Data.Maybe∷Maybe.Just",
                                                                    x32 + 1
                                                                  }, function( x33 )
                                                                    return Golden_LongMaybeBind_Test_bind_S_w({
                                                                      "Data.Maybe∷Maybe.Just",
                                                                      x33 + 1
                                                                    }, function( x34 )
                                                                      return Golden_LongMaybeBind_Test_bind_S_w({
                                                                        "Data.Maybe∷Maybe.Just",
                                                                        x34 + 1
                                                                      }, function( x35 )
                                                                        return Golden_LongMaybeBind_Test_bind_S_w({
                                                                          "Data.Maybe∷Maybe.Just",
                                                                          x35 + 1
                                                                        }, function( x36 )
                                                                          return Golden_LongMaybeBind_Test_bind_S_w({
                                                                            "Data.Maybe∷Maybe.Just",
                                                                            x36 + 1
                                                                          }, function( x37 )
                                                                            return Golden_LongMaybeBind_Test_bind_S_w({
                                                                              "Data.Maybe∷Maybe.Just",
                                                                              x37 + 1
                                                                            }, function( x38 )
                                                                              return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                "Data.Maybe∷Maybe.Just",
                                                                                x38 + 1
                                                                              }, function( x39 )
                                                                                return Golden_LongMaybeBind_Test_bind_S_w({
                                                                                  "Data.Maybe∷Maybe.Just",
                                                                                  x39 + 1
                                                                                }, function( x40 )
                                                                                  return _S_kont1249_S_w(x1, x40)
                                                                                end)
                                                                              end)
                                                                            end)
                                                                          end)
                                                                        end)
                                                                      end)
                                                                    end)
                                                                  end)
                                                                end)
                                                              end)
                                                            end)
                                                          end)
                                                        end)
                                                      end)
                                                    end)
                                                  end)
                                                end)
                                              end)
                                            end)
                                          end)
                                        end)
                                      end)
                                    end)
                                  end)
                                end)
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
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
return Effect_Console_foreign.log((function()
  if "Data.Maybe∷Maybe.Just" == Golden_LongMaybeBind_Test_compute[1] then
    return "(Just " .. Data_Show_foreign.showIntImpl(Golden_LongMaybeBind_Test_compute[2]) .. ")"
  else
    return "Nothing"
  end
end)())()
