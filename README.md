# DEBIAN TRAEFIK SETUP

[Traefik](https://containo.us/traefik/) setup to run all docker containers on a Debian server behind the same port 80 and 443 with automated LetsEncrypt certificates creation and renewal.


## CREATE A NEW DEBIAN SERVER

First of all create new Debian server in your provider of choice, but if you prefer to use an existing one, then you need to guarantee that the existing server doesn't have anything listening on port `80` or port `443`.

### Update the New Server

Assuming that you have a new brand server you should have now a shell as the `root` user, thus let's get it up to date with:

```
apt update && apt -y upgrade
```

### Create an Unprivileged User

We will not run the demo as `root`, because it's a best security practice to not run as `root`.

Check if the server already have an unprivileged user:

```
grep -irn :1000: /etc/passwd
```

Output example for a server that already has one:

```
28:debian:x:1000:1000:Cloud-init-user,,,:/home/debian:/bin/bash
```

If you don't get any output, then it means it doesn't exist yet, thus you can add a new unprivileged user with:

```
adduser debian
```
> **NOTE**: Type you password and reply to all other questions with just hitting `enter`.

Add the user to `sudo` with:

```
usermod -aG sudo debian
```

Switch to the `debian` user with:

```
su - debian
```

### The Public IP Address

Now grab the IP address for it in order to point a domain to it.

In the next step to setup the Domain DNS will need the public IP address for the server:

```txt
dig +short myip.opendns.com @resolver1.opendns.com
```

## DOMAIN DNS SETUP

Before starting the setup a domain needs to be set-ed to point at the Debian server.

For example if the `demo.example.com` is used, then each backend added will use it as their base domain.

So when adding a backend for the [python shapes api](https://github.com/approov/quickstart-python-flask_shapes-api) you give it the domain in the likes of `python-shapes.demo.example.com`, and for the [nodejs shapes api](https://github.com/approov/quickstart-nodejs-express_shapes-api) you maybe name it like `nodejs-shapes.demo.example.com`.

Go ahead and configure a domain at the DNS provider of your choice that points to the IP address from the previous step.

> **NOTE:** It's important that you add also a wild-card entry in the DNS record to point any sub-domain to the same IP.


## FIREWALL SETUP

Ensure that port `80` and `443` are open.


## DEBIAN SERVER SETUP

### Install Git

```
apt update && apt install -y git
```

### SSH Key

If the instance already has one, then just `cat ~/.ssh/id_rsa.pub` and add it to your Gitlab/Github account, otherwise create it first. This step is only necessary when you need to clone repositories via SSH.


### Instance Setup

#### Cloning this repository

Let's start by cloning this repository:

```
git clone https://github.com/approov/debian-traefik-setup.git && cd debian-traefik-setup
```

#### The Traefik environment file

Creating the `.env` file for Traefik:

```
sudo mkdir /opt/traefik && sudo cp ./traefik/.env.example /opt/traefik/.env
```

Customize the `env.` file with your values:

```
sudo nano /opt/traefik/.env
```

#### Run the setup

Traefik, Docker and Docker Compose will be installed and configured by running the bash script in the root of this repo:

```
./traefik-setup
```

The end of the output will look like this:

```
---> DOCKER COMPOSE VERSION <---
docker-compose version 1.25.5, build 8a1c60f6


---> GIT VERSION<---
git version 2.23.3


---> TRAEFIK installed at: /opt/traefik <---

From /opt/traefik folder you can ran any docker-compose command.

Some useful examples:

## Restart Traefik:
sudo docker-compose restart traefik

## Start Traefik:
sudo docker-compose up -d traefik

## Destroy Traefik:
sudo docker-compose down

## Tailing the Traefik logs in realtime:
sudo docker-compose logs --follow traefik

---> TRAEFIK is now listening for new docker containers <---
```

This setup script will let Traefik running and listening for incoming requests on port `80` and `443`, where requests for port `80` will be redirected to port `443`.


## TLS CERTIFICATES

Traefik uses LetsEncrypt to automatically generated and renew TLS certificates for all domains is listening on, and the will keep the public key unchanged, thus a mobile app can implement certificate pinning against the public key without the concern of having the pin changed at each renewal of the certificate.


## DEPLOY SERVER EXAMPLE

Let's see an example of deploying the Python Shapes API backend into an Debian server listening at `*.demo.example.com`.

#### Create the folder

```
mkdir -p ~/backend && cd ~/backend
```

#### Clone the repo

```
git clone https://github.com/approov/quickstart-python-flask_shapes-api && cd quickstart-python-flask_shapes-api
```

#### Create the .env file

```
cp .env.example .env
```

#### Edit the .env file

Replace the default domain with your own server domain:

```bash
PYTHON_FLASK_SHAPES_DOMAIN=python-shapes.demo.example.com
```

Replace the dummy Approov secret on it with the one for your Approov account:

```bash
# approov secret -get base64
APPROOV_BASE64_SECRET=your-secret-here
```

#### Start the Docker Stack

```
sudo docker-compose up -d
```

Now in your browser visit `python-shapes.demo.example.com` to check that the server is accepting requests.

#### Tail the logs

```
sudo docker-compose logs -f
```

## ADD A CONTAINER TO TRAEFIK

> **NOTE:** No need to follow this for the above Deploy Server Example. You only need to follow this part when your project doesn't have yet Traefik labels in the `docker-compose.yml` file.

Traefik inspects the labels in all running docker containers to know what ones it needs to proxy requests for.

So if your backend does not have yet support for Traefik in the `docker-compose.yml` file you can configure your service like this:

```yml
services:

    api:
        ...

        labels:
            - "traefik.enable=true"

            # The public domain name for your docker container
            - "traefik.frontend.rule=Host:api.demo.example.com"

            # Doesn't need to be exactly the same as the domain name.
            - "traefik.backend=api.demo.example.com"

            # The external docker network that Traefik uses to proxy request to containers.
            - "traefik.docker.network=traefik"

            # This is the internal container port, not the public one.
            - "traefik.port=5000"
...

networks:
    ...

    traefik:
        external: true

```

With this configuration all requests for `https://api.demo.example.com` will be proxy by Traefik to the docker container with the backend label `traefik.backend=api.demo.example.com` on the internal container network port `traefik.port=5000`.
