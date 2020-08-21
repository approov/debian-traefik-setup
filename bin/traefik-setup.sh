#!/bin/sh

set -eu

Setup_Depedencies() {
    printf "\n---> INSTALL DEPENDENCIES <---\n"
    sudo apt update

    sudo apt -y install \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        software-properties-common
}

Setup_Docker() {
    printf "\n---> INSTALL DOCKER <---\n"

    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

    sudo apt-key fingerprint 0EBFCD88

    sudo add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable"

    sudo apt update

    sudo apt -y install docker-ce docker-ce-cli containerd.io
}

Setup_Docker_Compose() {
    printf "\n---> INSTALL DOCKER COMPOSE <---\n"
    local _download_url="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
    sudo curl -L "${_download_url}" -o /usr/local/bin/docker-compose
    sudo chmod ug+x /usr/local/bin/docker-compose
}

Setup_Traefik() {
    printf "\n---> INSTALL TRAEFIK <---\n"

    sudo cp -r ./traefik /opt

    cd /opt/traefik

    sudo touch acme.json

    # Traefik will not create the certificates if we don't fix the permissions
    #  for the file where it stores the LetsEncrypt certificates.
    sudo chmod 600 acme.json

    # Creates a docker network that will be used by Traefik to proxy the requests to the docker containers:
    sudo docker network create traefik || true

    if [ ! -f ./.env ]; then
        printf "\n
        ===> ERROR:

        Please copy the .env.example file to .env:
        $ sudo cp ./traefik/.env.example /opt/traefik/.env

        Now customize it to your values with:
        $ sudo nano /opt/traefik/.env

        Afterwards just re-run the setup again:
        $ ./aws-ec2-setup.sh

        \n"

        exit 1
    fi

    # Traefik will be listening on port 80 and 443, and proxy the requests to
    #  the associated container for the domain. Check the README for more details.
    sudo docker-compose up -d traefik

    # Just give sometime for it to start in order to check the logs afterwards.
    sleep 5

    printf "\n---> CHECK TRAEFIK LOGS <---\n"
    sudo docker-compose logs traefik

    cd -
}

Main() {
    Setup_Depedencies
    Setup_Docker
    Setup_Docker_Compose
    Setup_Traefik

    printf "\n\n---> DOCKER VERSION <---\n"
    sudo docker version

    printf "\n---> DOCKER COMPOSE VERSION <---\n"
    sudo docker-compose --version
    echo

    printf "\n---> GIT VERSION<---\n"
    git version
    echo

    printf "\n---> TRAEFIK installed at: /opt/traefik <---\n"

    printf "\nFrom /opt/traefik folder you can ran any docker-compose command.\n"
    printf "\nSome useful examples:\n"

    printf "\n## Start Traefik:\n"
    printf "sudo docker-compose up -d traefik\n"

    printf "\n## Restart Traefik:\n"
    printf "sudo docker-compose restart traefik\n"

    printf "\n## Destroy Traefik:\n"
    printf "sudo docker-compose down\n"

    printf "\n## Tailing the Traefik logs in realtime:\n"
    printf "sudo docker-compose logs --follow traefik\n"

    printf "\n---> TRAEFIK is now listening for new docker containers <---\n\n"
}

Main ${@}
