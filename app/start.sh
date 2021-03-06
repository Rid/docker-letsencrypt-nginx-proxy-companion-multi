#!/bin/bash

until nc -z ${NGINX_PROXY_CONTAINER} 80; do echo "waiting for service in container..."; sleep 0.5; done

# SIGTERM-handler
term_handler() {
    [[ -n "$docker_gen_pid" ]] && kill $docker_gen_pid
    [[ -n "$letsencrypt_service_pid" ]] && kill $letsencrypt_service_pid

    source /app/functions.sh
    remove_all_location_configurations

    exit 143; # 128 + 15 -- SIGTERM
}

trap 'term_handler' INT QUIT TERM

/app/letsencrypt_service &
letsencrypt_service_pid=$!

if [ -z ${NGINX_DOCKER_GEN_ENDPOINTS} ]; then
    docker-gen -watch -notify '/app/update_certs' -wait 15s:60s /app/letsencrypt_service_data.tmpl /app/letsencrypt_service_data &
else
    echo -e "Endpoints: ${NGINX_DOCKER_GEN_ENDPOINTS} \n"
    docker-gen -endpoints ${NGINX_DOCKER_GEN_ENDPOINTS} -watch -notify '/app/update_certs' -wait 15s:60s /app/letsencrypt_service_data.tmpl /app/letsencrypt_service_data &
fi
docker_gen_pid=$!

# wait "indefinitely"
while [[ -e /proc/$docker_gen_pid ]]; do
    wait $docker_gen_pid # Wait for any signals or end of execution of docker-gen
done

# Stop container properly
term_handler