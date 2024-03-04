# SSH
Add SSH access, and SCP, SFTP.

MR6500 does not have sshd installed in its stock image. We need to build and install our own copy on to it. 

CPU architecture is `armv7l`. To avoid the complexity of dynamic linking (libc, etc), we can choose a static linked build.

## Static linked built
Pros: no dependency, everything is in the binary.
Cons: large file size.

Steps
* Get the static linked binaries
Follow instructions from https://github.com/binary-manu/static-cross-openssh, download prebuilt binaries from [CircleCI artifacts](https://app.circleci.com/pipelines/github/binary-manu/static-cross-openssh/15/workflows/97da4e36-5c80-4b74-8f26-c5528309f6c2)

* Extract and host the files
