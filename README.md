# Corner

> A lightweight Haskell HTTP server built on **WAI / Warp**, with a hand-written router.

---

## 🚀 Quick Start

```bash
# Build
cabal build

# Run tests
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
| GET | `/hello/:name` | Greeting with dynamic parameter |
| POST | `/echo` | Echo request body |

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

# Echo
curl -X POST -d 'hello world' http://localhost:3000/echo
# => {"echo":"hello world"}
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
│   ├── Types.hs           # Core type aliases
│   ├── Router.hs          # Hand-written path + method router
│   └── Server.hs          # WAI Application & Warp runner
└── test/
    └── Spec.hs            # Hspec + wai-extra tests
```

---

## 🧠 Design Goals

- **Minimal dependencies**: only `warp`, `wai`, `http-types`
- **Hand-written router**: no heavy web framework, easy to understand
- **Testable**: uses `hspec-wai` for in-memory HTTP testing

---

## 📚 Resources

- [WAI Documentation](https://hackage.haskell.org/package/wai)
- [Warp Documentation](https://hackage.haskell.org/package/warp)

---

## 📝 License

MIT
