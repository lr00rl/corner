{-|
模块：Corner.Server

将 Corner 的路由封装为 WAI Application，并通过 Warp 启动服务。
默认挂载日志与异常捕获中间件。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.Server
  ( app
  , startServer
  , defaultRoutes
  ) where

import Control.Monad.Reader (runReaderT)

import Network.Wai
  ( Application
  , Response
  , requestMethod
  )
import Network.Wai.Handler.Warp (run)
import Corner.Context (pathParam)
import Corner.Json (json, parseBody, badRequest, notFound, methodNotAllowed)
import Corner.Middleware (logMiddleware, catchErrorMiddleware)
import Corner.Router (RouteMatch(..), matchRoute, pathInfoString)
import Corner.RouteBuilder (get, post)
import Corner.Types
  ( Env(..)
  , Context(..)
  , CornerT(..)
  , Route
  )
import qualified Data.Aeson as Aeson
import qualified Data.Text as T

-- | 默认路由集。
defaultRoutes :: [Route]
defaultRoutes =
  [ get "/"           handleWelcome
  , get "/health"     handleHealth
  , get "/hello/:name" handleHello
  , post "/echo"      handleEcho
  ]

-- | 欢迎页。
handleWelcome :: Context -> CornerT Response
handleWelcome _ =
  json (Aeson.object ["message" Aeson..= ("Welcome to Corner!" :: T.Text)])

-- | 健康检查。
handleHealth :: Context -> CornerT Response
handleHealth _ =
  json (Aeson.object ["status" Aeson..= ("ok" :: T.Text)])

-- | 动态问候：从路由参数中提取 :name。
handleHello :: Context -> CornerT Response
handleHello ctx =
  let name = maybe "stranger" id (Corner.Context.pathParam ctx "name")
  in json (Aeson.object ["message" Aeson..= T.pack ("Hello, " ++ name ++ "!")])

-- | 回显 POST 请求体。
handleEcho :: Context -> CornerT Response
handleEcho ctx = do
  result <- parseBody ctx
  case result of
    Left err -> badRequest err
    Right val -> json (Aeson.object ["echo" Aeson..= (val :: Aeson.Value)])

-- | 构建 WAI Application。
app :: Env -> [Route] -> Application
app env routes req respond = do
  case matchRoute routes req of
    Matched handler params -> do
      let ctx = Context req params
      resp <- runReaderT (runCornerT (handler ctx)) env
      respond resp
    MethodNotAllowed -> do
      resp <- runReaderT (runCornerT (methodNotAllowed (show (Network.Wai.requestMethod req)) (pathInfoString req))) env
      respond resp
    NoMatch -> do
      resp <- runReaderT (runCornerT (notFound (pathInfoString req))) env
      respond resp

-- | 启动服务器在指定端口。
startServer :: Int -> [Route] -> IO ()
startServer port routes = do
  let env = Env { envLogger = putStrLn }
      application = catchErrorMiddleware (logMiddleware (envLogger env) (app env routes))
  putStrLn $ "Corner server listening on http://localhost:" ++ show port
  run port application
