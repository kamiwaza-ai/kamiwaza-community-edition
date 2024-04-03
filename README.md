# Kamiwaza Community Edition

## License

See license at the bottom.

## Discord

Join our discord to discuss, ask questions, get help: https://discord.gg/cVGBS5rD2U

## Showcase

Want pictures? Check the [showcase](showcase.md)!

## Quick Intro

Kamiwaza is a GenAI stack focused on two key technologies to enable Enterprise AI Anywhere: the **Distributed Data Engine** and **Inference Mesh**. This provides locality-aware data ops for RAG and scalable inference. But we are developers first, so we have built tools and are eager to drive a more seamless developer experience. The philosophy of Kamiwaza is:

*Opinionated, but loosely coupled*

Community edition now includes:

- [x] A local model repository that is API-accessible, allowing you to build applications around models and deployments of models (and for the Enterprise, you get an "artifactory for models")
- [x] A catalog, with the ability to ingest data easily from file or object, with credential management
- [x] Middleware for embeddings and vector database access, with neat features like model-aware chunking and automatic offset tracking to enable byte-range retrieval
- [x] Cluster awareness and resource management: Community edition runs roughly the same on OSX and Linux, giving you an ability to develop on a Mac but deploy on large Linux clusters (OSX is single-node only!)
- [x] A React UI
- [x] a robust set of REST APIs
- [x] A Jupyter environment ready to go with a handful of sample notebooks that show ingestion, retrieval, embedding and vector ops, model deployment and inferencing
- [x] a lot of developer middleware, especially around data ingestion, retrieval, model management and deployment, and more
- [x] Loose coupling; everything is built with a level of abstraction and fungibility in mind
- [x] Deploys a full integrated stack, so you get all the Kamiwaza goodness, along with a model engine (llamacpp/vLLM), a catalog (Acryl Datahub), using versions we've evaluated with our stack

We have a lot more cool things coming in both the community edition and the enterprise edition [hello@kamiwaza.ai](mailto:hello@kamiwaza.ai) if you'd like to know more about that!)

Enterprise edition adds:
* The ability to deploy and scale many models across an arbitrary number of hosts
* Integration with SAML and OAuth and more fine-grained control over identity and access
* Multi-location awareness with data locality affinity (in other words, you can construct things like prompt chains where the inferencing is local to the data)




## Kamiwaza Community Edition Release Notes

These will be deprecated in a later version when we release the docs engine.

### 0.2.0

#### Installing

0. **Read kamiwaza/README.md and ensure the pre-requisites (python 3.10.x, npm/node-21.6, pip, etc) are installed**
1. Untar kamiwaza tarball
2. Read kamiwaza/README.md and ensure the pre-requisites (python 3.10.x, npm/node-21.6, pip, etc) are installed
3. Run `bash install.sh` from this directory; this should create your venv and perform the rest of the install
4. If on OSX, run `bash build-llama-cpp.sh` (Even if you run it elsewhere locally, you should do this; Kamiwaza will build a specific commit and use this location) (We'd run this as a container, but Docker OSX doesn't have GPU access yet, which would make for a fairly miserable inferencing experience)
5. `cd frontend` and `npm install` and `npm start`

#### Running

1. Start kamiwaza venv with `source venv/bin/activate` from the Kamiwaza install folder (where you ran `bash install.sh`)
2. (Optional) Start ray with `ray start --head`; you can skip this if running locally - expect a heavier amount of logs if you don't

Then one of:

3. `python launch.py --standalone` to run Kamiwaza without ray running all the time (it will still be enabled for things like Retrieval)

**or**

3. `python launch.py` (optional `--ray-host=hostname` and `--ray-port=port` if you are launching additional nodes, to point at the IP of the head node)

(You can redirect also and background, as in `python launch.py --standalone > kamiwaza.log 2>&1 &`)

Then:

4. `cd frontend` and `npm start` (still debug mode react; and you can run this totally independently of kamiwaza, not that it will do anything on its own; but it isn't required)
5. If you want notebook services, run `bash restart-or-start-lab.sh`; the url with token will be printed; the notebooks have their own venv with the kamiwaza dependencies pre-installed, but `!pip install` commands in the notebooks will not affect the kamiwaza venv

### New in 0.2.0

* llamacpp build & deploy
* vllm deploy
* (both available in REST and models -> model details -> deploy in the UI)
* model download improvements
* model downloads are now quantity limited (6 is the default, configurable in the models config file)
* model config management
* Newly revamped introductory set of notebooks, 00->06 with a walkthrough
* Significant updates to Data Engine - improved RetrievalService, IngestionService, DataService, Runners, etc
* **strongly** recommend trying or reading through the new notebooks as they have more solid ingest/retrieval walkthroughs
* Auto-offsets are introduced and fully enabled, requirements

### Known issues

* Model East-West downloads are not functional; recommend a shared filesystem for cluster mode
* Cannot deploy additional vectorDB instances yet
* Only BAAI/llm-embedder and BAAI/bge-large-en-v1.5 are tested; and certainly, other embeddings that require instructions will have issues
* Embedder will not use local models (eg, they will pull from Hf)
* CORS policy is wide
* API and UI are not authenticated
* The model search API only supports '*' as a Hub parameter (which is only Hf currently)
* The `containers-up.sh` script which launches the containers sometimes doesn't wait quite long enough; both cockroachdb and datahub can sometimes take longer to spawn. If you see created containers not running you can re-run that script; it should generally be idempotent
* Stopping model engines will not remove them in the GUI when the modal disappears until you refresh


There are a few non-concerning errors during container bringup:
