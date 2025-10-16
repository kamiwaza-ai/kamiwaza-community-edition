# Changelog

Notable changes to Kamiwaza Community Edition. For full documentation, see the docs site: https://docs.kamiwaza.ai

## 0.5.1

### New Features

- **Enterprise Logging**: Advanced observability with OpenTelemetry infrastructure
- **Unified Logging**: New logs viewer with filtering and container log management
- **AI Framework**: Comprehensive coding assistance tools and knowledge base
- **App Garden**: Shinobi bench benchmarking capabilities
- **Enhanced Monitoring**: Better health checks and system visibility
- **Windows Installer**: Featuring a WSL2-based Windows MSI installer (supports modern RTXs & Intel Arc Series GPU)

### Improvements

- WSL support for cross-platform GPU detection
- Improved system stability and performance
- Better error handling and user feedback
- Enhanced cross-platform compatibility
- Streamlined dependency management

### Bug Fixes

- Fixed Docker installation issues
- Resolved Ray startup failures
- Fixed system stability problems
- Corrected various compatibility issues
- Improved error reporting

### Documentation

- Enhanced troubleshooting guides
- Better user documentation
- Improved setup instructions
- Clearer error messages


## 0.5.0

### Highlights
- **App Garden (compose-driven apps) + Tool Shed (curated tools)**: Launch apps and developer tools from curated templates with a new server module (`kamiwaza/serving/garden/*`) and default templates under `static/garden/default/*`. Frontend includes App Garden and Tool Shed UIs (browse, preview, deploy).
- **Debian/Ubuntu .deb installer (Linux)**: One-command install with automated dependency management and systemd integration; brings a `kamiwaza` CLI for managing services.
- **New React frontend**: Modern UI for auth, models, cluster, vector DBs, and App Garden. Comes with Jest + RTL tests and a streamlined dev setup.
- **Serving engines**: Added **MLX (Apple Silicon)** engine; major  **VLLM** and **Llama.cpp** engine improvements, better VRAM estimation, and container log capture.
- **Traefik integration**: More reliable automatic route management with extensive unit/integration/E2E tests.

### Added
- **Novice Mode + Model Guide**: Guided flows and docs to help first-time users deploy and test models quickly.
- **Startup supervisor**: `startup/kamiwazad.sh` (`kamiwaza <command>` on Linux deb install and WSL) manages all core services with a single command.
- **Container logging**: New APIs and utilities to view model container logs from the UI.

### Changed
- **Unified Python package layout (breaking)**: Everything now lives under `kamiwaza/*` (e.g., `services.*` → `kamiwaza.services.*`, `serving.*` → `kamiwaza.serving.*`, `util.*` → `kamiwaza.util.*`).
- **Frontend**: New `frontend/` app with clearer structure, consistent Webpack/Jest config, and improved routing/auth.

### Fixed/Improved
- **Stability**: Ray startup hardening, resilient streaming responses, port availability checks.
- **Model workflows**: More reliable downloads, cancellation, deployment status, and log pattern alerts.
- **Security**: Improved defaults (e.g., non-root containers where applicable) and safer UI rendering.

### Removed
- **Legacy duplicates and sample datasets**: Old `serving/*` and `services/*` duplicates removed; large sample datasets pruned to keep the repo lean.

### Breaking changes
- **Import paths**: Update imports to the new layout under `kamiwaza/*`.
- If you maintain external scripts/plugins, review renamed modules in `kamiwaza.serving.*` and `kamiwaza.services.*`.

### Upgrade notes
- **Rebuild and restart**: Rebuild images and run `startup/kamiwazad.sh start`.
- **Frontend**: Use the new `frontend/` package (`npm install`, `npm run dev`).
- **Traefik**: Validate routes with the included tests; new dynamic config is in deployment assets.
- If you persisted custom integrations, search for old imports and move to `kamiwaza/*`.

### Documentation
- Expanded docs at https://docs.kamiwaza.ai

## 0.3.3

- Fixes to the installer, update to `llamacpp` version for OSX
- Fixes to installer, `hostname` detection, update to `vLLM` version for Linux

## 0.3.2

- Authentication merged into community edition with JWT enforcement on all endpoints
  - Default login: `admin` / `kamiwaza`
- SSL is now required on all endpoints (self‑signed certificates are supported)
- JupyterLab now uses Kamiwaza authentication instead of lab tokens
- Improved SSL configuration and rotation handling for model endpoints
- Introduced `kamiwazad` for one‑command startup and systemd deployments
- Updated to vLLM 0.6.3.post1 and latest llama.cpp on OSX
- Improved model config autodetection during downloads
- vLLM model configurations now support all known parameters
- Enhanced Ray service management
- Better performance for large‑batch embeddings in pipelines
- Aligned recursive behavior between file and object catalog ingestion
- New lightweight client SDK available at github.com/kamiwaza-ai/kamiwaza-sdk
- Integrated new chatbot UI (thanks Vercel!)
- Many fixes and improvements

## 0.3.1

- Enhanced model deployment options (CPU offloading, custom configuration fields)
- UI refinements in model configuration and deployment sections
- Expanded compatibility for additional hardware environments (including Ampere)
- Various bug fixes related to container management, model deployment, and configuration

## 0.3.0

### Highlights

- Improvements in model config deployment and cluster mode; CE behavior aligns with enterprise (single‑node)
- Production mode React serving
- Improved cluster management and bootstrapping
- Significantly improved exception handling for model deployment/shutdown; force‑stop function added
- Cleanup and improvements in sentencetransformers middleware
- Added etcd for config management (visible under `/cluster/runtime_config`, deployed on port 12379)
- Added Traefik as load balancer; unified endpoint for all services
  - 80/443 with `/` as the UI, `/api/docs` Swagger, `/lab/lab` for JupyterLab
- Self‑signed certificates by default; can be replaced with your own
- Standardized model port mapping (51100–51199) to Ray Serve endpoints
- `KAMIWAZA_ENV` setting for container startup (advanced)
- Updated many components (vLLM 5.1, llama.cpp, CockroachDB, etc.)


