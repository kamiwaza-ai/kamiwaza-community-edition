# License

See license at the bototm.

# Discord

Join our discord to discuss, ask questios, get help: https://discord.gg/cVGBS5rD2U

# Kamiwaza Release Notes

These will be deprecated in a later version when we release the docs engine.

## 0.2.0

### Installing

0. **Read kamiwaza/README.md and ensure the pre-requisites (python 3.10.x, npm/node-21.6, pip, etc) are installed**
1. Untar kamiwaza tarball
2. Read kamiwaza/README.md and ensure the pre-requisites (python 3.10.x, npm/node-21.6, pip, etc) are installed
3. Run `bash install.sh` from this directory; this should create your venv and perform the rest of the install
4. If on OSX, run `bash build-llama-cpp.sh` (Even if you run it elsewhere locally, you should do this; Kamiwaza will build a specific commit and use this location) (We'd run this as a container, but Docker OSX doesn't have GPU access yet, which would make for a fairly miserable inferencing experience)
5. `cd frontend` and `npm install` and `npm start`

### Running

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

```bash
failed to generate node certificate and key: error writing node server certificate to certs/node.crt: open certs/node.crt: file exists
```

Will happen on the 2nd bring-up because certs were generated on the first; but

```bash
failed to connect to `host=localhost user=root database=`: dial error (dial tcp 127.0.0.1:26257: connect: connection refused)
```

Will happen on the first quite possibly because cockroachdb is still setting up.

These generally should not be concerning.

Installer has a warning:

```bash
WARNING: The candidate selected for download or install is a yanked version: 'executing' candidate (version 2.0.0 at https://files.pythonhosted.org/packages/bb
/3f/748594706233e45fd0e6fb57a2fbfe572485009c52b19919d161a0ae5d52/executing-2.0.0-py2.py3-none-any.whl#sha256=06df6183df67389625f4e763921c6cf978944721abf3e714000200aab95b0657 (from https://pypi.org/simple/executing/))
Reason for being yanked: Released 2.0.1 which is equivalent but added 'python_requires = >=3.5' so that pip install with Python 2 uses the previous version 1.2.0.
```

We don't allow python 2 so this is a a non-issue.

Contact support@kamiwaza.ai with issues.



# kamiwaza-community-edition
Holding Kamiwaza Community Edition releases.

## License

SOFTWARE LICENSE AGREEMENT FOR KAMIWAZA COMMUNITY EDITION

IMPORTANT: BY INSTALLING, COPYING, OR OTHERWISE USING THE KAMIWAZA COMMUNITY EDITION SOFTWARE, YOU AGREE TO BE BOUND BY THE TERMS OF THIS LICENSE AGREEMENT. IF YOU DO NOT AGREE TO THE TERMS OF THIS LICENSE AGREEMENT, DO NOT INSTALL, COPY, OR USE THE SOFTWARE.

1. LICENSE GRANT: Kamiwaza.AI ("Licensor") hereby grants you a non-exclusive, non-transferable, license to use the KAMIWAZA Community Edition software ("Software") solely for your personal or internal business purposes. This License does not allow you to use the Software on any system with which you charge for the Software's use or for the use of the Software's functionalities.

2. RESTRICTIONS: You may not reverse engineer, decompile, or disassemble the Software, except and only to the extent that such activity is expressly permitted by applicable law notwithstanding this limitation. You may not rent, lease, loan, sublicense, or distribute the Software or any portion thereof. You may not make any copies of the Software, except for the purpose of backup or archival purposes.

3. NO WARRANTY: THE SOFTWARE IS PROVIDED "AS IS," WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE LICENSORS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

4. LIMITATION OF LIABILITY: IN NO EVENT WILL LICENSOR BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

5. RESTRICTED USE: You shall not use the Software for any illegal purposes or in any manner inconsistent with this Agreement. You agree to comply with all applicable laws and regulations regarding your use of the Software.

6. TERMINATION: This License is effective until terminated. Your rights under this License will terminate automatically without notice from Licensor if you fail to comply with any term(s) of this License. Upon termination, you shall cease all use of the Software and destroy all copies, full or partial, of the Software.

7. GENERAL: This License constitutes the entire agreement between the parties with respect to the use of the Software licensed hereunder and supersedes all prior or contemporaneous understandings regarding such subject matter. No amendment to or modification of this License will be binding unless in writing and signed by Licensor.

By installing, copying, or otherwise using the KAMIWAZA Community Edition, you acknowledge that you have read this license, understand it, and agree to be bound by its terms and conditions.

Kamiwaza.ai
3/29/24
