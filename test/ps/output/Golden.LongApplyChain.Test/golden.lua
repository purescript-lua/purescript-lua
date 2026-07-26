local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Data_Maybe_Nothing = { "Data.Maybe∷Maybe.Nothing" }
local Golden_LongApplyChain_Test_applySecond_S_w = function(a_S_133, b_S_134)
  local v_S_626 = (function()
    if "Data.Maybe∷Maybe.Just" == a_S_133[1] then
      return { "Data.Maybe∷Maybe.Just", function(x_S_319) return x_S_319 end }
    else
      return Data_Maybe_Nothing
    end
  end)()
  local v1_S_627 = b_S_134
  if "Data.Maybe∷Maybe.Just" == v_S_626[1] then
    if "Data.Maybe∷Maybe.Just" == v1_S_627[1] then
      return { "Data.Maybe∷Maybe.Just", (v_S_626[2](v1_S_627[2])) }
    else
      return Data_Maybe_Nothing
    end
  else
    return Data_Maybe_Nothing
  end
end
local Golden_LongApplyChain_Test_compute = (function()
  local _S_tmp647 = Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w({
    "Data.Maybe∷Maybe.Just",
    1
  }, { "Data.Maybe∷Maybe.Just", 2 }), { "Data.Maybe∷Maybe.Just", 3 }), {
    "Data.Maybe∷Maybe.Just",
    4
  }), { "Data.Maybe∷Maybe.Just", 5 }), { "Data.Maybe∷Maybe.Just", 6 }), {
    "Data.Maybe∷Maybe.Just",
    7
  }), { "Data.Maybe∷Maybe.Just", 8 }), { "Data.Maybe∷Maybe.Just", 9 }), {
    "Data.Maybe∷Maybe.Just",
    10
  }), { "Data.Maybe∷Maybe.Just", 11 }), { "Data.Maybe∷Maybe.Just", 12 }), {
    "Data.Maybe∷Maybe.Just",
    13
  }), { "Data.Maybe∷Maybe.Just", 14 }), { "Data.Maybe∷Maybe.Just", 15 }), {
    "Data.Maybe∷Maybe.Just",
    16
  }), { "Data.Maybe∷Maybe.Just", 17 }), { "Data.Maybe∷Maybe.Just", 18 }), {
    "Data.Maybe∷Maybe.Just",
    19
  }), { "Data.Maybe∷Maybe.Just", 20 }), { "Data.Maybe∷Maybe.Just", 21 }), {
    "Data.Maybe∷Maybe.Just",
    22
  }), { "Data.Maybe∷Maybe.Just", 23 }), { "Data.Maybe∷Maybe.Just", 24 }), {
    "Data.Maybe∷Maybe.Just",
    25
  }), { "Data.Maybe∷Maybe.Just", 26 }), { "Data.Maybe∷Maybe.Just", 27 }), {
    "Data.Maybe∷Maybe.Just",
    28
  }), { "Data.Maybe∷Maybe.Just", 29 }), { "Data.Maybe∷Maybe.Just", 30 }), {
    "Data.Maybe∷Maybe.Just",
    31
  }), { "Data.Maybe∷Maybe.Just", 32 }), { "Data.Maybe∷Maybe.Just", 33 }), {
    "Data.Maybe∷Maybe.Just",
    34
  }), { "Data.Maybe∷Maybe.Just", 35 }), { "Data.Maybe∷Maybe.Just", 36 }), {
    "Data.Maybe∷Maybe.Just",
    37
  }), { "Data.Maybe∷Maybe.Just", 38 }), { "Data.Maybe∷Maybe.Just", 39 }), {
    "Data.Maybe∷Maybe.Just",
    40
  }), { "Data.Maybe∷Maybe.Just", 41 })
  local _S_tmp648 = Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(_S_tmp647, {
    "Data.Maybe∷Maybe.Just",
    42
  }), { "Data.Maybe∷Maybe.Just", 43 }), { "Data.Maybe∷Maybe.Just", 44 }), {
    "Data.Maybe∷Maybe.Just",
    45
  }), { "Data.Maybe∷Maybe.Just", 46 }), { "Data.Maybe∷Maybe.Just", 47 }), {
    "Data.Maybe∷Maybe.Just",
    48
  }), { "Data.Maybe∷Maybe.Just", 49 }), { "Data.Maybe∷Maybe.Just", 50 }), {
    "Data.Maybe∷Maybe.Just",
    51
  }), { "Data.Maybe∷Maybe.Just", 52 }), { "Data.Maybe∷Maybe.Just", 53 }), {
    "Data.Maybe∷Maybe.Just",
    54
  }), { "Data.Maybe∷Maybe.Just", 55 }), { "Data.Maybe∷Maybe.Just", 56 }), {
    "Data.Maybe∷Maybe.Just",
    57
  }), { "Data.Maybe∷Maybe.Just", 58 }), { "Data.Maybe∷Maybe.Just", 59 }), {
    "Data.Maybe∷Maybe.Just",
    60
  }), { "Data.Maybe∷Maybe.Just", 61 }), { "Data.Maybe∷Maybe.Just", 62 }), {
    "Data.Maybe∷Maybe.Just",
    63
  }), { "Data.Maybe∷Maybe.Just", 64 }), { "Data.Maybe∷Maybe.Just", 65 }), {
    "Data.Maybe∷Maybe.Just",
    66
  }), { "Data.Maybe∷Maybe.Just", 67 }), { "Data.Maybe∷Maybe.Just", 68 }), {
    "Data.Maybe∷Maybe.Just",
    69
  }), { "Data.Maybe∷Maybe.Just", 70 }), { "Data.Maybe∷Maybe.Just", 71 }), {
    "Data.Maybe∷Maybe.Just",
    72
  }), { "Data.Maybe∷Maybe.Just", 73 }), { "Data.Maybe∷Maybe.Just", 74 }), {
    "Data.Maybe∷Maybe.Just",
    75
  }), { "Data.Maybe∷Maybe.Just", 76 }), { "Data.Maybe∷Maybe.Just", 77 }), {
    "Data.Maybe∷Maybe.Just",
    78
  }), { "Data.Maybe∷Maybe.Just", 79 }), { "Data.Maybe∷Maybe.Just", 80 }), {
    "Data.Maybe∷Maybe.Just",
    81
  })
  local _S_tmp649 = Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(_S_tmp648, {
    "Data.Maybe∷Maybe.Just",
    82
  }), { "Data.Maybe∷Maybe.Just", 83 }), { "Data.Maybe∷Maybe.Just", 84 }), {
    "Data.Maybe∷Maybe.Just",
    85
  }), { "Data.Maybe∷Maybe.Just", 86 }), { "Data.Maybe∷Maybe.Just", 87 }), {
    "Data.Maybe∷Maybe.Just",
    88
  }), { "Data.Maybe∷Maybe.Just", 89 }), { "Data.Maybe∷Maybe.Just", 90 }), {
    "Data.Maybe∷Maybe.Just",
    91
  }), { "Data.Maybe∷Maybe.Just", 92 }), { "Data.Maybe∷Maybe.Just", 93 }), {
    "Data.Maybe∷Maybe.Just",
    94
  }), { "Data.Maybe∷Maybe.Just", 95 }), { "Data.Maybe∷Maybe.Just", 96 }), {
    "Data.Maybe∷Maybe.Just",
    97
  }), { "Data.Maybe∷Maybe.Just", 98 }), { "Data.Maybe∷Maybe.Just", 99 }), {
    "Data.Maybe∷Maybe.Just",
    100
  }), { "Data.Maybe∷Maybe.Just", 101 }), { "Data.Maybe∷Maybe.Just", 102 }), {
    "Data.Maybe∷Maybe.Just",
    103
  }), { "Data.Maybe∷Maybe.Just", 104 }), { "Data.Maybe∷Maybe.Just", 105 }), {
    "Data.Maybe∷Maybe.Just",
    106
  }), { "Data.Maybe∷Maybe.Just", 107 }), { "Data.Maybe∷Maybe.Just", 108 }), {
    "Data.Maybe∷Maybe.Just",
    109
  }), { "Data.Maybe∷Maybe.Just", 110 }), { "Data.Maybe∷Maybe.Just", 111 }), {
    "Data.Maybe∷Maybe.Just",
    112
  }), { "Data.Maybe∷Maybe.Just", 113 }), { "Data.Maybe∷Maybe.Just", 114 }), {
    "Data.Maybe∷Maybe.Just",
    115
  }), { "Data.Maybe∷Maybe.Just", 116 }), { "Data.Maybe∷Maybe.Just", 117 }), {
    "Data.Maybe∷Maybe.Just",
    118
  }), { "Data.Maybe∷Maybe.Just", 119 }), { "Data.Maybe∷Maybe.Just", 120 }), {
    "Data.Maybe∷Maybe.Just",
    121
  })
  local _S_tmp650 = Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(_S_tmp649, {
    "Data.Maybe∷Maybe.Just",
    122
  }), { "Data.Maybe∷Maybe.Just", 123 }), { "Data.Maybe∷Maybe.Just", 124 }), {
    "Data.Maybe∷Maybe.Just",
    125
  }), { "Data.Maybe∷Maybe.Just", 126 }), { "Data.Maybe∷Maybe.Just", 127 }), {
    "Data.Maybe∷Maybe.Just",
    128
  }), { "Data.Maybe∷Maybe.Just", 129 }), { "Data.Maybe∷Maybe.Just", 130 }), {
    "Data.Maybe∷Maybe.Just",
    131
  }), { "Data.Maybe∷Maybe.Just", 132 }), { "Data.Maybe∷Maybe.Just", 133 }), {
    "Data.Maybe∷Maybe.Just",
    134
  }), { "Data.Maybe∷Maybe.Just", 135 }), { "Data.Maybe∷Maybe.Just", 136 }), {
    "Data.Maybe∷Maybe.Just",
    137
  }), { "Data.Maybe∷Maybe.Just", 138 }), { "Data.Maybe∷Maybe.Just", 139 }), {
    "Data.Maybe∷Maybe.Just",
    140
  }), { "Data.Maybe∷Maybe.Just", 141 }), { "Data.Maybe∷Maybe.Just", 142 }), {
    "Data.Maybe∷Maybe.Just",
    143
  }), { "Data.Maybe∷Maybe.Just", 144 }), { "Data.Maybe∷Maybe.Just", 145 }), {
    "Data.Maybe∷Maybe.Just",
    146
  }), { "Data.Maybe∷Maybe.Just", 147 }), { "Data.Maybe∷Maybe.Just", 148 }), {
    "Data.Maybe∷Maybe.Just",
    149
  }), { "Data.Maybe∷Maybe.Just", 150 }), { "Data.Maybe∷Maybe.Just", 151 }), {
    "Data.Maybe∷Maybe.Just",
    152
  }), { "Data.Maybe∷Maybe.Just", 153 }), { "Data.Maybe∷Maybe.Just", 154 }), {
    "Data.Maybe∷Maybe.Just",
    155
  }), { "Data.Maybe∷Maybe.Just", 156 }), { "Data.Maybe∷Maybe.Just", 157 }), {
    "Data.Maybe∷Maybe.Just",
    158
  }), { "Data.Maybe∷Maybe.Just", 159 }), { "Data.Maybe∷Maybe.Just", 160 }), {
    "Data.Maybe∷Maybe.Just",
    161
  })
  local _S_tmp651 = Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(_S_tmp650, {
    "Data.Maybe∷Maybe.Just",
    162
  }), { "Data.Maybe∷Maybe.Just", 163 }), { "Data.Maybe∷Maybe.Just", 164 }), {
    "Data.Maybe∷Maybe.Just",
    165
  }), { "Data.Maybe∷Maybe.Just", 166 }), { "Data.Maybe∷Maybe.Just", 167 }), {
    "Data.Maybe∷Maybe.Just",
    168
  }), { "Data.Maybe∷Maybe.Just", 169 }), { "Data.Maybe∷Maybe.Just", 170 }), {
    "Data.Maybe∷Maybe.Just",
    171
  }), { "Data.Maybe∷Maybe.Just", 172 }), { "Data.Maybe∷Maybe.Just", 173 }), {
    "Data.Maybe∷Maybe.Just",
    174
  }), { "Data.Maybe∷Maybe.Just", 175 }), { "Data.Maybe∷Maybe.Just", 176 }), {
    "Data.Maybe∷Maybe.Just",
    177
  }), { "Data.Maybe∷Maybe.Just", 178 }), { "Data.Maybe∷Maybe.Just", 179 }), {
    "Data.Maybe∷Maybe.Just",
    180
  }), { "Data.Maybe∷Maybe.Just", 181 }), { "Data.Maybe∷Maybe.Just", 182 }), {
    "Data.Maybe∷Maybe.Just",
    183
  }), { "Data.Maybe∷Maybe.Just", 184 }), { "Data.Maybe∷Maybe.Just", 185 }), {
    "Data.Maybe∷Maybe.Just",
    186
  }), { "Data.Maybe∷Maybe.Just", 187 }), { "Data.Maybe∷Maybe.Just", 188 }), {
    "Data.Maybe∷Maybe.Just",
    189
  }), { "Data.Maybe∷Maybe.Just", 190 }), { "Data.Maybe∷Maybe.Just", 191 }), {
    "Data.Maybe∷Maybe.Just",
    192
  }), { "Data.Maybe∷Maybe.Just", 193 }), { "Data.Maybe∷Maybe.Just", 194 }), {
    "Data.Maybe∷Maybe.Just",
    195
  }), { "Data.Maybe∷Maybe.Just", 196 }), { "Data.Maybe∷Maybe.Just", 197 }), {
    "Data.Maybe∷Maybe.Just",
    198
  }), { "Data.Maybe∷Maybe.Just", 199 }), { "Data.Maybe∷Maybe.Just", 200 }), {
    "Data.Maybe∷Maybe.Just",
    201
  })
  local _S_tmp652 = Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(_S_tmp651, {
    "Data.Maybe∷Maybe.Just",
    202
  }), { "Data.Maybe∷Maybe.Just", 203 }), { "Data.Maybe∷Maybe.Just", 204 }), {
    "Data.Maybe∷Maybe.Just",
    205
  }), { "Data.Maybe∷Maybe.Just", 206 }), { "Data.Maybe∷Maybe.Just", 207 }), {
    "Data.Maybe∷Maybe.Just",
    208
  }), { "Data.Maybe∷Maybe.Just", 209 }), { "Data.Maybe∷Maybe.Just", 210 }), {
    "Data.Maybe∷Maybe.Just",
    211
  }), { "Data.Maybe∷Maybe.Just", 212 }), { "Data.Maybe∷Maybe.Just", 213 }), {
    "Data.Maybe∷Maybe.Just",
    214
  }), { "Data.Maybe∷Maybe.Just", 215 }), { "Data.Maybe∷Maybe.Just", 216 }), {
    "Data.Maybe∷Maybe.Just",
    217
  }), { "Data.Maybe∷Maybe.Just", 218 }), { "Data.Maybe∷Maybe.Just", 219 }), {
    "Data.Maybe∷Maybe.Just",
    220
  }), { "Data.Maybe∷Maybe.Just", 221 }), { "Data.Maybe∷Maybe.Just", 222 }), {
    "Data.Maybe∷Maybe.Just",
    223
  }), { "Data.Maybe∷Maybe.Just", 224 }), { "Data.Maybe∷Maybe.Just", 225 }), {
    "Data.Maybe∷Maybe.Just",
    226
  }), { "Data.Maybe∷Maybe.Just", 227 }), { "Data.Maybe∷Maybe.Just", 228 }), {
    "Data.Maybe∷Maybe.Just",
    229
  }), { "Data.Maybe∷Maybe.Just", 230 }), { "Data.Maybe∷Maybe.Just", 231 }), {
    "Data.Maybe∷Maybe.Just",
    232
  }), { "Data.Maybe∷Maybe.Just", 233 }), { "Data.Maybe∷Maybe.Just", 234 }), {
    "Data.Maybe∷Maybe.Just",
    235
  }), { "Data.Maybe∷Maybe.Just", 236 }), { "Data.Maybe∷Maybe.Just", 237 }), {
    "Data.Maybe∷Maybe.Just",
    238
  }), { "Data.Maybe∷Maybe.Just", 239 }), { "Data.Maybe∷Maybe.Just", 240 }), {
    "Data.Maybe∷Maybe.Just",
    241
  })
  local _S_tmp653 = Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(_S_tmp652, {
    "Data.Maybe∷Maybe.Just",
    242
  }), { "Data.Maybe∷Maybe.Just", 243 }), { "Data.Maybe∷Maybe.Just", 244 }), {
    "Data.Maybe∷Maybe.Just",
    245
  }), { "Data.Maybe∷Maybe.Just", 246 }), { "Data.Maybe∷Maybe.Just", 247 }), {
    "Data.Maybe∷Maybe.Just",
    248
  }), { "Data.Maybe∷Maybe.Just", 249 }), { "Data.Maybe∷Maybe.Just", 250 }), {
    "Data.Maybe∷Maybe.Just",
    251
  }), { "Data.Maybe∷Maybe.Just", 252 }), { "Data.Maybe∷Maybe.Just", 253 }), {
    "Data.Maybe∷Maybe.Just",
    254
  }), { "Data.Maybe∷Maybe.Just", 255 }), { "Data.Maybe∷Maybe.Just", 256 }), {
    "Data.Maybe∷Maybe.Just",
    257
  }), { "Data.Maybe∷Maybe.Just", 258 }), { "Data.Maybe∷Maybe.Just", 259 }), {
    "Data.Maybe∷Maybe.Just",
    260
  }), { "Data.Maybe∷Maybe.Just", 261 }), { "Data.Maybe∷Maybe.Just", 262 }), {
    "Data.Maybe∷Maybe.Just",
    263
  }), { "Data.Maybe∷Maybe.Just", 264 }), { "Data.Maybe∷Maybe.Just", 265 }), {
    "Data.Maybe∷Maybe.Just",
    266
  }), { "Data.Maybe∷Maybe.Just", 267 }), { "Data.Maybe∷Maybe.Just", 268 }), {
    "Data.Maybe∷Maybe.Just",
    269
  }), { "Data.Maybe∷Maybe.Just", 270 }), { "Data.Maybe∷Maybe.Just", 271 }), {
    "Data.Maybe∷Maybe.Just",
    272
  }), { "Data.Maybe∷Maybe.Just", 273 }), { "Data.Maybe∷Maybe.Just", 274 }), {
    "Data.Maybe∷Maybe.Just",
    275
  }), { "Data.Maybe∷Maybe.Just", 276 }), { "Data.Maybe∷Maybe.Just", 277 }), {
    "Data.Maybe∷Maybe.Just",
    278
  }), { "Data.Maybe∷Maybe.Just", 279 }), { "Data.Maybe∷Maybe.Just", 280 }), {
    "Data.Maybe∷Maybe.Just",
    281
  })
  return Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(Golden_LongApplyChain_Test_applySecond_S_w(_S_tmp653, {
    "Data.Maybe∷Maybe.Just",
    282
  }), { "Data.Maybe∷Maybe.Just", 283 }), { "Data.Maybe∷Maybe.Just", 284 }), {
    "Data.Maybe∷Maybe.Just",
    285
  }), { "Data.Maybe∷Maybe.Just", 286 }), { "Data.Maybe∷Maybe.Just", 287 }), {
    "Data.Maybe∷Maybe.Just",
    288
  }), { "Data.Maybe∷Maybe.Just", 289 }), { "Data.Maybe∷Maybe.Just", 290 }), {
    "Data.Maybe∷Maybe.Just",
    291
  }), { "Data.Maybe∷Maybe.Just", 292 }), { "Data.Maybe∷Maybe.Just", 293 }), {
    "Data.Maybe∷Maybe.Just",
    294
  }), { "Data.Maybe∷Maybe.Just", 295 }), { "Data.Maybe∷Maybe.Just", 296 }), {
    "Data.Maybe∷Maybe.Just",
    297
  }), { "Data.Maybe∷Maybe.Just", 298 }), { "Data.Maybe∷Maybe.Just", 299 }), {
    "Data.Maybe∷Maybe.Just",
    300
  })
end)()
return Effect_Console_foreign.log((function()
  if "Data.Maybe∷Maybe.Just" == Golden_LongApplyChain_Test_compute[1] then
    return "(Just " .. Data_Show_foreign.showIntImpl(Golden_LongApplyChain_Test_compute[2]) .. ")"
  else
    return "Nothing"
  end
end)())()
