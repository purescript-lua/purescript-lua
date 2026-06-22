module Golden.LongStateBind.Test where

import Prelude

import Control.Monad.State (State, evalState, get, put)
import Effect (Effect)
import Effect.Console (logShow)

go :: State Int Int
go = do
  x1 <- get
  put (x1 + 1)
  x2 <- get
  put (x2 + 1)
  x3 <- get
  put (x3 + 1)
  x4 <- get
  put (x4 + 1)
  x5 <- get
  put (x5 + 1)
  x6 <- get
  put (x6 + 1)
  x7 <- get
  put (x7 + 1)
  x8 <- get
  put (x8 + 1)
  x9 <- get
  put (x9 + 1)
  x10 <- get
  put (x10 + 1)
  x11 <- get
  put (x11 + 1)
  x12 <- get
  put (x12 + 1)
  x13 <- get
  put (x13 + 1)
  x14 <- get
  put (x14 + 1)
  x15 <- get
  put (x15 + 1)
  x16 <- get
  put (x16 + 1)
  x17 <- get
  put (x17 + 1)
  x18 <- get
  put (x18 + 1)
  x19 <- get
  put (x19 + 1)
  x20 <- get
  put (x20 + 1)
  x21 <- get
  put (x21 + 1)
  x22 <- get
  put (x22 + 1)
  x23 <- get
  put (x23 + 1)
  x24 <- get
  put (x24 + 1)
  x25 <- get
  put (x25 + 1)
  x26 <- get
  put (x26 + 1)
  x27 <- get
  put (x27 + 1)
  x28 <- get
  put (x28 + 1)
  x29 <- get
  put (x29 + 1)
  x30 <- get
  put (x30 + 1)
  x31 <- get
  put (x31 + 1)
  x32 <- get
  put (x32 + 1)
  x33 <- get
  put (x33 + 1)
  x34 <- get
  put (x34 + 1)
  x35 <- get
  put (x35 + 1)
  x36 <- get
  put (x36 + 1)
  x37 <- get
  put (x37 + 1)
  x38 <- get
  put (x38 + 1)
  x39 <- get
  put (x39 + 1)
  x40 <- get
  put (x40 + 1)
  x41 <- get
  put (x41 + 1)
  x42 <- get
  put (x42 + 1)
  x43 <- get
  put (x43 + 1)
  x44 <- get
  put (x44 + 1)
  x45 <- get
  put (x45 + 1)
  x46 <- get
  put (x46 + 1)
  x47 <- get
  put (x47 + 1)
  x48 <- get
  put (x48 + 1)
  x49 <- get
  put (x49 + 1)
  x50 <- get
  put (x50 + 1)
  x51 <- get
  put (x51 + 1)
  x52 <- get
  put (x52 + 1)
  x53 <- get
  put (x53 + 1)
  x54 <- get
  put (x54 + 1)
  x55 <- get
  put (x55 + 1)
  x56 <- get
  put (x56 + 1)
  x57 <- get
  put (x57 + 1)
  x58 <- get
  put (x58 + 1)
  x59 <- get
  put (x59 + 1)
  x60 <- get
  put (x60 + 1)
  x61 <- get
  put (x61 + 1)
  x62 <- get
  put (x62 + 1)
  x63 <- get
  put (x63 + 1)
  x64 <- get
  put (x64 + 1)
  x65 <- get
  put (x65 + 1)
  x66 <- get
  put (x66 + 1)
  x67 <- get
  put (x67 + 1)
  x68 <- get
  put (x68 + 1)
  x69 <- get
  put (x69 + 1)
  x70 <- get
  put (x70 + 1)
  x71 <- get
  put (x71 + 1)
  x72 <- get
  put (x72 + 1)
  x73 <- get
  put (x73 + 1)
  x74 <- get
  put (x74 + 1)
  x75 <- get
  put (x75 + 1)
  x76 <- get
  put (x76 + 1)
  x77 <- get
  put (x77 + 1)
  x78 <- get
  put (x78 + 1)
  x79 <- get
  put (x79 + 1)
  x80 <- get
  put (x80 + 1)
  x81 <- get
  put (x81 + 1)
  x82 <- get
  put (x82 + 1)
  x83 <- get
  put (x83 + 1)
  x84 <- get
  put (x84 + 1)
  x85 <- get
  put (x85 + 1)
  x86 <- get
  put (x86 + 1)
  x87 <- get
  put (x87 + 1)
  x88 <- get
  put (x88 + 1)
  x89 <- get
  put (x89 + 1)
  x90 <- get
  put (x90 + 1)
  x91 <- get
  put (x91 + 1)
  x92 <- get
  put (x92 + 1)
  x93 <- get
  put (x93 + 1)
  x94 <- get
  put (x94 + 1)
  x95 <- get
  put (x95 + 1)
  x96 <- get
  put (x96 + 1)
  x97 <- get
  put (x97 + 1)
  x98 <- get
  put (x98 + 1)
  x99 <- get
  put (x99 + 1)
  x100 <- get
  put (x100 + 1)
  x101 <- get
  put (x101 + 1)
  x102 <- get
  put (x102 + 1)
  x103 <- get
  put (x103 + 1)
  x104 <- get
  put (x104 + 1)
  x105 <- get
  put (x105 + 1)
  x106 <- get
  put (x106 + 1)
  x107 <- get
  put (x107 + 1)
  x108 <- get
  put (x108 + 1)
  x109 <- get
  put (x109 + 1)
  x110 <- get
  put (x110 + 1)
  x111 <- get
  put (x111 + 1)
  x112 <- get
  put (x112 + 1)
  x113 <- get
  put (x113 + 1)
  x114 <- get
  put (x114 + 1)
  x115 <- get
  put (x115 + 1)
  x116 <- get
  put (x116 + 1)
  x117 <- get
  put (x117 + 1)
  x118 <- get
  put (x118 + 1)
  x119 <- get
  put (x119 + 1)
  x120 <- get
  put (x120 + 1)
  x121 <- get
  put (x121 + 1)
  x122 <- get
  put (x122 + 1)
  x123 <- get
  put (x123 + 1)
  x124 <- get
  put (x124 + 1)
  x125 <- get
  put (x125 + 1)
  x126 <- get
  put (x126 + 1)
  x127 <- get
  put (x127 + 1)
  x128 <- get
  put (x128 + 1)
  x129 <- get
  put (x129 + 1)
  x130 <- get
  put (x130 + 1)
  x131 <- get
  put (x131 + 1)
  x132 <- get
  put (x132 + 1)
  x133 <- get
  put (x133 + 1)
  x134 <- get
  put (x134 + 1)
  x135 <- get
  put (x135 + 1)
  x136 <- get
  put (x136 + 1)
  x137 <- get
  put (x137 + 1)
  x138 <- get
  put (x138 + 1)
  x139 <- get
  put (x139 + 1)
  x140 <- get
  put (x140 + 1)
  x141 <- get
  put (x141 + 1)
  x142 <- get
  put (x142 + 1)
  x143 <- get
  put (x143 + 1)
  x144 <- get
  put (x144 + 1)
  x145 <- get
  put (x145 + 1)
  x146 <- get
  put (x146 + 1)
  x147 <- get
  put (x147 + 1)
  x148 <- get
  put (x148 + 1)
  x149 <- get
  put (x149 + 1)
  x150 <- get
  put (x150 + 1)
  final <- get
  pure (x1 + x100 + final)

compute :: Int
compute = evalState go 0

main :: Effect Unit
main = logShow compute
