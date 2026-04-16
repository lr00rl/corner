# Corner

> A lightweight Haskell HTTP server built on **WAI / Warp**, featuring a hand-written router, `ReaderT`-based handlers, JSON support via **aeson**, pluggable middleware, **JWT/Basic Auth**, **OpenAPI 3** document generation, and **WebSocket** support via **wai-websockets**.

---

## 🚀 Quick Start

```bash
# Build
cabal build

# Run tests (18 examples)
cabal test

# Start server on default port 3000
cabal run corner

# Start server on custom port
cabal run corner -- 8080
```

## 📡 API Endpoints

### HTTP

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

### WebSocket

| Path | Description |
|------|-------------|
| `/ws/echo` | Echo server — sends back any text message you send |

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

# Basic Auth (admin / secret)
curl -u admin:secret http://localhost:3000/protected/basic
# => {"message":"This is protected","user":"admin"}

# Swagger / OpenAPI JSON
curl http://localhost:3000/swagger.json
# => { "openapi": "3.0.0", "info": { "title": "Corner API", ... } }

# WebSocket echo with websocat
websocat ws://localhost:3000/ws/echo
> hello
hello
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
│   ├── WebSocket.hs       # WebSocket routing & echo handler
│   ├── Router.hs          # Hand-written path + method router (405 aware)
│   ├── RouteBuilder.hs    # get/post/put/delete/scope/document/withMiddleware DSL
│   ├── Middleware.hs      # Logging & exception-catching middleware
│   └── Server.hs          # WAI Application & Warp runner
└── test/
    └── Spec.hs            # Hspec + hspec-wai + real-port WebSocket tests
```

---

## 🧠 Design Highlights

### 1. CornerT — ReaderT for Handlers

```haskell
type Handler = Context -> CornerT Response

newtype CornerT a = CornerT { runCornerT :: ReaderT Env IO a }
  deriving (Functor, Applicative, Monad, MonadIO, MonadReader Env)
```

### 2. Per-Route Middleware

Middleware can be attached to individual routes:

```haskell
withMiddleware
  (get "/protected/basic" handleProtected)
  (protectBasic basicVerify)
```

### 3. WebSocket Support

WebSocket routes live alongside HTTP routes but are handled by `websocketsOr`:

```haskell
startServer port
  [ ws "/ws/echo" echoHandler ]      -- WebSocket routes
  [ get "/" handleWelcome, ... ]     -- HTTP routes
```

Under the hood, `Corner.Server` wraps the HTTP Application with `wsApp`, so any non-upgrade request to a WebSocket path gracefully falls back to normal HTTP routing.

### 4. JWT Verification with jose

```haskell
jwtMiddleware = protectJwt (verifyHmacJwt "corner-secret")
```

### 5. OpenAPI 3 / Swagger

```haskell
documentRoute (get "/health" handleHealth)
  (mempty & summary ?~ "Health check")
```

`withSwagger` automatically appends `/swagger.json`.

---

## 📝 License

MIT
