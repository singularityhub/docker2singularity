# docker2singularity

Are you developing Docker images and you would like to run them on an HPC cluster supporting [Singularity](http://singularity.lbl.gov)? Are you working on Mac or Windows with no easy access to a Linux machine? docker2singularity is the simplest way to generate Singularity images.

## Requirements

 - Docker (native Linux or Docker for Mac or Docker for Windows).

## Usage

No need to download anything from this repository! Simply type:

     docker run \        
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v D:\host\path\where\to\ouptut\singularity\image:/output \
     --privileged -t --rm \
     filo/docker2singularity \            
     ubuntu:14.04

Replace `D:\host\path\where\to\ouptut\singularity\image` with a path in the host filesystem where your Singularity image will be created. Replace `ubuntu:14.04` with the docker image name you wish to convert (it will be pulled from Docker Hub if it does not exist on your host system).

docker2signularity uses the Docker deamon located on the host system. It will access Docker image cache from the host system avoiding having to redownload images that are already present locally.

## Tips for making Docker images compatible with Singular ty

 - Define all environmental variables using the ENV instruction set. Do not rely on .bashrc, .profile etc.
 - Define an ENTRYPOINT instruction set pointing to the command line interface to your pipeline
 - Do not define CMD - rely only on ENTRY OINT
 - You can interactively test the software inside container by overriding the entrypoint
 `docker run -i -t --entrypoint /bin/bash bids/example`
 - Do not rely on being able to write anywhere else than the home folder and /scratch. Make sure your container runs with the `--read-only --tmpfs /run --tmpfs /tmp` parameters (this emulates read only behavior of Singularity)
 - Don’t rely on having elevated user permissions
 - Don’t use the USER instruction set

## FAQ
### "client is newer than server" error
If you are getting the following error:
`docker: Error response from daemon: client is newer than server`

You need to use `docker info` command to check your docker version and use it to grab the correct corresponding version of docker2singularity. For example:

     docker run \        
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v D:\host\path\where\to\ouptut\singularity\image:/output \
     --privileged -t --rm \
     filo/docker2singularity:1.11 \            
     ubuntu:14.04

Currently only 1.11 and 1.12 versions are supported. If you are using older version of Docker you will need to upgrade.

## Acknowledgements
This work is heavily based on the docker2singularity work done by [vsoch](https://github.com/vsoch) and [gmkurtzer](https://github.com/gmkurtzer). Hopefully most of the conversion code will be merged into Singularity in the future making this container even leaner!
