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

import Control.Monad (join)
import Control.Monad.Reader (runReaderT)
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Char8 as BC
import Data.OpenApi (summary)
import Control.Lens ((?~), (&))
import qualified Data.Text as T
import qualified Data.Vault.Lazy as V
import Network.Wai
  ( Application
  , Response
  , requestMethod
  , vault
  )
import Network.Wai.Handler.Warp (run)
import Corner.Auth
  ( userKey
  , protectBasic
  , protectJwt
  , verifyHmacJwt
  , requireAuth
  )
import Corner.Context (pathParam)
import Corner.Json (json, parseBody, badRequest, notFound, methodNotAllowed)
import Corner.Middleware (logMiddleware, catchErrorMiddleware)
import Corner.Router (RouteMatch(..), matchRoute, pathInfoString)
import Corner.RouteBuilder (get, post, withMiddleware, documentRoute)
import Corner.Types
  ( Env(..)
  , Context(..)
  , CornerT(..)
  , Route
  )
import Corner.WebSocket (WebSocketRoute, wsApp)

-- | 默认路由集，附带简单的 OpenAPI 文档。
defaultRoutes :: [Route]
defaultRoutes =
  [ documentRoute (get "/" handleWelcome)
      (mempty & summary ?~ "Welcome message")
  , documentRoute (get "/health" handleHealth)
      (mempty & summary ?~ "Health check")
  , documentRoute (get "/hello/:name" handleHello)
      (mempty & summary ?~ "Greeting with path parameter")
  , documentRoute (post "/echo" handleEcho)
      (mempty & summary ?~ "Echo JSON body")
  , withMiddleware
      (documentRoute (get "/protected/basic" handleProtected)
        (mempty & summary ?~ "Basic Auth protected resource"))
      (protectBasic basicVerify)
  , withMiddleware
      (documentRoute (get "/protected/jwt" handleProtected)
        (mempty & summary ?~ "JWT protected resource"))
      (protectJwt (verifyHmacJwt "corner-secret"))
  ]
  where
    basicVerify u p = return (u == "admin" && p == "secret")

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
  let name = maybe "stranger" id (pathParam ctx "name")
  in json (Aeson.object ["message" Aeson..= T.pack ("Hello, " ++ name ++ "!")])

-- | 回显 POST 请求体。
handleEcho :: Context -> CornerT Response
handleEcho ctx = do
  result <- parseBody ctx
  case result of
    Left err  -> badRequest err
    Right val -> json (Aeson.object ["echo" Aeson..= (val :: Aeson.Value)])

-- | 受保护资源示例。
handleProtected :: Context -> CornerT Response
handleProtected = requireAuth $ \ctx ->
  json (Aeson.object
    [ "message" Aeson..= ("This is protected" :: String)
    , "user"    Aeson..= maybe "unknown" id (ctxUser ctx)
    ])

-- | 构建 WAI Application。
app :: Env -> [Route] -> Application
app env routes req respond = do
  case matchRoute routes req of
    Matched handler params middlewares -> do
      let handlerApp req' respond' = do
            let mUser = V.lookup userKey (vault req')
                ctx   = Context req' params (join mUser)
            resp <- runReaderT (runCornerT (handler ctx)) env
            respond' resp
          wrappedApp = foldr ($) handlerApp middlewares
      wrappedApp req respond
    MethodNotAllowed -> do
      resp <- runReaderT (runCornerT (methodNotAllowed (BC.unpack (requestMethod req)) (pathInfoString req))) env
      respond resp
    NoMatch -> do
      resp <- runReaderT (runCornerT (notFound (pathInfoString req))) env
      respond resp

-- | 启动服务器在指定端口。
startServer :: Int -> [WebSocketRoute] -> [Route] -> IO ()
startServer port wsRoutes routes = do
  let env = Env { envLogger = putStrLn }
      httpApp     = app env routes
      wsApp'      = wsApp wsRoutes httpApp
      application = catchErrorMiddleware (logMiddleware (envLogger env) wsApp')
  putStrLn $ "Corner server listening on http://localhost:" ++ show port
  run port application
