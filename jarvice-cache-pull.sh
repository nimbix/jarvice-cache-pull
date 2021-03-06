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
# Set pull interval with environment variable or -i flag 
pull_interval=${PULL_INTERVAL}
while getopts "i:" opt; do
    case "$opt" in
        i)
            pull_interval=$OPTARG
            ;;
    esac
done
[[ -z ${pull_interval} ]] && exit 1
# Find worker architecture
arch=$(uname -m)
if [ "$arch" = "x86_64" ]; then
    arch=amd64
fi
while true; do
    # Get list of images from Config Map
    config=$(cat /etc/config/image.config)
    # Find number of images in cache
    images=$(( $(echo $config | jq 'length') - 1 ))
    for image in $(seq 0 $images); do
        private=$(echo $config | jq -r .[$image].private)
        reg=$(echo $config | jq -r .[$image].registry)
        # Login to Docker registry if image is private
        if [ "$private" == "true" ]; then
            user=$(echo $config | jq -r .[$image].config)
            cp /root/.docker/${user}/config.json /root/.docker/config.json
            docker login ${reg} &> /dev/null
        fi
        # Find location of image for architecture
        pull_image=$(echo $config | jq -r .[$image].arch.$arch)
        if [ "${pull_image}" != "null" ]; then
            echo "Pulling ${pull_image} from ${reg}"
            # Try to pull image from Docker registry
            docker pull ${pull_image} &> /dev/null
            if [ "$?" -ne "0" ]; then
                echo "ERROR: failed pulling ${pull_image} from ${reg}"
            fi
        fi
    done
    # Pause between iterations (seconds)
    sleep ${pull_interval}
done
