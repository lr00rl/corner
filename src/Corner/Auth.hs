{-|
模块：Corner.Auth

认证中间件：Basic Auth 与 JWT Bearer Token。

- Basic Auth：解析 `Authorization: Basic base64(user:pass)`
- JWT：验证 `Authorization: Bearer <token>` 的签名与过期时间（使用 jose 库）

认证成功后，用户信息会通过 WAI Vault 传递给下游 Handler。
-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Corner.Auth
  ( userKey
  , protectBasic
  , protectJwt
  , verifyHmacJwt
  , requireAuth
  ) where

import Control.Monad.Except (runExceptT, ExceptT)
import qualified Data.ByteString.Base64 as Base64
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy.Char8 as BLC
import qualified Data.Text as T
import qualified Data.Vault.Lazy as V
import qualified Data.Map as Map
import Data.Aeson (Value(..))
import Control.Lens ((^.))
import Network.HTTP.Types (status401, status403)
import Network.Wai
  ( Application
  , responseLBS
  , requestHeaders
  , vault
  )
import System.IO.Unsafe (unsafePerformIO)
import Corner.Types (Context(..), Handler, Middleware)
import Corner.Json (jsonStatus)

import Crypto.JOSE.JWK (fromOctets)
import Crypto.JWT
  ( decodeCompact
  , verifyClaims
  , defaultJWTValidationSettings
  , unregisteredClaims
  , JWTError
  )


-- | Vault Key 用于在 Request 中传递认证用户信息。
userKey :: V.Key (Maybe String)
userKey = unsafePerformIO V.newKey
{-# NOINLINE userKey #-}

-- | 401 未认证响应。
unauthorized :: Application
unauthorized _req respond =
  respond $ responseLBS status401
    [("Content-Type", "application/json"), ("WWW-Authenticate", "Bearer realm=\"corner\"")]
    "{\"error\":\"Unauthorized\"}"

-- | Basic Auth 保护中间件。
protectBasic :: (String -> String -> IO Bool) -> Middleware
protectBasic verify app req respond =
  case lookup "Authorization" (requestHeaders req) of
    Just auth | "Basic " `BC.isPrefixOf` auth ->
      case Base64.decode (BC.drop 6 auth) of
        Right decoded ->
          let (user, passWithColon) = break (== ':') (BC.unpack decoded)
          in if null passWithColon
               then unauthorized req respond
               else do
                 ok <- verify user (tail passWithColon)
                 if ok
                   then app (insertUser req (Just user)) respond
                   else unauthorized req respond
        Left _ -> unauthorized req respond
    _ -> unauthorized req respond
  where
    insertUser r mu = r { vault = V.insert userKey mu (vault r) }

-- | JWT Bearer Token 保护中间件。
protectJwt :: (BC.ByteString -> IO (Maybe String)) -> Middleware
protectJwt verify app req respond =
  case lookup "Authorization" (requestHeaders req) of
    Just auth | "Bearer " `BC.isPrefixOf` auth ->
      let token = BC.drop 7 auth
      in verify token >>= \case
           Just user -> app (insertUser req (Just user)) respond
           Nothing   -> unauthorized req respond
    _ -> unauthorized req respond
  where
    insertUser r mu = r { vault = V.insert userKey mu (vault r) }

-- | 使用 HMAC SHA-256 验证 JWT。
verifyHmacJwt :: String -> BC.ByteString -> IO (Maybe String)
verifyHmacJwt secret token = do
  result <- runExceptT (go :: ExceptT JWTError IO (Maybe String))
  return $ either (const Nothing) id result
  where
    go = do
      jwt <- decodeCompact (BLC.fromStrict token)
      let jwk = fromOctets (BC.pack secret)
      claims <- verifyClaims (defaultJWTValidationSettings (const True)) jwk jwt
      return $ case Map.lookup "sub" (claims ^. unregisteredClaims) of
                 Just (String s) -> Just (T.unpack s)
                 _               -> Nothing

-- | Handler 层强制要求已认证。
requireAuth :: Handler -> Handler
requireAuth handler ctx =
  case ctxUser ctx of
    Just _  -> handler ctx
    Nothing -> jsonStatus status403 (T.pack "Forbidden")
