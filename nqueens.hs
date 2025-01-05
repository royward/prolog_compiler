-- https://albertnetymk.github.io/2018/02/16/queens/

import Data.Time

-- import Control.Monad
-- nqueens n = foldM (\y _ -> [ x : y | x <- [1..n], safe x y 1]) [] [1..n]
--   where
--     safe x [] _ = True
--     safe x (c:y) n = and [ x /= c , x /= c + n , x /= c - n , safe x y (n+1)]

import Data.List (delete)
type Board = [Int]
nqueens :: Int -> [Board]
nqueens n = map fst $ loop [([], [1..n])] 0
  where
    loop :: [(Board, [Int])] -> Int -> [(Board, [Int])]
    loop boards counter
      | counter == n = boards
      | otherwise = loop (concatMap expand boards) (counter+1)

    expand :: (Board, [Int]) -> [(Board, [Int])]
    expand (board, candidates) =
      [(x : board, delete x candidates) | x <- candidates, safe x board]

    safe x board = and [ x /= c + n && x /= c - n  | (n,c) <- zip [1..] board]

-- import Control.Monad
-- import Data.List (delete)
-- queens n = map fst $ foldM oneMorequeens ([],[1..n]) [1..n]  where
--   oneMorequeens (y,d) _ = [(x:y, delete x d) | x <- d, safe x]  where
--     safe x = and [x /= c + n && x /= c - n | (n,c) <- zip [1..] y]

main = do
  start <- getCurrentTime
  print $ nqueens 12
  stop <- getCurrentTime
  print $ diffUTCTime stop start
