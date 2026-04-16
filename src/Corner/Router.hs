{-|
模块：Corner.Router

一个手写 HTTP 路由器，支持精确路径、参数路径、405 方法不匹配检测。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.Router
  ( RouteMatch(..)
  , matchRoute
  , pathInfoString
  ) where

import qualified Data.ByteString.Char8 as BC
import qualified Data.Text as T
import Network.Wai (Request, pathInfo, requestMethod)
import Corner.Types (Handler, Route(..))

-- | 路由匹配结果。
data RouteMatch
  = Matched Handler [(String, String)]
  | MethodNotAllowed
  | NoMatch

instance Show RouteMatch where
  show (Matched _ params) = "Matched <handler> " ++ show params
  show MethodNotAllowed   = "MethodNotAllowed"
  show NoMatch            = "NoMatch"

-- | 将 WAI 的 pathInfo 转换为以 / 分隔的字符串。
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

-- | 在路由列表中查找匹配。
matchRoute :: [Route] -> Request -> RouteMatch
matchRoute routes req =
  let actualPath   = pathInfoString req
      actualMethod = methodString req
  in go routes actualMethod actualPath NoMatch
  where
    go [] _ _ best = best
    go (route:rest) meth path best =
      case matchPath (routePattern route) path of
        Just params
          | routeMethod route == meth -> Matched (routeHandler route) params
          | otherwise                 -> go rest meth path (prefer best MethodNotAllowed)
        Nothing                       -> go rest meth path best

    prefer NoMatch x = x
    prefer x _       = x
