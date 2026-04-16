{-|
模块：Corner.RouteBuilder

路由 DSL：提供 get/post/put/delete 等便捷函数，以及 scope 路由分组。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.RouteBuilder
  ( get
  , post
  , put
  , delete
  , scope
  ) where

import Corner.Types (Route(..), Handler)

-- | 构造 GET 路由。
get :: String -> Handler -> Route
get path handler = Route path "GET" handler

-- | 构造 POST 路由。
post :: String -> Handler -> Route
post path handler = Route path "POST" handler

-- | 构造 PUT 路由。
put :: String -> Handler -> Route
put path handler = Route path "PUT" handler

-- | 构造 DELETE 路由。
delete :: String -> Handler -> Route
delete path handler = Route path "DELETE" handler

-- | 为子路由统一添加前缀。
scope :: String -> [Route] -> [Route]
scope prefix = map (\r -> r { routePattern = prefix ++ routePattern r })
