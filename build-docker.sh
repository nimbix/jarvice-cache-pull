#!/bin/bash
#
# Copyright (c) 2018, Nimbix, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met: 
# 
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer. 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
#
# The views and conclusions contained in the software and documentation are 
# those of the authors and should not be interpreted as representing official 
# policies, either expressed or implied, of Nimbix, Inc.
#
set -e
usage(){
    echo 
    printf "build-docker -h <ppc64le-host> -r <docker-repo>\n" 
    printf "\t-R <docker-registry> -u <docker-user> -U <ubuntu-release>\n"
    printf "\t-g <github-repository> -t <github-token>\n"
    echo
}
my_error(){
    echo "ERROR: $1"
    usage
    exit 1
}
ppc64le_host=""
docker_repo=""
docker_reg=""
docker_user=""
ubuntu_rel=""
github_repo=""
github_token=""
while getopts "h:r:R:u:U:g:t:" opt; do
    case "$opt" in
        h)
            ppc64le_host=$OPTARG
            ;;
        r)
            docker_repo=$OPTARG
            ;;
        R)
            docker_reg=$OPTARG
            ;;
        u)
            docker_user=$OPTARG
            ;;
        U)
            ubuntu_rel=$OPTARG
            ;;
        g)
            github_repo=$OPTARG
            ;;
        t)
            github_token=$OPTARG
    esac
done
[[ -z ${ppc64le_host} ]] && my_error "missing ppc64le build host"
[[ -z ${docker_repo} ]] && my_error "missing Docker repository"
[[ -z ${docker_reg} ]] && my_error "missing Docker registry"
[[ -z ${docker_user} ]] && my_error "missing Docker user"
[[ -z ${ubuntu_rel} ]] && my_error "missing Ubuntu release"
[[ -z ${github_repo} ]] && my_error "missing GitHub repository"
[[ -z ${github_token} ]] && my_error "missing GitHub access token"
# Check for docker
which docker &> /dev/null || my_error "missing docker CLI"
echo "Enter ${docker_reg} password for ${docker_user}"
docker login -u ${docker_user} ${docker_reg}
docker build --build-arg LSB_REL_NAME=${ubuntu_rel} -t ${docker_repo}:amd64 .
docker push ${docker_repo}:amd64
github_repo="https://${github_token}@${github_repo}"
ssh_cmd="which docker &> /dev/null; \
        git clone ${github_repo} /tmp/git-build; \
        docker build --build-arg LSB_REL_NAME=${ubuntu_rel} \
        -t ${docker_repo}:ppc64le /tmp/git-build; \
        docker push ${docker_repo}:ppc64le;
        rm -rf /tmp/git-build"
ssh ${ppc64le_host} "${ssh_cmd}"
docker pull ${docker_repo}:ppc64le
export DOCKER_CLI_EXPERIMENTAL=enabled 
docker manifest create ${docker_repo}:latest \
        ${docker_repo}:amd64 \
        ${docker_repo}:ppc64le
docker manifest annotate ${docker_repo}:latest ${docker_repo}:amd64 \
        --os linux \
        --arch amd64
docker manifest annotate ${docker_repo}:latest ${docker_repo}:ppc64le \
        --os linux \
        --arch ppc64le
docker manifest push -p ${docker_repo}:latest
