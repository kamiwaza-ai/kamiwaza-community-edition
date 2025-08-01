# Kamiwaza Installation Guide on OSX Sequoia

This document outlines the steps to install Kamiwaza on Mac OS Sequoia (15).

## Discord

This thread originated from our discord on our #community-edition-support channel. Join us to discuss, ask questions, get help: <https://discord.gg/cVGBS5rD2U>

## Pre-requisites

- MacOS Sequioa (15) installed 
- sudo privileges

## Installation Steps

### brew
	 1. install brew
		 - /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	 2. brew install pyenv pyenv-virtualenv docker cairo gobject-introspection jq

### dependencies
```
brew install cockroachdb/tap/cockroach
brew install cfssl etcd cmake
```

### docker
```
brew install docker --cask
sudo chown -R $(whoami):staff ~/.docker
open -a Docker
```

### pyenv
To configure your shell environment to auto load pyenv
```bash
echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc
source ~/.zshrc
```
Replace `.zshrc` to match your shell environment_

	 1. pyenv install 3.10
     2. pyenv local 3.10

#### 3.10 is a specific requirement for kamiwaza

### Node.js and NVM

1. Install NVM and Node.js:

    ```bash
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
    # Add these to your .bashrc file to have auto load
    nvm install 21
    ```

### Kamiwaza Installation

1. Download and install Kamiwaza:

    ```bash
    mkdir kamiwaza
    cd kamiwaza
    curl -L -O https://github.com/kamiwaza-ai/kamiwaza-community-edition/raw/main/kamiwaza-community-0.3.3-OSX.tar.gz
    tar -xvf kamiwaza-community-0.3.3-OSX.tar.gz
    bash install.sh --community
    ```

    This script will automatically set up a virtual environment, install the necessary packages, and perform initial configuration.


## Post-Installation Steps

### Starting Kamiwaza Services

As of 0.3.2:

```bash
bash startup/kamiwazad.sh start
```

### Managing Kamiwaza Services

Once Kamiwaza is running, you can manage the services using the following commands:

**Check Service Status:**
```bash
bash startup/kamiwazad.sh status
```
This command will display the current status of all Kamiwaza services, showing which components are running, stopped, or experiencing issues. Use this to verify that your installation is working correctly or to troubleshoot any problems.

**Stop Services:**
```bash
bash startup/kamiwazad.sh stop
```
This command gracefully shuts down all Kamiwaza services. Use this when you need to stop the system for maintenance, updates, or to free up system resources. Always use this command rather than forcefully killing processes to ensure data integrity.

## Troubleshooting

- Mentioned in the doc, but remember to log out/in after adding to the docker group
- Potential error in the `passlib` library for bcrypt
    - [passlib](https://foss.heptapod.net/python-libs/passlib) hasn't been updated in a few years, if you run into an `AttributeError`
        - `__about__` does not exist
    - if you're attempting to install with python 3.11
        - patch file ~/.pyenv/versions/kamiwaza/lib/python3.10/site-packages/passlib/handlers/bcrypt.py
        - adjust path to match your environment
        - line 620 
            - from
	            - version = _bcrypt.__about__.__version__
            - to
    		    - version = _bcrypt.__version__
- If the final step in running `admin_db_reset.py` fails you can run the commands manually through a console


## Additional Notes

- The installation steps and scripts provided by Kamiwaza are designed to streamline the setup process but always review each command for your specific environment.
