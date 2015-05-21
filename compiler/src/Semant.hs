module Semant where

import Data.List (foldl')
import Control.Monad.State.Strict (State, state, get, put)
import Data.Maybe
import Symbol
import qualified Absyn as A
import Types
import Typing
import PreDefined

import Debug.Trace

econst  :: Assump -> Expr
econst c = (Const c)

pNil :: Pat
pNil  = PCon nilCfun []

eNil :: Expr
eNil  = econst nilCfun

aTrue :: A.Exp
aTrue  = A.VarExp $ Name "True" "" (0,0) True

aFalse :: A.Exp
aFalse  = A.VarExp $ Name "False" "" (0,0) True

aThen :: A.Exp
aThen  = A.VarExp $ Name ">>" "" (0,0) False

aNil :: A.Exp
aNil  = A.VarExp $ Name "[]" "" (0,0) True

aCons :: A.Exp
aCons  = A.VarExp $ Name ":" "" (0,0) True

aBind :: A.Exp
aBind  = A.VarExp $ Name ">>=" "" (0,0) False

data FixtyInfo = LeftAssoc  Int
               | RightAssoc Int
               | NoAssoc    Int
                 deriving (Show, Eq)

data Level = Level { lv_prefix :: !Id
                   , lv_dict   :: !(Table Id)
                   , lv_num    :: !Int
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

data RnState = RnState { rn_modid  :: !Id
                       , rn_lvs    :: !([Level])
                       , rn_tenv   :: !(Table Id)
                       , rn_ifxenv :: !(Table FixtyInfo)
                       , rn_ce     :: !(ClassEnv)
                       , rn_cms    :: !([Assump])
                       , rn_tbs    :: !([TempBinds])
                       }
               deriving Show

type RN a = State RnState a

renameVar :: Name -> RN Id
renameVar name = state $ \st@RnState{rn_lvs=(lv:lvs)} ->
  let
    prefix = lv_prefix lv
    n  = orig_name name
    n' = prefix ++ "." ++ n
    dict' = insert n n' (lv_dict lv)
    lv' = lv{lv_dict=dict'}
  in
   (n', st{rn_lvs=(lv':lvs)})

