as = concat $ map (\x -> if even x then [2*x] else []) ([1..10]::[Int])
main = print as
