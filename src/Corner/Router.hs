{-|
模块：Corner.Router

一个简单的手写 HTTP 路由器。

支持：
  - 精确路径匹配（如 /health）
  - 参数路径匹配（如 /hello/:name）
  - HTTP 方法过滤（GET、POST 等）
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.Router
  ( matchRoute
  , pathInfoString
  ) where

import qualified Data.ByteString.Char8 as BC
import qualified Data.Text as T
import Network.Wai (Request, pathInfo, requestMethod)
import Corner.Types (Handler, Route)

-- | 将 WAI 的 pathInfo ([Text]) 转换为以 / 分隔的字符串。
pathInfoString :: Request -> String
pathInfoString req =
  let segs = map T.unpack (pathInfo req)
  in if null segs then "/" else concatMap ('/' :) segs

-- | 将 HTTP 方法转换为字符串。
methodString :: Request -> String
methodString = BC.unpack . requestMethod

-- | 拆分路径为段落列表，忽略前导空段。
splitPath :: String -> [String]
splitPath = filter (not . null) . splitOn '/'
  where
    splitOn _ [] = [[]]
    splitOn c (x:xs)
      | x == c    = [] : rest
      | otherwise = (x : head rest) : tail rest
      where rest = splitOn c xs

-- | 匹配路径模板与实际路径，返回 Maybe 参数列表。
matchPath :: String -> String -> Maybe [(String, String)]
matchPath template actual =
  let tSegs = splitPath template
      aSegs = splitPath actual
  in if length tSegs /= length aSegs
       then Nothing
       else foldr combine (Just []) (zip tSegs aSegs)
  where
    combine (_, _) Nothing = Nothing
    combine (t, a) (Just acc)
      | t == a          = Just acc
      | isParam t       = Just ((drop 1 t, a) : acc)
      | otherwise       = Nothing
    isParam (':':_) = True
    isParam _       = False

-- | 在路由列表中查找匹配的处理函数。
matchRoute :: [Route] -> Request -> Maybe (Handler, [(String, String)])
matchRoute routes req =
  let actualPath = pathInfoString req
      actualMethod = methodString req
  in go routes actualMethod actualPath
  where
    go [] _ _ = Nothing
    go ((tmpl, mthd, hndlr):rest) meth path =
      case matchPath tmpl path of
        Just params | mthd == meth -> Just (hndlr, params)
        _                          -> go rest meth path
