# Kamiwaza Community Edition

## License

See license at the bottom.

## Raw Download Links

[0.3.0 OSX](https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-0.3.0-osx.tar.gz)

[0.3.0 Linux](https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-0.3.0-UbuntuLinux.tar.gz)

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
