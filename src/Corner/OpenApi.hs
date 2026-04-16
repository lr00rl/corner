{-|
模块：Corner.OpenApi

基于 openapi3 包，程序化构建 OpenAPI 3.0 文档。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.OpenApi
  ( buildOpenApi
  , swaggerJsonHandler
  , withSwagger
  ) where

import Data.HashMap.Strict.InsOrd (fromList)
import Data.OpenApi
import Corner.Json (json)
import qualified Corner.RouteBuilder as RB
import Corner.Types (Route(..), Handler)

-- | 从路由列表构建 OpenApi 对象。
buildOpenApi :: [Route] -> OpenApi
buildOpenApi routes =
  mempty
    { _openApiInfo = mempty
        { _infoTitle = "Corner API"
        , _infoVersion = "0.1.0"
        }
    , _openApiPaths = fromList (map toPathPair routes)
    }
  where
    toPathPair :: Route -> (FilePath, PathItem)
    toPathPair route =
      let op = routeDoc route
          pathItem = case routeMethod route of
            "GET"    -> mempty { _pathItemGet = op }
            "POST"   -> mempty { _pathItemPost = op }
            "PUT"    -> mempty { _pathItemPut = op }
            "DELETE" -> mempty { _pathItemDelete = op }
            _        -> mempty
      in (routePattern route, pathItem)

-- | Swagger JSON 端点 Handler。
swaggerJsonHandler :: [Route] -> Handler
swaggerJsonHandler routes _ctx = json (buildOpenApi routes)

-- | 为路由列表追加 /swagger.json 端点。
withSwagger :: [Route] -> [Route]
withSwagger routes = routes ++ [RB.get "/swagger.json" (swaggerJsonHandler routes)]
