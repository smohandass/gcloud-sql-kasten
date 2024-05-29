FROM registry.access.redhat.com/ubi9/ubi:9.3-1476 as builder

# Install from the local file
RUN dnf install -y vi
RUN dnf install -y wget 

# Install Google cloud SDK
RUN curl -sSL https://sdk.cloud.google.com | bash 
ENV PATH $PATH:/root/google-cloud-sdk/bin
RUN gcloud components install beta --quiet

# Install Kanister Tools 
RUN wget https://raw.githubusercontent.com/kanisterio/kanister/master/scripts/get.sh
RUN ln -s /usr/bin/sha256sum /usr/bin/shasum
RUN sed -i 's/shasum -a 256/shasum/g' get.sh
RUN bash get.sh

