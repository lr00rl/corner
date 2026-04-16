{-# LANGUAGE OverloadedStrings #-}

module Main where

import System.Environment (getArgs)
import qualified Data.Aeson as Aeson
import Corner.Json (json)
import Corner.OpenApi (withSwagger)
import Corner.RouteBuilder (get, scope)
import Corner.Server (startServer, defaultRoutes)
import Corner.WebSocket (ws, echoHandler, WebSocketRoute)
import Corner.Types (Route)

-- | 示例：在默认路由之上添加自定义路由分组。
allRoutes :: [Route]
allRoutes = defaultRoutes ++ apiRoutes

-- | WebSocket 路由示例。
wsRoutes :: [WebSocketRoute]
wsRoutes =
  [ ws "/ws/echo" echoHandler
  ]

-- | API v1 路由组。
apiRoutes :: [Route]
apiRoutes =
  scope "/api/v1"
    [ get "/status" $ \_ctx ->
        json (Aeson.object ["api" Aeson..= ("v1" :: String)])
    ]

main :: IO ()
main = do
  args <- getArgs
  let port = case args of
               (p:_) -> read p
               _     -> 3000
  startServer port wsRoutes (withSwagger allRoutes)