regFixity :: A.Fixity -> Int -> [Name] -> RN ()
regFixity _ _ [] = return ()
regFixity fixity i (n:ns) = do reg (f i) n; regFixity fixity i ns
  where f = case fixity of
          A.Infixl -> LeftAssoc
          A.Infixr -> RightAssoc
          A.Infix  -> NoAssoc
        reg finfo name = state $ \st@RnState{rn_lvs=(lv:lvs), rn_ifxenv=ifxenv} ->
          let
            qn = (lv_prefix lv) ++ "." ++ (orig_name name)
            ifxenv' = insert qn finfo ifxenv
          in
           if defined (tabLookup qn ifxenv) then
             error $ "duplicate fixity declaration:" ++ qn
           else
             ((), st{rn_ifxenv=ifxenv'})

collectNames :: ([A.Decl], [A.Decl], [A.Decl]) -> [A.Decl]
                -> RN ([A.Decl], [A.Decl], [A.Decl])
collectNames x [] = return x
collectNames (ds, cds, ids) (decl:decls) = do
  (ds', cds', ids') <- collname decl
  collectNames (ds', cds', ids') decls
  where
    extrName (A.VarExp name)       = name
    extrName (A.FunAppExp f _)     = extrName f
    extrName (A.InfixExp _ name _) = name
    extrName e                     = error $ "unexpected exp:" ++ show e

    collname d@(A.ValDecl e _) = do _ <- renameVar (extrName e)
                                    return (ds ++ [d], cds, ids)
    collname (A.FixSigDecl fixity i ns) = do regFixity fixity i ns
                                             return (ds, cds, ids)

    collname d@(A.TypeSigDecl _ _)      = return (ds ++ [d], cds, ids)

    collname (A.DefaultDecl _)          = error "not yet: DefaultDecl"
    collname (A.ForeignDecl _)          = error "not yet: ForeignDecl"
    collname (A.SynonymDecl _ _)        = error "not yet: SynonymDecl"


    collname d@(A.ClassDecl (_, A.AppTy (A.Tycon n) _) ds') = do
      _ <- renameVar n
      mapM_ colname' ds'
      return (ds, cds ++ [d], ids)
      where colname' (A.ValDecl e _) = do _ <- renameVar (extrName e)
                                          return ()
            colname' _ = return ()


    collname d@(A.InstDecl _ _)         = return (ds, cds, ids ++ [d])

    collname (A.DataDecl _ _ _)         = error "not yet: DataDecl"
    collname (A.NewtypeDecl _ _ _)      = error "not yet: NewtypeDecl"

type TempBinds = (Id, Maybe Scheme, [Alt])


renProg  :: A.Module -> RN ([TempBinds], [Assump])
renProg m = do
  let body = snd (A.body m)
  (ds, cds, ids) <- collectNames ([], [], []) body
  renCDecls cds
  tbs <- renDecls ds
  return (tbs, [])

renCDecls :: [A.Decl] -> RN ()
renCDecls [] = return ()
renCDecls ((A.ClassDecl cls ds):cds) = do
  clsadd cls
  renDecls $ addvar cls ds
  renCDecls cds
  where clsadd (ctx, (A.AppTy (A.Tycon n) _)) = do
          cname <- qname $ orig_name n
          st <- get
          let ce = rn_ce st
              Just ce' = addClass cname [] ce -- todo: super class?
          put $ st{rn_ce=ce'}
          trace (show ce') $ return ()
        addvar cls ds = let (_, sigvar) = cls
                            f (A.TypeSigDecl ns (_, sigdoc)) =
                              A.TypeSigDecl ns (Just sigvar, sigdoc)
                            f d = d
                        in map f ds

renDecls :: [A.Decl] -> RN [TempBinds]
renDecls [] = do
  st <- get
  return $ rn_tbs st
renDecls (d:ds) = do
  ntbs <- renDecl d
  st <- get
  let tbs = rn_tbs st
      tbs' = tbs++ntbs
  put st{rn_tbs=tbs'}
  renDecls ds

renDecl :: A.Decl -> RN [TempBinds]
renDecl (A.ValDecl expr rhs) = do
  enterNewLevel
  (n, pats) <- renFExp expr
  rexp      <- renRhs  rhs
  exitLevel
  return [(n, Nothing, [(pats, rexp)])]

renDecl (A.TypeSigDecl ns (maybe_sigvar, sigdoc)) = do
  trace (show (ns, maybe_sigvar, sigdoc)) $ return ()
  ns' <- mapM renameVar ns
  let kdict = kiExpr sigdoc []
  kdict `seq` return ()
  ps <- renSigvar maybe_sigvar kdict
  t <- renSigdoc sigdoc kdict
  let scheme = mkScheme (ps :=> t) kdict
  t `seq` scheme `seq` return [(n, Just scheme, []) | n <- ns']

renDecl decl = trace (show ("non-exhaustive", decl)) $
               return [("", Nothing, [])]

kiExpr :: A.Type -> [(Id, Kind)] -> [(Id, Kind)]
kiExpr (A.FunTy t1 t2) dict =
  let dict' = kiExpr t1 dict
  in kiExpr t2 dict'
kiExpr (A.AppTy t1 t2) dict = dict ++ [(extrid t1, Kfun Star Star)
                                      ,(extrid t2, Star)]
  where extrid (A.Tyvar n) = orig_name n
kiExpr (A.Tyvar n) dict = dict ++ [(orig_name n, Star)]
kiExpr (A.ParTy e) dict = kiExpr e dict
kiExpr t dict = trace (show (t, "kiExpr")) $ error "kiExpr"

renSigvar :: Maybe A.Type -> [(Id, Kind)] -> RN [Pred]
renSigvar Nothing _ = return []
renSigvar (Just (A.AppTy (A.Tycon n) (A.Tyvar m))) kdict = do
  qn <- qname $ orig_name n
  let vname = orig_name m
      k = kindLookup vname kdict
  return [IsIn qn (TVar (Tyvar vname k))]

renSigvar _ _ = error "renSigvar"

renSigdoc :: A.Type -> [(Id, Kind)] -> RN Type
renSigdoc (A.FunTy e1 e2) kdict = do
  t1 <- renSigdoc e1 kdict
  t2 <- renSigdoc e2 kdict
  return (t1 `fn` t2)
renSigdoc (A.Tyvar n) kdict = let vname = orig_name n
                                  k = kindLookup vname kdict
                              in return (TVar (Tyvar vname k))
renSigdoc (A.AppTy e1 e2) kdict = do
  t1 <- renSigdoc e1 kdict
  t2 <- renSigdoc e2 kdict
  return (TAp t1 t2)

renSigdoc (A.ParTy e) kdict = renSigdoc e kdict

renSigdoc t kdict = trace (show t) $ error "renSigdoc"

kindLookup n kdict = case lookup n kdict of
  Just k -> k
  Nothing -> error $ "Kind not infered" ++ n

mkScheme :: (Qual Type) -> [(Id, Kind)] -> Scheme
mkScheme qt kdict = let vs = map (\(n, k) -> Tyvar n k) kdict
                    in quantify vs qt

-- Todo:
renFExp :: A.Exp -> RN (Id, [Pat])

renFExp (A.VarExp n) = do
  qname_f <- qname (orig_name n)
  return (qname_f, [])

renFExp e@(A.FunAppExp _ _) = do
  renfexp' e []
  where
    renfexp' (A.FunAppExp e@(A.FunAppExp _ _) e') pats = do
      pat <- renPat e'
      renfexp' e (pat:pats)
    renfexp' (A.FunAppExp (A.VarExp n) e) pats = do
      qn <- qname (orig_name n)
      pat <- renPat e
      return (qn, pat:pats)

renFExp (A.InfixExp le op re) = do
  qname_op <- qname (orig_name op)
  lpat <- renPat le
  rpat <- renPat re
  return (qname_op, [lpat, rpat])

renFExp e = trace (show e) $ error "renFExp"

renPat (A.VarExp n) | isConName n = do qn <- qname (orig_name n)
                                       Just a <- findCMs qn
                                       return $ PCon a []
                    | otherwise   = do qn <- renameVar n
                                       return $ PVar qn

renPat (A.ParExp e) = renPat e

-- TODO: DRY! renExp and renPats have
renPat(A.InfixExp (A.InfixExp rest op2 e2) op1 e1) = do
  (prec1, fix1) <- lookupInfixOp op1
  (prec2, fix2) <- lookupInfixOp op2
  if prec1 == prec2 && (fix1 /= fix2 || fix1 == A.Infix)
    then fail "fixty resolution error."
    else if prec1 > prec2 || (prec1 == prec2 && fix1 == A.Infixr)
         then renPat (A.InfixExp rest op2 (opAppExp op1 e2 e1))
         else renPat (opAppExp op1 (A.InfixExp rest op2 e2) e1)
  where
    opAppExp op e e' = (A.FunAppExp (A.FunAppExp (A.VarExp op) e) e')

renPat (A.InfixExp e2 op e1) =
  renPat (A.FunAppExp (A.FunAppExp (A.VarExp op) e2) e1)

renPat (A.FunAppExp e e') = renPCon (A.FunAppExp e e') []
  where renPCon (A.FunAppExp (A.FunAppExp e e') e'') pats = do
          pat <- renPat e''
          renPCon (A.FunAppExp e e') (pat:pats)
        renPCon (A.FunAppExp (A.VarExp n) e') pats = do
          qn <- qname (orig_name n)
          Just a <- findCMs qn
          pat' <- renPat e'
          return $ PCon a (pat':pats)

renPat A.WildcardPat = return PWildcard

renPat e = trace (show e) $ error "renPat"

renRhs :: A.Rhs -> RN Expr
renRhs (A.UnguardedRhs (A.VarExp n) []) = do
  qname_c <- qname (orig_name n)
  c_pat   <- findCMs qname_c
  case c_pat of
    Just pat -> return (Const pat)
    Nothing | not (isConName n) -> return (Var qname_c)

renRhs (A.UnguardedRhs e []) = renExp e

renRhs (A.UnguardedRhs e ds) =
  renRhs (A.UnguardedRhs (A.LetExp ds e) [])

renRhs rhs = do
  st <- get
  trace (show (st, rhs)) $ error "renRhs not yet implemented."

renExp (A.InfixExp (A.InfixExp rest op2 e2) op1 e1) = do
  (prec1, fix1) <- lookupInfixOp op1
  (prec2, fix2) <- lookupInfixOp op2
  if prec1 == prec2 && (fix1 /= fix2 || fix1 == A.Infix)
    then fail "fixty resolution error."
    else if prec1 > prec2 || (prec1 == prec2 && fix1 == A.Infixr)
         then renExp (A.InfixExp rest op2 (opAppExp op1 e2 e1))
         else renExp (opAppExp op1 (A.InfixExp rest op2 e2) e1)
  where
    opAppExp op e e' = (A.FunAppExp (A.FunAppExp (A.VarExp op) e) e')

renExp (A.InfixExp e2 op e1) = 
  renExp (A.FunAppExp (A.FunAppExp (A.VarExp op) e2) e1)

renExp (A.FunAppExp e1 e2) = do
  expr1 <- renExp e1
  expr2 <- renExp e2
  return (Ap expr1 expr2)

renExp (A.VarExp name) = do
  qn <- qname (orig_name name)
  return (Var qn)

renExp (A.LitExp (A.LitInteger i _)) = do
  return (Lit (LitInt i))

renExp (A.LetExp ds e) = do
  enterNewLevel
  (ds', _, _) <- collectNames ([], [], []) ds
  renDecls ds'
  st <- get
  r <- renExp e
  exitLevel
  return r

-- List comprehension
-- [e | True] = [e]
-- [e | q] = [q, True]
renExp (A.ListCompExp e [stmt@(A.ExpStmt p)]) =
  case p of
    A.VarExp n  | orig_name n == "True" -> renExp (A.ListExp [e])
                | otherwise             -> ren'
    _                                   -> ren'
  where ren' = renExp (A.ListCompExp e [stmt, A.ExpStmt aTrue])

-- [e | b, Q] = if b then [e | Q] else []
renExp (A.ListCompExp e ((A.ExpStmt b):stmts)) =
  renExp (A.IfExp b (A.ListCompExp e stmts) nil)
  where nil = A.VarExp $ Name "[]" "" (0,0) True

-- [e | p <- l, Q] = let ok p = [e | Q] in concatMap ok l
renExp (A.ListCompExp e ((A.BindStmt p l):stmts)) = renExp letexp
  where
    ok = Name "OK" "" (0,0) False -- "OK" is fresh,  will never parsed as a variable.
    okp = A.FunAppExp (A.VarExp ok) p
    rhs = case stmts of
      [] -> A.UnguardedRhs (A.ListExp [e]) []
      _  -> A.UnguardedRhs (A.ListCompExp e stmts) []
    decl = A.ValDecl okp rhs
    body = A.FunAppExp (A.FunAppExp (A.VarExp $ Name "concatMap" "" (0,0) False)
                                    (A.VarExp ok))
                       l
    letexp = A.LetExp [decl] body

-- [e | let decls, Q] = let decls in [e | Q]
renExp (A.ListCompExp e ((A.LetStmt decls):stmts)) = renExp letexp
  where
    body = case stmts of
      [] -> A.ListExp [e]
      _  -> A.ListCompExp e stmts
    letexp = A.LetExp decls body

renExp (A.IfExp c t f) = renExp caseexp
  where
    alt1 = A.Match aTrue (A.UnguardedRhs t [])
    alt2 = A.Match aFalse (A.UnguardedRhs f [])
    caseexp = A.CaseExp c [alt1, alt2]

renExp (A.CaseExp c alts) = renExp (A.LetExp decls fc)
  where f = Name "F" "" (0,0) False
        fc = A.FunAppExp (A.VarExp f) c
        decls = map (\(A.Match p rhs) ->
                      A.ValDecl (A.FunAppExp (A.VarExp f) p) rhs) alts

renExp (A.ListExp [e]) =
  renExp $ A.FunAppExp (A.FunAppExp aCons e) aNil

renExp (A.ListExp (e:es)) =
  renExp $ A.FunAppExp (A.FunAppExp aCons e) (A.ListExp es)

renExp (A.DoExp [stmt]) = case stmt of
  A.ExpStmt e -> renExp e
  _ -> fail "The last statement in a 'do' block must be an expression"

renExp (A.DoExp (A.ExpStmt e:stmts)) =
  renExp $ A.FunAppExp (A.FunAppExp aThen e) (A.DoExp stmts)

renExp (A.DoExp ((A.BindStmt p e):stmts)) = renExp letexp
  where
    ok = Name "OK" "" (0,0) False
    okp = A.FunAppExp (A.VarExp ok) p
    rhs = A.UnguardedRhs (A.DoExp stmts) []
    decl = A.ValDecl okp rhs
    body = A.FunAppExp (A.FunAppExp aBind e) (A.VarExp ok)
    letexp = A.LetExp [decl] body

renExp (A.DoExp ((A.LetStmt decls):stmts)) = renExp letexp
  where
    letexp = A.LetExp decls (A.DoExp stmts)

renExp (A.LamExp args e) = renExp (A.LetExp [decl] f)
  where f = A.VarExp $ Name "F" "" (0,0) False
        fexp = foldl' A.FunAppExp f args
        rhs = A.UnguardedRhs e []
        decl = A.ValDecl fexp rhs

renExp (A.LitExp (A.LitString s _)) =
  return $ Lit (LitStr s)

renExp (A.LitExp (A.LitInteger i _)) =
  return $ Lit (LitInt i)

renExp (A.ParExp e) = renExp e

renExp e = trace (show e) $ error "Non-exhaustive patterns in renExp."

lookupInfixOp :: Name -> RN (Int, A.Fixity)
lookupInfixOp op = do
  op_qname <- qname (orig_name op)
  st <- get
  case tabLookup op_qname (rn_ifxenv st) of
    Just (LeftAssoc  x) -> return (x, A.Infixl)
    Just (RightAssoc x) -> return (x, A.Infixr)
    Just (NoAssoc    x) -> return (x, A.Infix)
    Nothing             -> return (9, A.Infixl)

qname   :: Id -> RN Id
qname name = state $ \st@RnState{rn_lvs=lvs} -> (findQName lvs name, st)
  where findQName [] n = error $ "qname not found: " ++ n
        findQName (lv:lvs) n = case tabLookup n (lv_dict lv) of
          Just qn -> qn
          Nothing -> findQName lvs n

findCMs   :: Id -> RN (Maybe Assump)
findCMs qn = state $ \st@RnState{rn_cms=as} -> (find' as qn, st)
  where find' [] _ = Nothing
        find' (a@(n :>: _):as') qn' | n == qn'  = Just a
                                    | otherwise = find' as' qn'

pushLv :: Level -> RN ()
pushLv lv = state $ \st@RnState{rn_lvs=lvs} ->
  ((), st{rn_lvs=(lv:lvs)})

getPrefix :: RN Id
getPrefix = state $ \st@RnState{rn_lvs=(lv:_)} -> (lv_prefix lv, st)

newNum :: RN Int
newNum = state $ \st@RnState{rn_lvs=(lv:lvs)} ->
  let n   = lv_num lv
      lv' = lv{lv_num=n+1}
  in (n, st{rn_lvs=(lv':lvs)})

enterNewLevelWith :: Id -> RN ()
enterNewLevelWith n = do
  currPrefix <- getPrefix
  let newPrefix = currPrefix ++ "." ++ n
      lv = Level newPrefix empty 0
  pushLv lv

enterNewLevel :: RN ()
enterNewLevel = do
  n <- newNum
  enterNewLevelWith ("l" ++ show n)

exitLevel :: RN ()
exitLevel = do
  st <- get
  let lvs' = tail $ rn_lvs st
  put st{rn_lvs=lvs'}



