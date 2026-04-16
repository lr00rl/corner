{-|
模块：Corner.Server

将 Corner 的路由封装为 WAI Application，并通过 Warp 启动服务。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.Server
  ( app
  , startServer
  , defaultRoutes
  ) where

import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy.Char8 as BLC
import qualified Data.ByteString.Char8 as BC
import qualified Data.Text as T
import Network.HTTP.Types (Status, status200, status404)
import Network.Wai
  ( Application
  , Response
  , pathInfo
  , responseLBS
  , strictRequestBody
  )
import Network.Wai.Handler.Warp (run)
import Corner.Types (Handler, Route)
import Corner.Router (matchRoute, pathInfoString)

-- | 默认路由集：包含健康检查、问候、回显等示例端点。
defaultRoutes :: [Route]
defaultRoutes =
  [ ("/",          "GET",  handleWelcome)
  , ("/health",    "GET",  handleHealth)
  , ("/hello/:name", "GET", handleHello)
  , ("/echo",      "POST", handleEcho)
  ]

-- | 欢迎页。
handleWelcome :: Handler
handleWelcome _ =
  jsonResponse status200 "{\"message\":\"Welcome to Corner!\"}"

-- | 健康检查。
handleHealth :: Handler
handleHealth _ =
  jsonResponse status200 "{\"status\":\"ok\"}"

-- | 动态问候：从路由参数中提取 :name。
-- 注意：这里为了简化，不传递参数，而是通过再次解析 pathInfo 获取 name。
-- 生产代码中应将参数注入 Handler 上下文。
handleHello :: Handler
handleHello req =
  let segs = map T.unpack (pathInfo req)
      name = if length segs >= 2 then segs !! 1 else "stranger"
      body = BLC.pack $ "{\"message\":\"Hello, " ++ escapeJson name ++ "!\"}"
  in jsonResponse status200 body
  where
    escapeJson [] = []
    escapeJson ('"':xs) = '\\' : '"' : escapeJson xs
    escapeJson ('\\':xs) = '\\' : '\\' : escapeJson xs
    escapeJson (x:xs)   = x : escapeJson xs

-- | 回显 POST 请求体。
handleEcho :: Handler
handleEcho req = do
  body <- strictRequestBody req
  let quoted = BLC.pack $ show $ BC.unpack $ BLC.toStrict body
  jsonResponse status200 $ "{\"echo\":" <> quoted <> "}"

-- | 辅助函数：返回 JSON 格式的 Response。
jsonResponse :: Status -> ByteString -> IO Response
jsonResponse st body =
  return $ responseLBS st [("Content-Type", "application/json")] body

-- | 构建 WAI Application。
app :: [Route] -> Application
app routes req respond = do
  case matchRoute routes req of
    Just (handler, _params) -> handler req >>= respond
    Nothing ->
      respond $ responseLBS status404 [("Content-Type", "application/json")]
             $ "{\"error\":\"Not Found\",\"path\":" <> BLC.pack (show (pathInfoString req)) <> "}"

-- | 启动服务器在指定端口。
startServer :: Int -> [Route] -> IO ()
startServer port routes = do
  putStrLn $ "Corner server listening on http://localhost:" ++ show port
  run port (app routes)
