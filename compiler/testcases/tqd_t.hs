-- qsort :: Ord a => [a] -> [a]
qsort []     = []
qsort (x:xs) = qsort smaller ++ [x] ++ qsort larger
               where
                 smaller = [a | a <- xs, a <= x]
                 larger  = [b | b <- xs, b > x]
                 
-- main :: IO ()
main = 
  do let helo = "Hello, World!" 
     putStrLn helo
     putStrLn.show $ qsort [3, 1, 4, 1, 5, 9, 2, 6, 5]
     putStrLn $ show $ qsort helo
infixl 1 >>, >>=

class Monad m where
  return :: a -> m a
  (>>=)  :: m a -> (a -> m b) -> m b
  (>>)   :: m a -> m b -> m b
  fail   :: String -> m a

  -- Minimal complete definition: (>>=), return
  p >> q = p >>= \_ -> q
  fail s = error s
  (>>=) = error ">>= is not defined."

instance Monad IO where
  return = primRetIO
  (>>=)  = primBindIO
  fail s = primFailIO s

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

foldr :: (a -> b -> b) -> b -> [a] -> b
foldr k z = go
            where go []     = z
                  go (y:ys) = y `k` go ys

infix 4 >, <=
a > b = PrimGt a b
a <= b = PrimLe a b


