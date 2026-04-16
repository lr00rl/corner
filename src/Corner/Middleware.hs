{-|
模块：Corner.Middleware

中间件系统：日志记录与异常捕获。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.Middleware
  ( logMiddleware
  , catchErrorMiddleware
  ) where

import Control.Exception (catch, SomeException)
import qualified Data.ByteString.Lazy.Char8 as BLC
import Data.Time (getCurrentTime, diffUTCTime)
import Network.HTTP.Types (status500)
import Network.Wai
  ( Application
  , Response
  , responseLBS
  , rawPathInfo
  , requestMethod
  )
import Network.Wai.Internal (Response(..))
import qualified Data.ByteString.Char8 as BC

-- | 日志中间件：记录方法、路径、状态码、处理耗时。
logMiddleware :: (String -> IO ()) -> Application -> Application
logMiddleware logger app req respond = do
  start <- getCurrentTime
  app req $ \response -> do
    end <- getCurrentTime
    let duration = diffUTCTime end start
        method   = BC.unpack (requestMethod req)
        path     = BC.unpack (rawPathInfo req)
        status   = getStatus response
    logger $ "[" ++ method ++ " " ++ path ++ "] " ++ show status ++ " in " ++ show duration
    respond response

-- | 从 Response 中提取状态码（仅用于日志）。
-- WAI 的 Response 有三种构造器，这里只做最小处理。
getStatus :: Response -> Int
getStatus res =
  case res of
    ResponseBuilder st _ _       -> fromEnum st
    ResponseStream st _ _        -> fromEnum st
    ResponseRaw _ resp           -> getStatus resp
    ResponseFile st _ _ _        -> fromEnum st

-- | 异常捕获中间件：捕获 Handler 抛出的任何异常，返回 500 JSON。
catchErrorMiddleware :: Application -> Application
catchErrorMiddleware app req respond =
  app req respond `catch` \e -> do
    let msg = show (e :: SomeException)
    respond $ responseLBS status500 [("Content-Type", "application/json")]
            $ "{\"error\":\"Internal Server Error\",\"detail\":" <> BLC.pack (show msg) <> "}"
