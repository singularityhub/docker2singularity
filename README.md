# docker2singularity

Are you developing Docker images and you would like to run them on an HPC cluster supporting [Singularity](http://singularity.lbl.gov)? Are you working on Mac or Windows with no easy access to a Linux machine? docker2singularity is the simplest way to generate Singularity images.

## Requirements

 - Docker (native Linux or Docker for Mac of Docker for Windows).

## Usage

No need to download anything from this repository! Simply type:

    docker run \
      -v /var/run/docker.sock:/var/run/docker.sock 
      -v D:\host\path\where\to\ouptut\singularity\image:/output 
      --privileged -t --rm 
      filo/docker2singularity 
      ubuntu:14.04
      
Replace `D:\host\path\where\to\ouptut\singularity\image` with a path in the host filesystem where your Singularity image will be created. Replace `ubuntu:14.04` with the docker image name you wish to convert (it will be pulled from Docker Hub if it does not exist on your host system).

docker2signularity uses the Docker deamon located on the host system. It will access Docker image cache from the host system avoiding having to redownload images that are already present locally.

## Acknowledgements
This work is heavily based on the docker2singularity work done by [vsoch](https://github.com/vsoch) and [gmkurtzer](https://github.com/gmkurtzer). Hopefully most of the conversion code will be merged into Singularity in the future making this container even leaner!
