# Changelog

Notable changes to Kamiwaza Community Edition. For full documentation, see the docs site: https://docs.kamiwaza.ai

## 0.5.0

TBD

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


