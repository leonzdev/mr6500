# SSH
Add SSH access, and SCP, SFTP.

MR6500 does not have sshd installed in its stock image. We need to build and install our own copy on to it. 

CPU architecture is `armv7l`. To avoid the complexity of dynamic linking (libc, etc), we can choose a static linked build.

## Static linked build
Pros: no dependency, everything is in the binary.
Cons: large file size.

Steps
1. Get the static linked binaries
Follow instructions from https://github.com/binary-manu/static-cross-openssh, download prebuilt binaries from [CircleCI artifacts](https://app.circleci.com/pipelines/github/binary-manu/static-cross-openssh/15/workflows/97da4e36-5c80-4b74-8f26-c5528309f6c2)

1. Extract and host the files
1. Download from the telnet root shell using `wget`

   Need the following files: `sshd`, `sftp-server`, `sftp`, `scp`, `ssh-keygen`

   The artifacts from `static-cross-openssh` use `/opt/openssh` as its base directory. Put files in `/opt/openssh` to avoid troubles
    ```bash
    bash-3.2# ls /opt/openssh/
    bin      etc      libexec  var
    bash-3.2# ls -l /opt/openssh/bin
    total 5052
    -rwxr-xr-x    1 root     root       5172712 Jan  7  1980 sshd
    bash-3.2# ls -l /opt/openssh/etc
    total 28
    -rw-------    1 root     root           505 Jan  6 01:56 ssh_host_ecdsa_key
    -rw-r--r--    1 root     root           175 Jan  6 01:56 ssh_host_ecdsa_key.pub
    -rw-------    1 root     root           399 Jan  6 01:56 ssh_host_ed25519_key
    -rw-r--r--    1 root     root            95 Jan  6 01:56 ssh_host_ed25519_key.pub
    -rw-------    1 root     root          2602 Jan  6 01:56 ssh_host_rsa_key
    -rw-r--r--    1 root     root           567 Jan  6 01:56 ssh_host_rsa_key.pub
    -rw-r--r--    1 root     root           345 Jan  6 03:40 sshd_config
    bash-3.2# ls -l /opt/openssh/libexec
    total 280
    -rwxr-xr-x    1 root     root        284092 Jan  6 03:38 sftp-server
    bash-3.2# ls -l /opt/openssh/var/empty/
    total 0
    ```

1. Generate host keys with `ssh-keygen -A` command. Delete `ssh-keygen` after generating keys to save space

1. Create `sshd_config`
    ```bash
    bash-3.2# cat /opt/openssh/etc/sshd_config 
    PermitRootLogin yes
    ChallengeResponseAuthentication yes 
    #UsePAM yes
    
    X11Forwarding yes
    X11DisplayOffset 20 
    X11UseLocalhost no 
    PrintMotd no
    
    AcceptEnv LANG LC_*
    
    HostKey /opt/openssh/etc/ssh_host_ecdsa_key
    HostKey /opt/openssh/etc/ssh_host_rsa_key
    HostKey /opt/openssh/etc/ssh_host_ed25519_key
    Subsystem	sftp	/opt/openssh/libexec/sftp-server
    ```

1. Upload pub key to authorized_keys
   1. Create directory `/home/root/.ssh`
   1. Create file `/home/root/.ssh/authorized_keys`
   1. Add pub keys to the `authorized_keys` file
   1. Change permissions to 644
    ```bash
    bash-3.2# ls -l /home/root/.ssh
    total 4
    -rw-r--r--    1 root     root           608 Jan  6 02:10 authorized_keys
    ```
