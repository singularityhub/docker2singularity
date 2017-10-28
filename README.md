# `docker2singularity`

Are you developing Docker images and you would like to run them on an HPC cluster supporting [Singularity](http://singularity.lbl.gov)? Are you working on Mac or Windows with no easy access to a Linux machine? If the pull, import, and general commands to [work with docker images provided by Singularity](http://singularity.lbl.gov/docs-docker) natively do not fit your needs, `docker2singularity` is an alternative way to generate Singularity images. This particular branch is intended for Singularity 2.4, which gives you a selection of image formats to build.

## Usage

```
docker run docker2singularity
USAGE: docker2singularity [-m "/mount_point1 /mount_point2"] [options] docker_image_name
OPTIONS:

          Image Format
              -f: build development sandbox (folder)
              -w: non-production writable image (ext3)         

              Default is squashfs (recommended)

```

### Options

**Image Format**

 - `squashfs` (no arguments specified) gives you a squashfs (`*.simg`) image. This is a compressed, reliable, and read only format that is recommended for production images.
 - `sandbox` (`-f`) builds your image into a sandbox **folder**. This is ideal for development, as it will produce a working image in a folder on your system.
 - `ext3` (`-w`) builds an older format (ext3) image (`*.img`). This format is not recommended for production images as we have observed degradation of the images over time, and they tend to be upwards of 1.5x to 2x the size of squashfs.

Note that you are able to convert easily from a folder or ext3 image using Singularity 2.4. If your choice is to develop, making changes, and then finalize, this approach is **not** recommended - your changes are not recorded and thus the image not reproducible.

**Mount Points**

 - `-m` specify one or more mount points to create in the image.

**Image Name**

The last argument (without a letter) is the name of the docker image, as you would specify to run with Docker (e.g., `docker run ubuntu:latest`)


## Legacy

If you want a legacy version, see the following other branches:

 - [v2.3](https://github.com/singularityware/docker2singularity/tree/v2.3): Version 2.3 of Singularity. The image format is ext3.
 - [v2.4](https://github.com/singularityware/docker2singularity/tree/v2.4): Version 2.4 of Singularity. The default image format is squashfs.

Intermediate versions built on [Docker Hub](https://hub.docker.com/r/singularityware/docker2singularity/tags/). A tag with prefix `v` corresponds to a release of the Singularity software, while the others are in reference to releases of Docker.

## Requirements

 - Docker (native Linux or Docker for Mac or Docker for Windows) - to create the Singularity image.
 - Singularity >= 2.1 - to run the Singularity image (**versions 2.0 and older are not supported!**). Note that if running a 2.4 image using earlier versions, not all (later developed) features may be available.

## Examples

## Build a Squashfs Image
Squashfs is the recommended image type, it is compressed and less prone to degradation over time. You don't need to specify anything special to create it:

```
docker run -v /var/run/docker.sock:/var/run/docker.sock \
-v /host/path/change/me:/output \
--privileged -t --rm \
singularityware/docker2singularity:2.4
ubuntu:14.04

Image Format: squashfs
Inspected Size: 188 MB

(1/10) Creating a build sandbox...
(2/10) Exporting filesystem...
(3/10) Creating labels...
(4/10) Adding run script...
(5/10) Setting ENV variables...
(6/10) Adding mount points...
(7/10) Fixing permissions...
(8/10) Stopping and removing the container...
(9/10) Building squashfs container...
Building image from sandbox: /tmp/ubuntu_14.04-2017-09-13-3e51deeadc7b.build
Building Singularity image...
Singularity container built: /tmp/ubuntu_14.04-2017-09-13-3e51deeadc7b.simg
Cleaning up...
(10/10) Moving the image to the output folder...
     62,591,007 100%  340.92MB/s    0:00:00 (xfr#1, to-chk=0/1)
Final Size: 60MB
```

Notice how the image went from 188MB to 60MB? This reduction is even more impressive when we are dealing with
very large images (e.g., ~3600 down to ~1800). A few notes on the inputs shown above that you should edit:

 - `/host/path/change/me`: the path you want to have the final image reside. If you are on windows this might look like `D:\host\path\where\to\output\singularity\image`.
 -`ubuntu:14.04`: the docker image name you wish to convert (it will be pulled from Docker Hub if it does not exist on your host system).

`docker2singularity` uses the Docker daemon located on the host system. It will access the Docker image cache from the host system avoiding having to redownload images that are already present locally.

If you ever need to make changes, you can easily export the squashfs image into either a sandbox folder or ext3 (legacy) image, both of which have writable.

```
sudo singularity build --sandbox sandbox/ production.simg
sudo singularity build --writable ext3.img production.simg
```

## Inspect Your Image
New with `docker2singularity` 2.4, the labels for the container are available with `inspect`:

```
 singularity inspect ubuntu_14.04-2017-09-13-3e51deeadc7b.simg 
{
    "org.label-schema.singularity.build": "squashfs",
    "org.label-schema.docker.version": "17.06.2-ce",
    "org.label-schema.schema-version": "1.0",
    "org.label-schema.singularity.build-type": "docker2singularity",
    "org.label-schema.docker.id": "sha256:dea1945146b96542e6e20642830c78df702d524a113605a906397db1db022703",
    "org.label-schema.build-date": "2017-10-28-17:19:18",
    "org.label-schema.singularity.version": "2.4-dist",
    "org.label-schema.docker.created": "2017-09-13"
}
```

as is the runscript and environment

```
singularity inspect --json -e -r ubuntu_14.04-2017-09-13-3e51deeadc7b.simg 
{
    "data": {
        "attributes": {
            "environment": "# Custom environment shell code should follow\n\n",
            "runscript": "#!/bin/sh\n/bin/bash $@\n"
        },
        "type": "container"
    }
}

```

## Build a Sandbox Image
A sandbox image is a folder that is ideal for development. You can view it on your desktop, cd inside and browse, and it works like a Singularity image. To create a sandbox, specify the `-f` flag:

```
docker run -v /var/run/docker.sock:/var/run/docker.sock \
-v /host/path/change/me:/output \
--privileged -t --rm \
singularityware/docker2singularity:2.4 \
-f \
ubuntu:14.04
```
Importantly, you can use `--writable`, and if needed, you can convert a sandbox folder into a production image:

```
sudo singularity build sandbox/ production.simg
```

## Build a Legacy (ext3) Image
You can build a legacy ext3 image (with `--writable`) with the `-w` flag. This is an older image format that is more prone to degradation over time, and (building) may not be supported for future versions of the software.

```
docker run -v /var/run/docker.sock:/var/run/docker.sock \
-v /host/path/change/me:/output \
--privileged -t --rm \
singularityware/docker2singularity:2.4 \
-w \
ubuntu:14.04
```
You can also use `--writable` and convert an ext3 image into a production image:

```
sudo singularity build ext3.img production.simg
```


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
