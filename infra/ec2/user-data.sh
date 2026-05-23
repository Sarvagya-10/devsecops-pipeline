#!/bin/bash
###############################################################################
# DevSecOps EC2 Bootstrap
# Target: Ubuntu 22.04 LTS on t3.micro (1 GB RAM)
# Installs: Java 17, Jenkins LTS, Docker CE, Trivy, kubectl, AWS CLI v2,
#           SonarQube (image pulled, started on demand)
# Adds:     4 GB swap (required for SonarQube on 1 GB RAM)
#           Bare git repo at /srv/git/devsecops.git
###############################################################################
set -euxo pipefail

# Mirror all output to a log so we can debug failures via SSH
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "===== DevSecOps EC2 Bootstrap starting at $(date -u) ====="

export DEBIAN_FRONTEND=noninteractive

###############################################################################
# 1. System update + base utilities
###############################################################################
apt-get update -y
apt-get upgrade -y
apt-get install -y \
    curl wget gnupg lsb-release ca-certificates \
    apt-transport-https software-properties-common \
    unzip git fontconfig jq net-tools

###############################################################################
# 2. Swap (4 GB) - lets SonarQube run on a 1 GB RAM instance
###############################################################################
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
sysctl -w vm.swappiness=10

###############################################################################
# 3. Kernel tuning for SonarQube (Elasticsearch under the hood)
###############################################################################
echo "vm.max_map_count=524288" >> /etc/sysctl.d/99-sonarqube.conf
echo "fs.file-max=131072"      >> /etc/sysctl.d/99-sonarqube.conf
sysctl --system

###############################################################################
# 4. Java 17 (Jenkins requirement)
###############################################################################
apt-get install -y openjdk-17-jdk
java -version

###############################################################################
# 5. Jenkins (container-based - avoids apt GPG key churn)
#    Started AFTER Docker is installed in step 6. We only pull the image here.
###############################################################################
# (deferred: see step 6.5)

###############################################################################
# 6. Docker CE
###############################################################################
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io \
                   docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

###############################################################################
# 6.5. Jenkins container (depends on Docker from step 6)
#      Mounts docker.sock so pipelines can build images on the host daemon.
###############################################################################
docker volume create jenkins_home
DOCKER_GID="$(getent group docker | cut -d: -f3)"
docker pull jenkins/jenkins:lts-jdk17
docker run -d --name jenkins \
    --restart unless-stopped \
    -p 8080:8080 -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --group-add "${DOCKER_GID}" \
    jenkins/jenkins:lts-jdk17

###############################################################################
# 7. SonarQube image (do NOT start - we start on demand to save RAM)
###############################################################################
docker pull sonarqube:lts-community

###############################################################################
# 8. Trivy (Aqua Security)
###############################################################################
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
    | tee /etc/apt/sources.list.d/trivy.list > /dev/null
apt-get update -y
apt-get install -y trivy

###############################################################################
# 9. kubectl (Kubernetes 1.30 stable)
###############################################################################
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
    | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
apt-get update -y
apt-get install -y kubectl

###############################################################################
# 10. AWS CLI v2
###############################################################################
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip
aws --version

###############################################################################
# 11. Self-hosted bare git repo (origin for Jenkins)
###############################################################################
mkdir -p /srv/git
cd /srv/git
git init --bare devsecops.git
chown -R ubuntu:ubuntu /srv/git

###############################################################################
# 12. MOTD banner
###############################################################################
cat > /etc/motd <<'EOF'
============================================================
  DevSecOps Pipeline - EC2 Build Server
  Tools: Jenkins(8080), SonarQube(9000), Trivy, Docker, kubectl
  Bare git repo: ubuntu@<host>:/srv/git/devsecops.git
  Bootstrap log: /var/log/user-data.log
============================================================
EOF

echo "===== DevSecOps EC2 Bootstrap finished at $(date -u) ====="
