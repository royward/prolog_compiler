-- https://albertnetymk.github.io/2018/02/16/queens/
-- ghc -package time --make nqueens.hs

import Data.Time

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

main = do
  start <- getCurrentTime
  print $ length (nqueens 14)
  stop <- getCurrentTime
  print $ diffUTCTime stop start
