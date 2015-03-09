module Main where

import Parser
import qualified Absyn
import Semant
import Symbol
import PreDefined

import Control.Monad.State (runState)

do_semant :: Absyn.Module -> IO ()
do_semant m = do
  -- TODO: regular way to add primitive names.
  let lv = (initialLevel $ Absyn.modid m){lv_dict=primNames}
  print lv
  let body = snd $ Absyn.body m
  -- print body
  -- let result = collectTopNames (lv_prefix lv) (empty, empty) body
  let st = RnState (lv_prefix lv) [lv] empty empty preludeClasses
      result = runState (collectNames ([],[],[]) body) st
  print result

main :: IO ()
main = do
  s <- getContents
  let r = parse s
  case r of
    Left  mes -> putStrLn $ "Error: " ++ mes
    Right m -> do do_semant m
                  
