# Corner

> A lightweight Haskell HTTP server built on **WAI / Warp**, featuring a hand-written router, `ReaderT`-based handlers, JSON support via **aeson**, and pluggable middleware.

---

## 🚀 Quick Start

```bash
# Build
cabal build

# Run tests (10 examples)
cabal test

# Start server on default port 3000
cabal run corner

# Start server on custom port
cabal run corner -- 8080
```

## 📡 API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/` | Welcome message |
| GET | `/health` | Health check |
| GET | `/hello/:name` | Greeting with dynamic path parameter |
| POST | `/echo` | Echo a valid JSON request body |
| GET | `/api/v1/status` | Example of scoped route group |

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

# Scoped route
curl http://localhost:3000/api/v1/status
# => {"api":"v1"}

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
│   ├── Router.hs          # Hand-written path + method router (405 aware)
│   ├── RouteBuilder.hs    # get/post/put/delete/scope DSL
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

### 3. Route DSL & Scoping

```haskell
apiRoutes :: [Route]
apiRoutes =
  scope "/api/v1"
    [ get "/status"  handleStatus
    , post "/users" handleCreateUser
    ]
```

### 4. Middleware Stack

`startServer` automatically mounts:

- **Log Middleware** — prints method, path, status code, and duration.
- **Catch-Error Middleware** — catches unhandled exceptions and returns a safe `500` JSON response.

### 5. 405 Method Not Allowed

If a path matches but the HTTP method does not, the router returns `405` instead of `404`.

---

## 📝 License

MIT
