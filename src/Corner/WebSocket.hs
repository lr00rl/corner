{-|
模块：Corner.WebSocket

为 Corner 提供 WebSocket 支持，基于 wai-websockets。

设计思路：
  - WebSocket 路由与普通 HTTP 路由分离
  - 通过 wsApp 使用 websocketsOr 包裹 HTTP Application
  - 匹配失败时拒绝 pending connection
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.WebSocket
  ( WsHandler
  , WebSocketRoute(..)
  , ws
  , wsApp
  , echoHandler
  ) where

import qualified Data.ByteString.Char8 as BC
import qualified Data.Text as T
import Network.Wai (Application)
import Network.Wai.Handler.WebSockets (websocketsOr)
import Network.WebSockets
  ( PendingConnection
  , Connection
  , ConnectionOptions
  , defaultConnectionOptions
  , pendingRequest
  , requestPath
  , acceptRequest
  , rejectRequest
  , receiveData
  , sendTextData
  , withPingThread
  )

-- | WebSocket 处理函数类型。
type WsHandler = PendingConnection -> IO ()

-- | WebSocket 路由类型。
data WebSocketRoute = WebSocketRoute
  { wsPattern :: String
  , wsHandler :: WsHandler
  }

-- | 构造 WebSocket 路由。
ws :: String -> WsHandler -> WebSocketRoute
ws = WebSocketRoute

-- | 将 WebSocket 路由列表转换为 WAI Application 包装器。
wsApp :: [WebSocketRoute] -> Application -> Application
wsApp routes = websocketsOr defaultConnectionOptions serverApp
  where
    serverApp :: PendingConnection -> IO ()
    serverApp pending = do
      let path = BC.unpack (requestPath (pendingRequest pending))
      case lookup path (map (\r -> (wsPattern r, wsHandler r)) routes) of
        Just handler -> handler pending
        Nothing      -> rejectRequest pending "No WebSocket handler for this path"

-- | 示例 Echo Handler：接收文本消息后原样返回。
echoHandler :: WsHandler
echoHandler pending = do
  conn <- acceptRequest pending
  withPingThread conn 30 (return ()) $ do
    loop conn
  where
    loop conn = do
      msg <- receiveData conn
      sendTextData conn (msg :: T.Text)
      loop conn
