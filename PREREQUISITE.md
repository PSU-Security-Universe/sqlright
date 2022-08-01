# Prerequisites

* Update the CPU settings for the best fuzzing performance (necessary for every system reboot).

```bash
# Disable On-demand CPU scaling
cd /sys/devices/system/cpu
echo performance | sudo tee cpu*/cpufreq/scaling_governor
# Avoid having crashes being misinterpreted as hangs
sudo sh -c " echo core >/proc/sys/kernel/core_pattern "
```

* Install `Docker` in `Ubuntu` (Tested on `Ubuntu 20.04` with Docker version `>= 20.10.16`.)  

```bash
# The script is grabbed from Docker official documentation: https://docs.docker.com/engine/install/ubuntu/
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# The next script could fail on some machines. However, the following installation process should still succeed. 
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
# Receiving a GPG error when running apt-get update?
# Your default umask may not be set correctly, causing the public key file for the repo to not be detected. Run the following command and then try to update your repo again: sudo chmod a+r /etc/apt/keyrings/docker.gpg.
# To test the Docker installation. 
sudo docker run hello-world # Expected outputs 'Hello from Docker!'
``` 

Interacting with `Docker` requires the `root` privilege. A non-root user should be a sudoer to use docker.

### Run docker inside VM

Running `SQLRight` inside a virtual machine may lead to unexpected errors, and thus is not recommendated. If you have to do it, at least make sure `--start-core` + `--num-concurrent` won't exceed the total number of avaiable CPU cores in the VM.
