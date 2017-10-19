# `docker2singularity`

Are you developing Docker images and you would like to run them on an HPC cluster supporting [Singularity](http://singularity.lbl.gov)? Are you working on Mac or Windows with no easy access to a Linux machine? If the pull, import, and general commands to [work with docker images provided by Singularity](http://singularity.lbl.gov/docs-docker) natively do not fit your needs, `docker2singularity` is an alternative way to generate Singularity images. This particular branch is intended for Singularity 2.4, which builds a squashfs image. If you want a legacy version to build ext3 images, see the following other branches:

 - [v2.3](https://github.com/singularityware/docker2singularity/tree/v2.3): Version 2.3 of Singularity. The image format is ext3.
 - [v2.4](https://github.com/singularityware/docker2singularity/tree/v2.4): Version 2.4 of Singularity. The default image format is squashfs.

Intermediate versions built on [Docker Hub](https://hub.docker.com/r/singularityware/docker2singularity/tags/). A tag with prefix `v` corresponds to a release of the Singularity software, while the others are in reference to releases of Docker.

## Requirements

 - Docker (native Linux or Docker for Mac or Docker for Windows) - to create the Singularity image.
 - Singularity >= 2.1 - to run the Singularity image (**versions 2.0 and older are not supported!**). Note that if running a 2.4 image using earlier versions, not all (later developed) features may be available.

## Usage

No need to download anything from this repository! Simply type:

```
docker run \
-v /var/run/docker.sock:/var/run/docker.sock \
-v D:\host\path\where\to\output\singularity\image:/output \
--privileged -t --rm \
singularityware/docker2singularity:2.4 \
ubuntu:14.04
```

Replace `D:\host\path\where\to\output\singularity\image` with a path on the host filesystem where your Singularity image will be created. Replace `ubuntu:14.04` with the docker image name you wish to convert (it will be pulled from Docker Hub if it does not exist on your host system).

`docker2singularity` uses the Docker daemon located on the host system. It will access the Docker image cache from the host system avoiding having to redownload images that are already present locally.

## Tips for making Docker images compatible with Singularity

 - Define all environmental variables using the `ENV` instruction set. Do not rely on `.bashrc`, `.profile`, etc.
 - Define an `ENTRYPOINT` instruction set pointing to the command line interface to your pipeline
 - Do not define `CMD` - rely only on `ENTRYPOINT`
 - You can interactively test the software inside the container by overriding the `ENTRYPOINT`
   `docker run -i -t --entrypoint /bin/bash bids/example`
 - Do not rely on being able to write anywhere other than the home folder and `/scratch`. Make sure your container runs with the `--read-only --tmpfs /run --tmpfs /tmp` parameters (this emulates the read-only behavior of Singularity)
 - Don’t rely on having elevated user permissions
 - Don’t use the USER instruction set

## FAQ
### "client is newer than server" error
If you are getting the following error:
`docker: Error response from daemon: client is newer than server`

You need to use the `docker info` command to check your docker version and use it to grab the correct corresponding version of `docker2singularity`. For example:

     docker run \        
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v D:\host\path\where\to\output\singularity\image:/output \
     --privileged -t --rm \
     singularityware/docker2singularity:1.11 \            
     ubuntu:14.04

Currently only the 1.10, 1.11, 1.12, and 1.13  versions are supported. If you are using an older version of Docker you will need to upgrade.


### My cluster/HPC requires Singularity images to include specific mount points
If you are getting `WARNING: Non existant bind point (directory) in container: '/shared_fs'` or a similar error when running your Singularity image that means that your Singularity images require custom mount points. To make the error go away you can specify the mount points required by your system when creating the Singularity image:

     docker run \        
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v D:\host\path\where\to\output\singularity\image:/output \
     --privileged -t --rm \
     singularityware/docker2singularity \            
     -m "/shared_fs /custom_mountpoint2" \
     ubuntu:14.04

## Acknowledgements
This work is heavily based on the `docker2singularity` work done by [vsoch](https://github.com/vsoch) and [gmkurtzer](https://github.com/gmkurtzer). Hopefully most of the conversion code will be merged into Singularity in the future making this container even leaner!
