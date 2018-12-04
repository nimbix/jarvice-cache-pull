# Set which Ubuntu release to use (e.g. bionic)
ARG LSB_REL_NAME
FROM ubuntu:${LSB_REL_NAME}
ARG LSB_REL_NAME
ENV LSB_REL_NAME=${LSB_REL_NAME}
# Install dependencies for jarvice-cache-pull
RUN apt-get update && apt-get install -y jq curl gnupg
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN DEBARCH=$(dpkg --print-architecture) && echo "deb [arch=$DEBARCH] https://download.docker.com/linux/ubuntu ${LSB_REL_NAME} stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce
# Add jarvice-cache-pull
ADD jarvice-cache-pull.sh /usr/local/bin/jarvice-cache-pull.sh
RUN chmod a+x /usr/local/bin/jarvice-cache-pull.sh
