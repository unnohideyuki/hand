primes = sieve [2..]
sieve (p:ps) = p : sieve [q | q <- ps, q `mod` p /= 0]
main = print $ take 100 $ primes
