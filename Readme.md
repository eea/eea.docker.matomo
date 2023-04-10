
# MATOMO for rancher 1.6, based on bitnami/matomo

Based on 
https://github.com/bitnami/containers/tree/6de10e059df92fcf0c82a69db03ce0ed95f8339b/bitnami/matomo/4/debian-11


## How to upgrade


Check what was updated between current version from https://github.com/bitnami/containers/tree/main/bitnami/matomo/4/debian-11 and https://github.com/bitnami/containers/tree/6de10e059df92fcf0c82a69db03ce0ed95f8339b/bitnami/matomo/4/debian-11

### Small/version differences

No code updates, only version updates

1. Update the code with the small updates ( do not update any debian OS related version)
2. Fix the commit id in the `Readme.md` file

### Code upgrades

This repo was made from the bitnami repo, with the following differeces:

1. Added our scripts 

2. Update `./rootfs/opt/bitnami/scripts/matomo/entrypoint.sh`

    a. Update `if` line to support `run_` docker commands
    
    b. add `/use_matomo_in_rancher.sh`


3. In Dockerfile

    a. Replace `bullseye` with `buster`

    b. Replace `debian-11` with `debian-10`

    c. Update `RUN install_packages` from last bitnami/matomo debian 10 code: https://github.com/bitnami/containers/tree/54cbc81cf48e126af9063c1e900dcabe00e3770f/bitnami/matomo/4/debian-10
    
    d. At the end, add the 2 `COPY` commands


           COPY run_* /usr/bin/
           COPY use_matomo_in_rancher.sh /

4. Update `Readme.md` with the commit id
