{-|
模块：Corner.Json

基于 aeson 的 JSON 响应辅助和请求体解析。
-}
{-# LANGUAGE OverloadedStrings #-}

module Corner.Json
  ( json
  , jsonStatus
  , parseBody
  , badRequest
  , notFound
  , methodNotAllowed
  , internalError
  ) where

import qualified Data.Aeson as Aeson

import Network.HTTP.Types
  ( Status
  , status200
  , status400
  , status404
  , status405
  , status500
  )
import Network.Wai (Response, responseLBS, strictRequestBody)
import Control.Monad.IO.Class (liftIO)
import Corner.Types (Context(..), CornerT(..))
import qualified Data.Text as T

-- | 返回 200 JSON 响应。
json :: Aeson.ToJSON a => a -> CornerT Response
json = jsonStatus status200

-- | 返回指定状态码的 JSON 响应。
jsonStatus :: Aeson.ToJSON a => Status -> a -> CornerT Response
jsonStatus st val =
  return $ responseLBS st [("Content-Type", "application/json")] (Aeson.encode val)

-- | 将请求体解析为 JSON。
parseBody :: Aeson.FromJSON a => Context -> CornerT (Either String a)
parseBody ctx = liftIO $ do
  body <- strictRequestBody (ctxRequest ctx)
  return $ Aeson.eitherDecode body

-- | 400 Bad Request。
badRequest :: String -> CornerT Response
badRequest msg = jsonStatus status400 (Aeson.object ["error" Aeson..= T.pack msg])

-- | 404 Not Found。
notFound :: String -> CornerT Response
notFound path = jsonStatus status404 (Aeson.object ["error" Aeson..= ("Not Found" :: T.Text), "path" Aeson..= T.pack path])

-- | 405 Method Not Allowed。
methodNotAllowed :: String -> String -> CornerT Response
methodNotAllowed meth path =
  jsonStatus status405
    (Aeson.object
      [ "error" Aeson..= ("Method Not Allowed" :: T.Text)
      , "method" Aeson..= T.pack meth
      , "path" Aeson..= T.pack path
      ])

-- | 500 Internal Server Error。
internalError :: String -> CornerT Response
internalError msg = jsonStatus status500 (Aeson.object ["error" Aeson..= T.pack msg])
