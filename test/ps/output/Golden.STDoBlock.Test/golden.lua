local function PSLUA_runtime_lazy(name)
  return function(init)
    local state = 0
    local val = nil
    return function()
      if state == 2 then
        return val
      elseif state == 1 then
        return error(name .. " was needed before it finished initializing")
      else
        state = 1
        val = init()
        state = 2
        return val
      end
    end
  end
end
local M = {}
local Data_Show_foreign = { showIntImpl = function(n) return tostring(n) end }
local Control_Monad_ST_Internal_foreign = {
  map_ = function(f)
    return function(a) return function() return f(a()) end end
  end,
  pure_ = function(a) return function() return a end end,
  bind_ = function(a)
    return function(f) return function() return f(a())() end end
  end,
  run = function(f) return f() end,
  new = function(val) return function() return { value = val } end end,
  read = function(ref) return function() return ref.value end end,
  modifyImpl = function(f)
    return function(ref)
      return function()
        local t = f(ref.value)
        ref.value = t.state
        return t.value
      end
    end
  end
}
local Control_Monad_ST_Internal_modifyImpl = Control_Monad_ST_Internal_foreign.modifyImpl
local Control_Monad_ST_Internal_new = Control_Monad_ST_Internal_foreign.new
local Control_Monad_ST_Internal_read = Control_Monad_ST_Internal_foreign.read
local Control_Monad_ST_Internal_run = Control_Monad_ST_Internal_foreign.run
local Effect_Console_foreign = {
  log = function(s) return function() print(s) end end
}
local Control_Monad_ST_Internal_bindST
local Control_Monad_ST_Internal_applicativeST
local Control_Monad_ST_Internal_monadST = {
  Applicative0 = function() return Control_Monad_ST_Internal_applicativeST end,
  Bind1 = function() return Control_Monad_ST_Internal_bindST end
}
local Control_Monad_ST_Internal_Lazy_applyST
Control_Monad_ST_Internal_bindST = {
  bind = Control_Monad_ST_Internal_foreign.bind_,
  Apply0 = function() return Control_Monad_ST_Internal_Lazy_applyST(0) end
}
Control_Monad_ST_Internal_applicativeST = {
  pure = Control_Monad_ST_Internal_foreign.pure_,
  Apply0 = function() return Control_Monad_ST_Internal_Lazy_applyST(0) end
}
Control_Monad_ST_Internal_Lazy_applyST = PSLUA_runtime_lazy("applyST")(function(  )
  return {
    apply = (function()
      local bind_S_445 = (Control_Monad_ST_Internal_monadST.Bind1()).bind
      return function(f_S_446)
        return function(a_S_447)
          return bind_S_445(f_S_446)(function(fPrime_S_448)
            return bind_S_445(a_S_447)(function(aPrime_S_449)
              return (Control_Monad_ST_Internal_monadST.Applicative0()).pure(fPrime_S_448(aPrime_S_449))
            end)
          end)
        end
      end
    end)(),
    Functor0 = function()
      return { map = Control_Monad_ST_Internal_foreign.map_ }
    end
  }
end)
local Golden_STDoBlock_Test_add_S_w = function(x_S_425_S_451, y_S_426_S_452)
  return x_S_425_S_451 + y_S_426_S_452
end
M.Golden_STDoBlock_Test_sumTwice = function(n)
  return Control_Monad_ST_Internal_run(function()
    local ref = Control_Monad_ST_Internal_new(0)()
    local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_457)
      local sPrime_S_458 = Golden_STDoBlock_Test_add_S_w(s_S_457, n)
      return { state = sPrime_S_458, value = sPrime_S_458 }
    end)(ref)()
    local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_460)
      local sPrime_S_461 = Golden_STDoBlock_Test_add_S_w(s_S_460, n)
      return { state = sPrime_S_461, value = sPrime_S_461 }
    end)(ref)()
    local total = Control_Monad_ST_Internal_read(ref)()
    return Control_Monad_ST_Internal_applicativeST.pure(Golden_STDoBlock_Test_add_S_w(total, 1))()
  end)
end
return Effect_Console_foreign.log(Data_Show_foreign.showIntImpl(Control_Monad_ST_Internal_run(function(  )
  local ref_S_467 = Control_Monad_ST_Internal_new(0)()
  local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_472)
    local sPrime_S_473 = Golden_STDoBlock_Test_add_S_w(s_S_472, 5)
    return { state = sPrime_S_473, value = sPrime_S_473 }
  end)(ref_S_467)()
  local _ = Control_Monad_ST_Internal_modifyImpl(function(s_S_475)
    local sPrime_S_476 = Golden_STDoBlock_Test_add_S_w(s_S_475, 5)
    return { state = sPrime_S_476, value = sPrime_S_476 }
  end)(ref_S_467)()
  local total_S_468 = Control_Monad_ST_Internal_read(ref_S_467)()
  return Control_Monad_ST_Internal_applicativeST.pure(Golden_STDoBlock_Test_add_S_w(total_S_468, 1))()
end)))()
