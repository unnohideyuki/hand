main = do print $ properFraction (3.14 :: Double)
          print $ truncate (1.7 :: Double)
          print $ truncate (-1.7 :: Double)
          print $ round (3.4 :: Double)
          print $ round (3.6 :: Double)
          print $ round (-3.6 :: Double)
          print $ ceiling (3.7 :: Double)
          print $ ceiling (-4.999 :: Double)
          print $ floor (3.001 :: Double)
          print $ floor (-4.999 :: Double)