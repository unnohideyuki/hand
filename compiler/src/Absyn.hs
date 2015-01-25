module Absyn where

type Pos = (Int, Int) -- line number, column number

posLine :: Pos -> Int
posLine (line, _) = line
posCol :: Pos -> Int
posCol (_, col) = col

data Name = Name { name_body :: String
                 , name_qual :: Maybe String
                 , name_pos  :: Pos
                 }
          deriving Show

data Module = Module { modid    :: Name
                     , exports  :: [IE]
                       -- , impdecls :: [Impdecl]
                       -- , topdecls :: [Topdecl]
                     }
             deriving Show

-- | Imported or exported entity
data IE
  = IEVar           Name
  | IEThingAbs      Name        -- ^ Class/Type
  | IEThingAll      Name        -- ^ Class/Type plus all methods/constructors
  | IEThingWith     Name [Name] -- ^ Class/Type plus some methods/constructors
  | IEModuleContens Name        -- ^ Module (export only)
    deriving Show
