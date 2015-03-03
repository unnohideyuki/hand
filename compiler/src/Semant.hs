module Semant where

import Control.Monad.State (State, state)
import Symbol
import qualified Absyn as A
import Typing

data FixtyInfo = LeftAssoc  Int
               | RightAssoc Int
               | NoAssoc    Int
                 deriving (Show, Eq)

data Level = Level { lv_prefix :: Id
                   , lv_dict   :: Table Id
                   , lv_num    :: Int
                   }
             deriving Show

initialLevel      :: Maybe Name -> Level
initialLevel modid = Level { lv_prefix = case modid of
                                Just s  -> orig_name s
                                Nothing -> "Main"
                           , lv_dict   = empty
                           , lv_num    = 0
                           }

-- Renaming Monad

data RnState = RnState { rn_modid  :: Id
                       , rn_lvs    :: [Level]
                       , rn_tenv   :: Table Id
                       , rn_ifxenv :: Table FixtyInfo
                       -- , rn_ce     :: ClassEnv
                       }
               deriving Show

type RN a = State RnState a

renameVar :: Name -> RN ()
renameVar name = state $ \st@RnState{rn_lvs=(lv:lvs)} ->
  let
    prefix = lv_prefix lv
    qname = (++) (prefix ++ ".")
    n = orig_name name
    dict' = insert n (qname n) (lv_dict lv)
    lv' = lv{lv_dict=dict'}
  in
   ((), st{rn_lvs=(lv':lvs)})

regFixity :: A.Fixity -> Int -> [Name] -> RN ()
regFixity _ _ [] = return ()
regFixity fixity i (n:ns) = do reg (f i) n; regFixity fixity i ns
  where f = case fixity of
          A.Infixl -> LeftAssoc
          A.Infixr -> RightAssoc
          A.Infix  -> NoAssoc
        reg finfo name = state $ \st@RnState{rn_lvs=(lv:_), rn_ifxenv=ifxenv} ->
          let
            qn = (lv_prefix lv) ++ "." ++ (orig_name name)
            ifxenv' = insert qn finfo ifxenv
          in
           if defined (Symbol.lookup qn ifxenv) then
             error $ "duplicate fixity declaration:" ++ qn
           else
             ((), st{rn_ifxenv=ifxenv'})

collectNames :: [A.Decl] -> RN ()
collectNames [] = return ()
collectNames (decl:decls) = do collname decl; collectNames decls
  where
    extrName (A.VarExp name)       = name
    extrName (A.FunAppExp f _)     = extrName f
    extrName (A.InfixExp _ name _) = name
    extrName e                     = error $ "unexpected exp:" ++ show e

    collname (A.ValDecl e _) = renameVar (extrName e)
    collname (A.FixSigDecl fixity i ns) = regFixity fixity i ns
    collname _               = return ()

type TempBinds = (Id, Maybe Scheme, [Alt])

