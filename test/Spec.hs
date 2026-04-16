{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import Test.Hspec.Wai
import Network.Wai (Application)
import qualified Data.Aeson as Aeson
import Data.Maybe (fromMaybe)
import Corner.Server (app, defaultRoutes)
import Corner.Context (queryParam)
import Corner.Json (json)
import Corner.Middleware (catchErrorMiddleware)
import qualified Corner.RouteBuilder as RB
import Corner.Types (Env(..), Route)

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

  describe "404" $ do
    it "returns not found for unknown paths" $ do
      get "/unknown" `shouldRespondWith` 404

testRoutes :: [Route]
testRoutes = defaultRoutes ++
  [ RB.get "/search" $ \ctx ->
      let q = fromMaybe "all" (queryParam ctx "q")
      in json (Aeson.object ["query" Aeson..= q])
  , RB.get "/boom" $ \_ctx ->
      error "intentional boom"
  ]

testApp :: Application
testApp = catchErrorMiddleware (app (Env { envLogger = \_ -> return () }) testRoutes)
