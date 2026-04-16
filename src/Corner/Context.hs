{-|
模块：Corner.Context

提供从请求上下文中提取路径参数、Query String 的辅助函数。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.Context
  ( pathParam
  , queryParam
  , queryParams
  , rawBody
  ) where

import qualified Data.ByteString.Lazy as BSL
import qualified Data.CaseInsensitive as CI
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8)
import Network.Wai (queryString, strictRequestBody)
import Control.Monad.IO.Class (liftIO)
import Corner.Types (Context(..), CornerT(..))

-- | 从路由参数中获取单个值。
pathParam :: Context -> String -> Maybe String
pathParam ctx key = lookup key (ctxParams ctx)

-- | 从 Query String 中获取单个值。
queryParam :: Context -> T.Text -> Maybe T.Text
queryParam ctx key =
  let qs = queryString (ctxRequest ctx)
      pairs = [ (CI.mk (decodeUtf8 k), decodeUtf8 v) | (k, Just v) <- qs ]
  in lookup (CI.mk key) pairs

-- | 获取完整的 Query String 列表。
queryParams :: Context -> [(T.Text, Maybe T.Text)]
queryParams ctx =
  let qs = queryString (ctxRequest ctx)
  in map (\(k, mv) -> (decodeUtf8 k, fmap decodeUtf8 mv)) qs

-- | 读取请求体的原始字节串。
rawBody :: Context -> CornerT BSL.ByteString
rawBody ctx = liftIO $ strictRequestBody (ctxRequest ctx)
