module Main where

import System.Environment (getArgs)
import Corner.Server (startServer, defaultRoutes)

main :: IO ()
main = do
  args <- getArgs
  let port = case args of
               (p:_) -> read p
               _     -> 3000
  startServer port defaultRoutes
