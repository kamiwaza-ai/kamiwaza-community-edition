# scripted install

These scripts are relatively lightly tested, but we have run them multiple times on Azure Canonical Ubuntu 22.04LTS-Server instances.

The flow is essentially:
1. `bash 1.sh`
2. reboot
3. `bash 2.sh`
4. log out, back in
5. `bash 3.sh`

That concludes with it launching the kamiwaza `install.sh`

These scripts include pulling the kamiwaza tar.gz from github.

These are Ubuntu Linux only, there is not an osx equivalent.

