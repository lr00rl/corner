{-|
模块：Corner.Types

定义 Corner HTTP server 的核心类型。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.Types
  ( Handler
  , Route
  ) where

import Network.Wai (Request, Response)

-- | 处理函数类型：接收 WAI Request，返回 IO Response。
type Handler = Request -> IO Response

-- | 路由类型：路径模板 + HTTP 方法 + 处理函数。
type Route = (String, String, Handler)
