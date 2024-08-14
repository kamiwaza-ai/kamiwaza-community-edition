# Kamiwaza Community Edition

## License

See license at the bottom.

## Raw Download Links

[0.3.1 OSX](https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-0.3.1-osx.tar.gz)

[0.3.1 Linux](https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-0.3.1-UbuntuLinux.tar.gz)

## Discord

Join our discord to discuss, ask questions, get help: https://discord.gg/cVGBS5rD2U

## Showcase

Want pictures? Check the [showcase](showcase.md)!

## Full Installation Instructions

We now have [full installation instructions](INSTALL.md) for the Kamiwaza Community Edition for Linux that go step-by-step from a fresh system for every pre-requisite.

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

### 0.3.0

#### Installing

0. **Read kamiwaza/README.md and ensure the pre-requisites (python 3.10.x, npm/node-21.6, pip, etc) are installed**
1. Untar kamiwaza tarball
2. Read kamiwaza/README.md and ensure the pre-requisites (python 3.10.x, npm/node-21.6, pip, etc) are installed
3. Run `bash install.sh` from this directory; this should create your venv and perform the rest of the install
4. If on OSX, run `bash build-llama-cpp.sh` (Even if you run it elsewhere locally, you should do this; Kamiwaza will build a specific commit and use this location) (We'd run this as a container, but Docker OSX doesn't have GPU access yet, which would make for a fairly miserable inferencing experience)

#### Running

1. In 0.3.0 you should be able to run `bash start-all.sh` which should launch all of the services; `bash stop-all.sh` should also shut everything down


### New in 0.3.0

* Improvements in model config deployment and cluster mode, and cluster mode now usable in community edition (still single-node, but the behavior should match enterprise)
* Improved UI
* Production mode React serving
* Improved cluster management and bootstrapping
* Significantly improved exception handling for model deployment/shutdown; including a force-stop function that will clear a model if the underlying engine is unavailable to respond to a graceful shutdown
* Cleanup and improvements in sentencetransformers middleware
* Added etcd for config management - visible under /cluster/runtime_config endpoint; we deploy on port 12379
* Added Traefik as a load balancer; Kamiwaza now sports a unified endpoint for all services
* 80/443 with / being the ui, /api/docs being the swagger docs, /lab/lab for Jupyter lab
* Deploys with self-signed certificates but you can now replace the certificate with your own (generally /deployment/envs/[env]/kamiwaza-traefik/[amd64|arm64]/certs
* Support for letsencrypt coming in the future
* All editions now standardize on Traefik (all hosts) providing a port from 51100-51199 for model deployments, which map to ray.serve endpoints
* Added 'KAMIWAZA_ENV' setting for startup for containers - advanced use
* Updated over 50 packages and components, including vLLM (5.1), llamacpp (recent build), cockroachDB, etc.
* Improved model config management - more fields; fields are now generally all optional and graceful to not being set
* Many fixes
* And many more!


### Known issues

* Default vLLM memory usage is not computed correctly and will default to 0.9; set `gpu_memory_utilization` as a config appropriate for your model/system
* While we have significant updates, Llama-3.1 came out during testing; note that it will generally **not** function, but we will evaluate llamacpp/vLLM updates to support its RoPE config changes in 0.3.1
* Model East-West downloads are not functional; use a shared filesystem
* Cannot deploy additional vectorDB instances yet
* Only BAAI/llm-embedder and BAAI/bge-large-en-v1.5 are tested; and certainly, other embeddings that require instructions will have issues
* Embedder will not use local models (eg, they will pull from Hf)
* CORS policy is wide
* API and UI are not authenticated - although you can now restrict access to port 80/443 from outside networks as Kamiwaza has load balancing
* The model search API only supports '*' as a Hub parameter (which is only Hf currently)


## LICENSE

This software is (c) 2023-2024 Matthew Wallace, all rights reserved

SOFTWARE LICENSE AGREEMENT FOR KAMIWAZA COMMUNITY EDITION

IMPORTANT: BY INSTALLING, COPYING, OR OTHERWISE USING THE KAMIWAZA COMMUNITY EDITION SOFTWARE, YOU AGREE TO BE BOUND BY THE TERMS OF THIS LICENSE AGREEMENT. IF YOU DO NOT AGREE TO THE TERMS OF THIS LICENSE AGREEMENT, DO NOT INSTALL, COPY, OR USE THE SOFTWARE.

LICENSE GRANT: Kamiwaza.AI ("Licensor") hereby grants you a non-exclusive, non-transferable, license to use the KAMIWAZA Community Edition software ("Software") solely for your personal or internal business purposes. This License does not allow you to use the Software on any system with which you charge for the Software's use or for the use of the Software's functionalities.

RESTRICTIONS: You may not reverse engineer, decompile, or disassemble the Software, except and only to the extent that such activity is expressly permitted by applicable law notwithstanding this limitation. You may not rent, lease, loan, sublicense, or distribute the Software or any portion thereof. You may not make any copies of the Software, except for the purpose of backup or archival purposes.

NO WARRANTY: THE SOFTWARE IS PROVIDED "AS IS," WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE LICENSORS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

LIMITATION OF LIABILITY: IN NO EVENT WILL LICENSOR BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

RESTRICTED USE: You shall not use the Software for any illegal purposes or in any manner inconsistent with this Agreement. You agree to comply with all applicable laws and regulations regarding your use of the Software.

TERMINATION: This License is effective until terminated. Your rights under this License will terminate automatically without notice from Licensor if you fail to comply with any term(s) of this License. Upon termination, you shall cease all use of the Software and destroy all copies, full or partial, of the Software.

GENERAL: This License constitutes the entire agreement between the parties with respect to the use of the Software licensed hereunder and supersedes all prior or contemporaneous understandings regarding such subject matter. No amendment to or modification of this License will be binding unless in writing and signed by Licensor.

By installing, copying, or otherwise using the KAMIWAZA Community Edition, you acknowledge that you have read this license, understand it, and agree to be bound by its terms and conditions.

Kamiwaza.ai 3/29/24
