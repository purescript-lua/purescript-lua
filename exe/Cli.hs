{-# LANGUAGE QuasiQuotes #-}

module Cli where

import Data.Char qualified as Char
import Data.List.NonEmpty qualified as NE
import Data.Tagged (Tagged (..))
import Data.Text (splitOn)
import Data.Text qualified as Text
import Language.PureScript.Backend.Lua.Limits (LuaLimits (..), lua51Limits)
import Language.PureScript.Backend.Types (AppOrModule (..))
import Language.PureScript.Names qualified as PS
import Options.Applicative
  ( Parser
  , ReadM
  , eitherReader
  , execParser
  , flag
  , fullDesc
  , header
  , helpDoc
  , helper
  , info
  , long
  , metavar
  , option
  , progDesc
  , short
  , value
  )
import Path
  ( Dir
  , File
  , SomeBase (..)
  , parseSomeDir
  , parseSomeFile
  , reldir
  , relfile
  )
import Prettyprinter (Doc, annotate, flatAlt, indent, line, vsep, (<+>))
import Prettyprinter qualified as PP
import Prettyprinter.Render.Terminal (AnsiStyle, Color (..))
import Prettyprinter.Render.Terminal qualified as PT

data Args = Args
  { foreignPath ∷ Tagged "foreign" (SomeBase Dir)
  , psOutputPath ∷ Tagged "output" (SomeBase Dir)
  , luaOutputFile ∷ Tagged "output-lua" (SomeBase File)
  , directivesFile ∷ Maybe (Tagged "directives" (SomeBase File))
  , outputIR ∷ Maybe ExtraOutput
  , outputLuaAst ∷ Maybe ExtraOutput
  , lintIR ∷ Tagged "lint-ir" Bool
  , luaLimits ∷ LuaLimits
  , appOrModule ∷ AppOrModule
  , runEntry ∷ Maybe AppOrModule
  }
  deriving stock (Show)

data ExtraOutput = OutputIR | OutputLuaAst
  deriving stock (Eq, Show)

options ∷ Parser Args
options = do
  foreignPath ←
    option (eitherReader (bimap displayException Tagged . parseSomeDir)) $
      fold
        [ metavar "FOREIGN-PATH"
        , long "foreign-path"
        , value $ Tagged $ Rel [reldir|foreign|]
        , helpDoc . Just $
            "Path to a directory containing foreign files."
              <> linebreak
              <> bold "Default: foreign"
        ]

  psOutputPath ←
    option (eitherReader (bimap displayException Tagged . parseSomeDir)) $
      fold
        [ metavar "PS-PATH"
        , long "ps-output"
        , value $ Tagged $ Rel [reldir|output|]
        , helpDoc . Just $
            "Path to purs output directory."
              <> linebreak
              <> bold "Default: output"
        ]

  luaOutputFile ←
    option (eitherReader (bimap displayException Tagged . parseSomeFile)) $
      fold
        [ metavar "LUA-OUT-FILE"
        , long "lua-output-file"
        , value $ Tagged $ Rel [relfile|main.lua|]
        , helpDoc . Just $
            "Path to write compiled Lua file to."
              <> linebreak
              <> bold "Default: main.lua"
        ]

  directivesFile ←
    optional . option (eitherReader (bimap displayException Tagged . parseSomeFile)) $
      fold
        [ metavar "DIRECTIVES-FILE"
        , long "directives"
        , helpDoc . Just $
            vsep
              [ "Path to a file with project-wide inlining directives,"
                  <> softbreak
                  <> "one per line:"
                  <+> magenta "<Module>.<binding><accessor?> <mode>"
              , "- accessor:" <+> magenta ".label" <+> "or" <+> magenta "...label"
              , "- mode:" <+> magenta "default | never | always | arity=N"
              , green $ indent 2 "Example: Data.Lens.over arity=2"
              , "A local module-header pragma overrides the file;"
                  <> softbreak
                  <> "the file overrides @inline export pragmas."
              ]
        ]

  outputLuaAst ←
    flag Nothing (Just OutputLuaAst) . fold $
      [ long "output-lua-ast"
      , helpDoc . Just $
          "Output Lua AST."
            <> linebreak
            <> bold "Default: false"
      ]
  outputIR ←
    flag Nothing (Just OutputIR) . fold $
      [ long "output-ir"
      , helpDoc . Just $
          "Output IR."
            <> linebreak
            <> bold "Default: false"
      ]
  lintIR ←
    flag (Tagged False) (Tagged True) . fold $
      [ long "lint-ir"
      , helpDoc . Just $
          "Check IR invariants after every optimizer pass (debug)."
            <> linebreak
            <> bold "Default: false"
      ]
  targetMaxLocals ←
    option positiveInt . fold $
      [ metavar "N"
      , long "max-locals"
      , value (maxLocals lua51Limits)
      , helpDoc . Just $
          "Target Lua VM's hard limit on local variables"
            <> softbreak
            <> "per function (LUAI_MAXVARS)."
            <> linebreak
            <> bold "Default: 200 (Lua 5.1)"
      ]
  targetMaxUpvalues ←
    option positiveInt . fold $
      [ metavar "N"
      , long "max-upvalues"
      , value (maxUpvalues lua51Limits)
      , helpDoc . Just $
          "Target Lua VM's hard limit on upvalues"
            <> softbreak
            <> "per function (LUAI_MAXUPVALUES)."
            <> linebreak
            <> bold "Default: 60 (Lua 5.1)"
      ]
  appOrModule ←
    option (eitherReader parseAppOrModule) . fold $
      [ metavar "ENTRY"
      , short 'e'
      , long "entry"
      , value $ AsApplication (PS.ModuleName "Main") (PS.Ident "main")
      , helpDoc . Just $
          vsep
            [ "Where to start compilation."
                <> softbreak
                <> "Could be one of the following formats:"
            , "- Application format:" <+> magenta "<Module>.<binding>"
            , green $ indent 2 "Example: Acme.App.main"
            , "- Module format:" <+> magenta "<Module>"
            , green $ indent 2 "Example: Acme.Lib"
            , bold "Default: Main.main"
            ]
      ]
  runEntry ←
    optional . option (eitherReader parseRunEntry) . fold $
      [ metavar "ENTRY"
      , long "run"
      , helpDoc . Just $
          vsep
            [ "Compile the given application entry point and run it with"
                <> softbreak
                <> magenta "lua"
                <> ", forwarding lua's exit code."
            , "This is what" <+> magenta "spago run" <+> "invokes."
            , "Format:" <+> magenta "<Module>.<binding>"
            , green $ indent 2 "Example: Acme.App.main"
            ]
      ]
  pure
    Args
      { luaLimits =
          LuaLimits
            { maxLocals = targetMaxLocals
            , maxUpvalues = targetMaxUpvalues
            }
      , ..
      }

positiveInt ∷ ReadM Int
positiveInt = eitherReader \s → case readMaybe s of
  Just n | n > 0 → Right n
  _ → Left ("expected a positive integer, got: " <> s)

{- | `--run` must name an application entry point (`<Module>.<binding>`): there
is nothing to execute without a binding, so a bare module name is rejected.
-}
parseRunEntry ∷ String → Either String AppOrModule
parseRunEntry s =
  parseAppOrModule s >>= \case
    app@AsApplication {} → pure app
    AsModule _ →
      Left $
        "--run requires an application entry point <Module>.<binding> "
          <> "(e.g. Main.main), not a bare module name: "
          <> s

parseAppOrModule ∷ String → Either String AppOrModule
parseAppOrModule s = case splitOn "." (toText s) of
  [] → Left "Invalid entry point format"
  [name] | isModule name → pure . AsModule $ PS.ModuleName name
  segments → do
    let name = last (NE.fromList segments)
    pure
      if isModule name
        then AsModule . PS.ModuleName $ Text.intercalate "." segments
        else
          let modname = Text.intercalate "." (init (NE.fromList segments))
           in AsApplication (PS.ModuleName modname) (PS.Ident name)
 where
  isModule = Char.isAsciiUpper . Text.head

parseArguments ∷ IO Args
parseArguments =
  execParser $
    info
      (options <**> helper)
      ( fullDesc
          <> progDesc "Compile PureScript's CoreFn to Lua"
          <> header "pslua - a PureScript backend for Lua"
      )

--------------------------------------------------------------------------------
-- Helpers for pretty-printing -------------------------------------------------

linebreak ∷ Doc AnsiStyle
linebreak = flatAlt line mempty

softbreak ∷ Doc AnsiStyle
softbreak = PP.group linebreak

green ∷ Doc AnsiStyle → Doc AnsiStyle
green = annotate (PT.color Green)

magenta ∷ Doc AnsiStyle → Doc AnsiStyle
magenta = annotate (PT.color Magenta)

bold ∷ Doc AnsiStyle → Doc AnsiStyle
bold = annotate PT.bold
