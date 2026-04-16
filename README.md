# Corner

> A lightweight Haskell HTTP server built on **WAI / Warp**, featuring a hand-written router, `ReaderT`-based handlers, JSON support via **aeson**, pluggable middleware, **JWT/Basic Auth**, and **OpenAPI 3** document generation.

---

## 🚀 Quick Start

```bash
# Build
cabal build

# Run tests (17 examples)
cabal test

# Start server on default port 3000
cabal run corner

# Start server on custom port
cabal run corner -- 8080
```

## 📡 API Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/` | Welcome message | None |
| GET | `/health` | Health check | None |
| GET | `/hello/:name` | Greeting with dynamic path parameter | None |
| POST | `/echo` | Echo a valid JSON request body | None |
| GET | `/protected/basic` | Basic Auth protected resource | Basic Auth |
| GET | `/protected/jwt` | JWT protected resource | Bearer JWT |
| GET | `/api/v1/status` | Example of scoped route group | None |
| GET | `/swagger.json` | OpenAPI 3 JSON specification | None |

### Example Requests

```bash
# Welcome
curl http://localhost:3000/
# => {"message":"Welcome to Corner!"}

# Health
curl http://localhost:3000/health
# => {"status":"ok"}

# Dynamic greeting
curl http://localhost:3000/hello/Haskell
# => {"message":"Hello, Haskell!"}

# Echo JSON
curl -X POST -d '{"msg":"hello"}' http://localhost:3000/echo
# => {"echo":{"msg":"hello"}}

# Invalid JSON returns 400
curl -X POST -d 'not-json' http://localhost:3000/echo
# => {"error":"..."}

# Basic Auth (admin / secret)
curl -u admin:secret http://localhost:3000/protected/basic
# => {"message":"This is protected","user":"admin"}

# JWT Auth — you need a valid HMAC-SHA256 token with sub claim
# Example using a mock verifier in tests; in production use verifyHmacJwt

# Scoped route
curl http://localhost:3000/api/v1/status
# => {"api":"v1"}

# Swagger / OpenAPI JSON
curl http://localhost:3000/swagger.json
# => { "openapi": "3.0.0", "info": { "title": "Corner API", ... } }

# Wrong method returns 405
curl -X POST http://localhost:3000/health
# => {"error":"Method Not Allowed","method":"POST","path":"/health"}
```

---

## 📁 Project Structure

```
.
├── corner.cabal           # Cabal build configuration
├── README.md              # You are here
├── app/
│   └── Main.hs            # Server entry point
├── src/Corner/
│   ├── Types.hs           # Env, CornerT (ReaderT), Context, Route
│   ├── Context.hs         # Path param / query param helpers
│   ├── Json.hs            # json response helpers & body parsing
│   ├── Auth.hs            # Basic Auth & JWT middleware (jose)
│   ├── OpenApi.hs         # OpenAPI 3 document builder (openapi3)
│   ├── Router.hs          # Hand-written path + method router (405 aware)
│   ├── RouteBuilder.hs    # get/post/put/delete/scope/document/withMiddleware DSL
│   ├── Middleware.hs      # Logging & exception-catching middleware
│   └── Server.hs          # WAI Application & Warp runner
└── test/
    └── Spec.hs            # Hspec + hspec-wai tests
```

---

## 🧠 Design Highlights

### 1. CornerT — ReaderT for Handlers

Instead of plain `Request -> IO Response`, handlers run in `CornerT`:

```haskell
type Handler = Context -> CornerT Response

newtype CornerT a = CornerT { runCornerT :: ReaderT Env IO a }
  deriving (Functor, Applicative, Monad, MonadIO, MonadReader Env)
```

This lets handlers access shared environment (logger, config, DB pool) without threading arguments manually.

### 2. JSON via Aeson

```haskell
handleEcho :: Handler
handleEcho ctx = do
  result <- parseBody ctx
  case result of
    Left err  -> badRequest err
    Right val -> json (Aeson.object ["echo" Aeson..= (val :: Aeson.Value)])
```

No more hand-written JSON strings.

### 3. Per-Route Middleware

Middleware can be attached to individual routes:

```haskell
withMiddleware
  (get "/protected/basic" handleProtected)
  (protectBasic basicVerify)
```

Available middleware:
- `protectBasic :: (String -> String -> IO Bool) -> Middleware`
- `protectJwt :: (ByteString -> IO (Maybe String)) -> Middleware`
- `logMiddleware :: (String -> IO ()) -> Middleware`
- `catchErrorMiddleware :: Middleware`

Authentication results are passed through WAI Vault and available in `ctxUser :: Maybe String`.

### 4. JWT Verification with jose

`verifyHmacJwt` uses the industrial-strength `jose` library to verify HMAC-SHA256 tokens and extract the `sub` claim:

```haskell
jwtMiddleware = protectJwt (verifyHmacJwt "corner-secret")
```

### 5. OpenAPI 3 / Swagger

Routes can carry `Operation` metadata:

```haskell
documentRoute (get "/health" handleHealth)
  (mempty & summary ?~ "Health check")
```

`withSwagger` appends a `/swagger.json` endpoint that aggregates all route docs into a valid OpenAPI 3 specification.

### 6. 405 Method Not Allowed

If a path matches but the HTTP method does not, the router returns `405` instead of `404`.

---

## 📝 License

MIT
