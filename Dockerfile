FROM ubuntu:22.04
# FROM registry.tc.egov.local/gitlab/gitlab-runner:v0.1

ENV JAVA_VERSION_MAJOR=8 \
    JAVA_VERSION_MINOR=351 \
    APACHE_MAVEN_VERSION=3.6.3 \
    DOCKER_MACHINE_VERSION=0.16.2 \
    DUMB_INIT_VERSION=1.2.5 \
    GIT_LFS_VERSION=2.7.1 \
    BAZEL_VERSION=5.3.2 \
    HELM_VERSION=v3.8.2 \
    TERRAFORM_VERSION=1.3.6 \
    GIT_LOCAL=gitlab.sol77.local \
    REGISTRY_LOCAL=registry.sol77.local

# Repositories
RUN apt-get update -y --allow-unauthenticated && \
    # apt-get upgrade -y --allow-unauthenticated && \
    apt-get install -y --allow-unauthenticated ca-certificates software-properties-common coreutils ca-certificates wget apt-transport-https vim nano curl rsync curl gcc python3.9 python3-pip python3-lxml git jq vim make npm postgresql-client unzip


RUN mkdir -p /etc/ssl/certs /etc/docker/certs.d/${REGISTRY_LOCAL}
# DOCKER Certificates
# registry.sol77.local
RUN openssl s_client -showcerts -connect ${REGISTRY_LOCAL}:443 -servername ${REGISTRY_LOCAL} < /dev/null 2>/dev/null | openssl x509 -outform PEM > /etc/docker/certs.d/${REGISTRY_LOCAL}/${REGISTRY_LOCAL}.crt
# gitlab.sol77.local
RUN openssl s_client -showcerts -connect ${GIT_LOCAL}:443 -servername ${GIT_LOCAL} < /dev/null 2>/dev/null | openssl x509 -outform PEM > /usr/local/share/ca-certificates/${GIT_LOCAL}.crt 
RUN update-ca-certificates

RUN echo "[global]" > /etc/pip.conf && \
    echo "trusted-host=pypi.python.org" >> /etc/pip.conf && \
    echo "             pypi.org" >> /etc/pip.conf && \
    echo "             files.pythonhosted.org" >> /etc/pip.conf && \
    pip3 install --upgrade pip

# Install python requirements
# COPY requirements.txt /tmp/requirements.txt
COPY requirements3.txt /tmp/requirements3.txt

RUN pip3 install -r /tmp/requirements3.txt

# Docker Kuber
RUN curl -ks https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    touch /etc/apt/sources.list.d/kubernetes.list && \
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl

RUN curl -k https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    tar -xzvf helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/helm

# Get docker-compose in the agent container
# RUN curl -kL https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
RUN curl https://get.docker.com -o install.sh && sh install.sh

RUN curl -kL https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz > kubeval-linux-amd64.tar.gz && \
    tar -xf kubeval-linux-amd64.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/kubeval && \
    rm -f kubeval-linux-amd64.tar.gz

RUN curl -kfsSL https://gitlab-runner-downloads.s3.amazonaws.com/latest/deb/gitlab-runner_amd64.deb -o /tmp/gitlab-runner_amd64.deb && \
    dpkg -i /tmp/gitlab-runner_amd64.deb

RUN apt-get update &&  \
    apt-get -f install -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm /tmp/gitlab-runner_amd64.deb && \
    gitlab-runner --version && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    # wget --no-check-certificate -nv https://github.com/docker/machine/releases/download/v${DOCKER_MACHINE_VERSION}/docker-machine-Linux-x86_64 -O /usr/bin/docker-machine && \
    # chmod +x /usr/bin/docker-machine && \
    # docker-machine --version && \
    wget --no-check-certificate -nv https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_x86_64 -O /usr/bin/dumb-init && \
    chmod +x /usr/bin/dumb-init && \
    dumb-init --version && \
    wget --no-check-certificate -nv https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-amd64-v${GIT_LFS_VERSION}.tar.gz -O /tmp/git-lfs.tar.gz && \
    mkdir /tmp/git-lfs && \
    tar -xzf /tmp/git-lfs.tar.gz -C /tmp/git-lfs/ && \
    mv /tmp/git-lfs/git-lfs /usr/bin/git-lfs && \
    rm -rf /tmp/git-lfs* && \
    git-lfs install --skip-repo && \
    git-lfs version

# Terraform
RUN curl -kfsSL  https://hashicorp-releases.yandexcloud.net/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o /tmp/terraform.zip && \
    cd /usr/local/bin && unzip /tmp/terraform.zip && \
    chmod +x terraform
