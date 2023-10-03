# Download the binary for your system
sudo curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64

# Give it permission to execute
sudo chmod +x /usr/local/bin/gitlab-runner

# Create a GitLab Runner user
sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash

# Install and run as a service
sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
sudo gitlab-runner start

# sudo apt-get install gitlab-runner

# Install docker on aws ubuntu instance: 
sudo apt install docker.io
sudo usermod -aG docker gitlab-runner
sudo apt install docker-compose
sudo apt-get install jq
# here we want to save the cache in the volume of the system and not the docker image itself
sudo ls /etc/gitlab-runner/
sudo nano /etc/gitlab-runner/config.toml
# add this lines to the [[runners]]
cache_dir=”/cache”
volumes=[“/cache”]
docker volume inspect # shows where the cache is saved on gitlab runner hardware

# install kubectl on the runner

