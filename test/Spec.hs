{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import Test.Hspec.Wai
import Network.Wai (Application)
import Corner.Server (app, defaultRoutes)

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
    it "echoes the request body" $ do
      post "/echo" "hello" `shouldRespondWith` 200
        { matchBody = "{\"echo\":\"hello\"}" }

  describe "404" $ do
    it "returns not found for unknown paths" $ do
      get "/unknown" `shouldRespondWith` 404

testApp :: Application
testApp = app defaultRoutes
