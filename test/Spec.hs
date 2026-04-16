{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import Test.Hspec.Wai
import Network.Wai (Application)
import Network.HTTP.Types (methodGet)
import qualified Data.Aeson as Aeson
import Data.Maybe (fromMaybe)
import qualified Data.ByteString.Base64 as Base64
import Corner.Server (app, defaultRoutes)
import Corner.Context (queryParam)
import Corner.Json (json)
import Corner.Middleware (catchErrorMiddleware)
import Corner.OpenApi (withSwagger)
import Corner.Auth (protectJwt, requireAuth)
import qualified Corner.RouteBuilder as RB
import Corner.Types (Env(..), Context(..), Route, Handler)

main :: IO ()
main = hspec spec

spec :: Spec
spec = with (return testApp) $ do
  describe "GET /" $ do
    it "returns welcome message" $ do
      get "/" `shouldRespondWith` 200
        { matchBody = "{\"message\":\"Welcome to Corner!\"}"
        , matchHeaders = ["Content-Type" <:> "application/json"]
        }

  describe "GET /health" $ do
    it "returns status ok" $ do
      get "/health" `shouldRespondWith` 200
        { matchBody = "{\"status\":\"ok\"}" }

  describe "GET /hello/:name" $ do
    it "greets the given name" $ do
      get "/hello/Alice" `shouldRespondWith` 200
        { matchBody = "{\"message\":\"Hello, Alice!\"}" }

  describe "POST /echo" $ do
    it "echoes valid JSON body" $ do
      let payload = Aeson.encode (Aeson.object ["msg" Aeson..= ("hello" :: String)])
      post "/echo" payload `shouldRespondWith` 200
        { matchBody = "{\"echo\":{\"msg\":\"hello\"}}" }

    it "returns 400 for invalid JSON" $ do
      post "/echo" "not-json" `shouldRespondWith` 400

  describe "405 Method Not Allowed" $ do
    it "returns 405 for matched path but wrong method" $ do
      post "/health" "" `shouldRespondWith` 405

  describe "Query String" $ do
    it "reads query parameter" $ do
      get "/search?q=haskell" `shouldRespondWith` 200
        { matchBody = "{\"query\":\"haskell\"}" }

    it "uses default when query parameter is missing" $ do
      get "/search" `shouldRespondWith` 200
        { matchBody = "{\"query\":\"all\"}" }

  describe "Exception handling" $ do
    it "returns 500 when handler throws" $ do
      get "/boom" `shouldRespondWith` 500

  describe "Basic Auth" $ do
    it "returns 200 with valid credentials" $ do
      let creds = Base64.encode "admin:secret"
      request methodGet "/protected/basic" [("Authorization", "Basic " <> creds)] ""
        `shouldRespondWith` 200

    it "returns 401 with invalid credentials" $ do
      let creds = Base64.encode "admin:wrong"
      request methodGet "/protected/basic" [("Authorization", "Basic " <> creds)] ""
        `shouldRespondWith` 401

    it "returns 401 without Authorization header" $ do
      get "/protected/basic" `shouldRespondWith` 401

  describe "JWT Auth" $ do
    it "returns 200 with valid token" $ do
      request methodGet "/protected/jwt" [("Authorization", "Bearer valid")] ""
        `shouldRespondWith` 200

    it "returns 401 with invalid token" $ do
      request methodGet "/protected/jwt-bad" [("Authorization", "Bearer invalid")] ""
        `shouldRespondWith` 401

    it "returns 401 without Authorization header" $ do
      get "/protected/jwt" `shouldRespondWith` 401

  describe "Swagger" $ do
    it "returns OpenAPI JSON" $ do
      get "/swagger.json" `shouldRespondWith` 200
        { matchHeaders = ["Content-Type" <:> "application/json"] }

  describe "404" $ do
    it "returns not found for unknown paths" $ do
      get "/unknown" `shouldRespondWith` 404

handleProtected :: Handler
handleProtected = requireAuth $ \ctx ->
  json (Aeson.object ["user" Aeson..= maybe "unknown" id (ctxUser ctx)])

testRoutes :: [Route]
testRoutes =
  [ RB.withMiddleware (RB.get "/protected/jwt" handleProtected)
      (protectJwt (const (return (Just "testuser"))))
  ]
  ++ defaultRoutes ++
  [ RB.get "/search" $ \ctx ->
      let q = fromMaybe "all" (queryParam ctx "q")
      in json (Aeson.object ["query" Aeson..= q])
  , RB.get "/boom" $ \_ctx ->
      error "intentional boom"
  , RB.withMiddleware (RB.get "/protected/jwt-bad" handleProtected)
      (protectJwt (const (return Nothing)))
  ]

testApp :: Application
testApp = catchErrorMiddleware (app (Env { envLogger = \_ -> return () }) (withSwagger testRoutes))
