module Prelude where

infixr 5 :

class Show a where
  show      :: a -> [Char]
  showsPrec :: Int -> a -> ([Char] -> [Char])
  showList  :: [a] -> ([Char] -> [Char])
  -- Minimal complete definition:
  --  show or showsPrec
  showsPrec p x s = show x ++ s
  show x = showsPrec 0 x ""
  showList []     = (++) "[]"
  showList (x:xs) = (:) '[' . showsPrec 0 x . showl xs
    where showl []     = (:) ']'
          showl (x:xs) = (:) ',' . showsPrec 0 x . showl xs
  
data Bool = False | True

instance Show Bool where
  show = Prim.showConName

instance (Show a) => Show [a] where
  showsPrec p = showList

instance (Show a, Show b) => Show (a, b) where
  show (a, b) = "(" ++ show a ++ "," ++ show b ++ ")"

class Enum a where
  succ, pred     :: a -> a
  toEnum         :: Int -> a
  fromEnum       :: a -> Int
  enumFrom       :: a -> [a]           -- [n..]
  enumFromThen   :: a -> a -> [a]      -- [n,n',..]
  enumFromTo     :: a -> a -> [a]      -- [n..m]
  enumFromThenTo :: a -> a -> a -> [a] -- [n,n'..m]

infixl 7 *, /, `quot`, `rem`, `div`, `mod`
infixl 6 +, -

infixl 1 >>, >>=

class Monad m where
  return :: a -> m a
  (>>=)  :: m a -> (a -> m b) -> m b
  (>>)   :: m a -> m b -> m b
  fail   :: String -> m a

  -- Minimal complete definition: (>>=), return
  p >> q = p >>= \_ -> q
  fail s = error s

instance Monad IO where
  return = Prim.retIO
  (>>=)  = Prim.bindIO
  fail s = Prim.failIO s

-- identity function
id   :: a -> a
id x = x

infixr 0 $
($) :: (a -> b) -> a -> b
f $ x = f x

infixr 9 .
(.) :: (b -> c) -> (a -> b) -> (a -> c)
(.) f g = \x -> f (g x)

infixr 5 ++
(++) :: [a] -> [a] -> [a]
(++) []     ys = ys
(++) (x:xs) ys = x : xs ++ ys

concatMap  :: (a -> [b]) -> [a] -> [b]
concatMap f = foldr ((++) . f) []

head             :: [a] -> a
head (x:xs)      =  x -- todo: wild card
head []          =  error "Prelude.head: empty list"

tail             :: [a] -> [a]
tail (x:xs)      =  xs -- todo wild card
tail []          =  error "Prelude.tail: empty list"

take :: Int -> [a] -> [a]
take n []     = []
take n (x:xs) | n <= 0 = []
              | otherwise = x : take (n-1) xs

foldl            :: (a -> b -> a) -> a -> [b] -> a
foldl f z []     =  z
foldl f z (x:xs) =  foldl f (f z x) xs

foldr :: (a -> b -> b) -> b -> [a] -> b
foldr k z = go
            where go []     = z
                  go (y:ys) = y `k` go ys

infix 4 ==, /=, <, <=, >=, >
infixr 3 &&

(&&) :: Bool -> Bool -> Bool
True  && x = x
False && x = False
  
not :: Bool -> Bool
not True  = False
not False = True

fst :: (a, b) -> a
fst (x, y) = x

snd :: (a, b) -> b
snd (x, y) = y

-- Ordering type
data Ordering = LT | EQ | GT
--              deriving (Eq, Ord, Enum, Read, Show, Bounded)

instance Show Ordering where
  show = Prim.showConName

instance Eq Ordering where
  a == b = case (a, b) of
    (LT, LT) -> True
    (LT, EQ) -> False
    (LT, GT) -> False
    (EQ, LT) -> False
    (EQ, EQ) -> True
    (EQ, GT) -> False
    (GT, LT) -> False
    (GT, EQ) -> False
    (GT, GT) -> True

instance Ord Ordering where
  a <= b = case (a, b) of
    (LT, LT) -> True
    (LT, EQ) -> True
    (LT, GT) -> True
    (EQ, LT) -> False
    (EQ, EQ) -> True
    (EQ, GT) -> True
    (GT, LT) -> False
    (GT, EQ) -> False
    (GT, GT) -> True

-- Equality and Ordered classes

class Eq a where
  (==), (/=) :: a -> a -> Bool
  -- Minimal Complete Definition:
  -- (==) or (/=)
  x /= y = not (x == y)
  x == y = not (x /= y)

class (Eq a) => Ord a where
  compare              :: a -> a -> Ordering
  (<), (<=), (>=), (>) :: a -> a -> Bool
  max, min             :: a -> a -> a
  -- Minimal complete definition:
  --   (<=) or compare
  compare x y
    | x == y    = EQ
    | x <= y    = LT
    | otherwise = GT
  x <= y = compare x y /= GT
  x <  y = compare x y == LT
  x >= y = compare x y /= LT
  x >  y = compare x y == GT
  max x y
    | x <= y    = y
    | otherwise = x
  min x y
    | x <= y    = x
    | otherwise = y

instance Ord Char where
  (<=) = Prim.charLe

instance Eq Char where
  (==) = Prim.charEq

instance Show Char where
  -- todo: escape
  show c = ['\'', c, '\'']
  showList cs = (:) '"' . showl cs
    where showl "" = (:) '"'
          -- showl ('"':cs) = (++) "\\\"" . showl cs
          showl (c:cs) = showLitChar c . showl cs

-- todo: should convert to printable characters
showLitChar c = (++) [c]

class (Eq a) => Num a where
  (+), (-), (*) :: a -> a -> a
  negate        :: a -> a
  signum        :: a -> a
  fromInteger   :: Integer -> a
  -- Minimal complete definition:
  --  All, except negate or (-)
  x - y    = x + nagate y
  negate x = 0 - x


class (Enum a) => Integral a where
  quot, rem       :: a -> a -> a
  div, mod        :: a -> a -> a
  quotRem, divMod :: a -> a -> (a, a)
  toInteger       :: a -> Integer
  -- Minimal complete definition: quotRem, toInteger
  n `quot` d = q where (q,r) = quotRem n d
  n `rem`  d = r where (q,r) = quotRem n d
  n `div`  d = q where (q,r) = divMod n d
  n `mod`  d = r where (q,r) = divMod n d
  divMod n d = if signum r == - signum d then (q-1, r+d) else qr
    where qr@(q,r) = quotRem n d

signum' :: Integer -> Integer
signum' x | x > 0  = 1
          | x == 0 = 0
          | x < 0  = -1

signum'' :: Int -> Int
signum'' x | x > 0  = 1
           | x == 0 = 0
           | x < 0  = -1

instance Num Integer where
  (+)  = Prim.integerAdd
  (-)  = Prim.integerSub
  (*)  = Prim.integerMul
  signum = signum'
  fromInteger = id

instance Integral Integer where
  quotRem = Prim.integerQuotRem
  toInteger = id

instance Ord Integer where
  (<=) = Prim.integerLe

instance Eq Integer where
  (==) = Prim.integerEq

instance Show Integer where
  show = Prim.integerShow

instance Enum Integer where
  succ = (+1)
  pred = (+ (-1))
  toEnum = Prim.integerFromInt
  fromEnum = Prim.intFromInteger
  enumFrom n = n : enumFrom (n+1)
  enumFromTo x y | x > y     = []
                 | otherwise = x : enumFromTo (x+1) y
  enumFromThen x y = x : enumFromThen y (2*y-x)
  enumFromThenTo x y z | x == y && z >= x           = x : enumFromThenTo x y z
                       | x == z                     = [x]
                       | compare x y /= compare x z = []
                       | otherwise                  = x : enumFromThenTo y (2*y-x) z

instance Num Int where
  (+)  = Prim.intAdd
  (-)  = Prim.intSub
  (*)  = Prim.intMul
  signum = signum''
  fromInteger = Prim.intFromInteger

instance Integral Int where
  quotRem = Prim.intQuotRem
  toInteger = Prim.integerFromInt

instance Ord Int where
  (<=) = Prim.intLe

instance Eq Int where
  (==) = Prim.intEq

instance Show Int where
  show = Prim.intShow

instance Enum Int where
  succ = (+1)
  pred = (+ (-1))
  toEnum x = x
  fromEnum x = x
  enumFrom n = n : enumFrom (n+1)
  enumFromTo x y | x > y     = []
                 | otherwise = x : enumFromTo (x+1) y
  enumFromThen x y = x : enumFromThen y (2*y-x)
  enumFromThenTo x y z | x == y && z >= x           = x : enumFromThenTo x y z
                       | x == z                     = [x]
                       | compare x y /= compare x z = []
                       | otherwise                  = x : enumFromThenTo y (2*y-x) z

instance Eq Double where
  (==) = Prim.doubleEq

instance Ord Double where
  (<=) = Prim.doubleLe

instance Num Double where
  (+) = Prim.doubleAdd
  (-) = Prim.doubleSub
  (*) = Prim.doubleMul
  signum = Prim.doubleSignum
  fromInteger = Prim.doubleFromInteger

instance Show Double where
  show = Prim.doubleShow
  showList xs = (++) (showlist' xs)
    where showlist' [] = "[]"
          showlist' [x] =  "[" ++ show x ++ "]"
          showlist' (x:xs) = "[" ++ foldl (\s t -> s ++ "," ++ show t) (show x) xs ++ "]"
          showlist' :: [Double] -> [Char]

instance Eq Float where
  (==) = Prim.floatEq

instance Ord Float where
  (<=) = Prim.floatLe

instance Num Float where
  (+) = Prim.floatAdd
  (-) = Prim.floatSub
  (*) = Prim.floatMul
  signum = Prim.floatSignum
  fromInteger = Prim.floatFromInteger

instance Show Float where
  show = Prim.floatShow
  showList xs = (++) (showlist' xs)
    where showlist' [] = "[]"
          showlist' [x] =  "[" ++ show x ++ "]"
          showlist' (x:xs) = "[" ++ foldl (\s t -> s ++ "," ++ show t) (show x) xs ++ "]"
          showlist' :: [Float] -> [Char]

print x = putStrLn (show x)

otherwise = True
