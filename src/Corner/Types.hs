{-|
模块：Corner.Types

定义 Corner HTTP server 的核心类型，包括 ReaderT 形式的 CornerT Monad 和请求上下文。
-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Corner.Types
  ( Env(..)
  , CornerT(..)
  , Context(..)
  , Handler
  , Route(..)
  , Middleware
  ) where

import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Reader (ReaderT, MonadReader)
import Data.OpenApi (Operation)
import Network.Wai (Application, Request, Response)

-- | 应用环境，可扩展配置、日志函数、连接池等。
data Env = Env
  { envLogger :: String -> IO ()
  }

-- | CornerT Monad：ReaderT Env IO。
newtype CornerT a = CornerT
  { runCornerT :: ReaderT Env IO a
  } deriving ( Functor
             , Applicative
             , Monad
             , MonadIO
             , MonadReader Env
             )

-- | 请求上下文，封装 WAI Request 和路由参数。
data Context = Context
  { ctxRequest :: Request
  , ctxParams  :: [(String, String)]
  , ctxUser    :: Maybe String
  }

-- | 处理函数类型：接收请求上下文，运行在 CornerT 中，返回 Response。
type Handler = Context -> CornerT Response

-- | 路由类型，支持附加中间件和 OpenAPI 文档。
data Route = Route
  { routePattern    :: String
  , routeMethod     :: String
  , routeHandler    :: Handler
  , routeMiddleware :: [Middleware]
  , routeDoc        :: Maybe Operation
  } deriving ()

-- | 中间件类型：WAI Application 的变换器。
type Middleware = Application -> Application