# https://github.com/docker/docker/tree/master/hack/dind
ENV DIND_COMMIT ed89041433a031cafc0a0f19cfe573c31688d377
RUN set -eux; \
	wget --no-check-certificate -O /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"; \
	chmod +x /usr/local/bin/dind

ENV KUSTOMIZE_VERSION v4.5.5
RUN curl -kfsSL https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.5/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz > kustomize_${KUSTOMIZE_VERSION}.tar.gz && \
    tar -xzvf kustomize_${KUSTOMIZE_VERSION}.tar.gz -C /usr/local/bin/ && \
    kustomize version

#Install bazel
RUN curl -kfsSL https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-linux-x86_64 > /usr/local/bin/bazel && \
    chmod +x /usr/local/bin/bazel

#Install Java
RUN mkdir -p /usr/lib/jvm
COPY jdk-8u351-linux-x64.tar.gz /usr/lib/jvm/jdk-8u351-linux-x64.tar.gz
RUN cd /usr/lib/jvm \
    && tar xzf jdk-8u351-linux-x64.tar.gz \
    && rm jdk-8u351-linux-x64.tar.gz
ENV JAVA_HOME /usr/lib/jvm/jdk1.8.0_351

RUN update-alternatives --install "/usr/bin/java" "java" "/usr/lib/jvm/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR}/bin/java" 1500
RUN update-alternatives --install "/usr/bin/javac" "javac" "/usr/lib/jvm/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR}/bin/javac" 1500
RUN update-alternatives --install "/usr/bin/javaws" "javaws" "/usr/lib/jvm/jdk1.${JAVA_VERSION_MAJOR}.0_${JAVA_VERSION_MINOR}/bin/javaws" 1500

# # ADD certificate to truststore
# RUN ${JAVA_HOME}/jre/bin/keytool -trustcacerts -keystore "${JAVA_HOME}/jre/lib/security/cacerts" -storepass changeit -importcert -noprompt -alias ${GIT_LOCAL} -file "/usr/local/share/ca-certificates/${GIT_LOCAL}.crt"

# get maven ${APACHE_MAVEN_VERSION}
RUN wget --no-verbose -O /tmp/apache-maven-${APACHE_MAVEN_VERSION}.tar.gz http://archive.apache.org/dist/maven/maven-3/${APACHE_MAVEN_VERSION}/binaries/apache-maven-${APACHE_MAVEN_VERSION}-bin.tar.gz

# install maven
RUN tar xzf /tmp/apache-maven-${APACHE_MAVEN_VERSION}.tar.gz -C /opt/
RUN ln -sf /opt/apache-maven-${APACHE_MAVEN_VERSION} /opt/maven
RUN ln -sf /opt/maven/bin/mvn /usr/local/bin
RUN rm -f /tmp/apache-maven-${APACHE_MAVEN_VERSION}.tar.gz
ENV MAVEN_HOME /opt/maven

# Private keys gitlab-runner
RUN mkdir -p /home/gitlab-runner/.ssh /root/.ssh /root/.gitlab-runner
COPY id_rsa /home/gitlab-runner/.ssh/id_rsa
COPY id_rsa /root/.ssh/id_rsa

# GITLAB-RUNNER Certificates
# registry
RUN openssl s_client -showcerts -connect ${REGISTRY_LOCAL}:443 -servername ${REGISTRY_LOCAL} < /dev/null 2>/dev/null | openssl x509 -outform PEM > /etc/gitlab-runner/certs/${REGISTRY_LOCAL}
# gitlab
RUN openssl s_client -showcerts -connect ${GIT_LOCAL}:443 -servername ${GIT_LOCAL} < /dev/null 2>/dev/null | openssl x509 -outform PEM > /etc/gitlab-runner/certs/${GIT_LOCAL}.crt


# Host keys sctrict disable
COPY ssh_config /home/gitlab-runner/.ssh/config
COPY ssh_config /root/.ssh/config
RUN cat /root/.ssh/config

# CHOWN
RUN chown gitlab-runner:gitlab-runner -R /home/gitlab-runner && chmod 0700 /home/gitlab-runner/.ssh && chmod 0600 /home/gitlab-runner/.ssh/*
RUN chown -R root:root /root && chmod 0700 /root/.ssh && chmod 0600 /root/.ssh/*

# Clean
RUN apt-get clean all

COPY dockerd-entrypoint.sh /
COPY entrypoint /
RUN chmod +x /entrypoint

VOLUME /var/lib/docker
EXPOSE 2375 2376

STOPSIGNAL SIGQUIT
VOLUME ["/etc/gitlab-runner", "/home/gitlab-runner", "/root", "/var/lib/docker"]
ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint"]
CMD ["run", "--working-directory=/home/gitlab-runner"]
