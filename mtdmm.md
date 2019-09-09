# Multiple TeamDrive Mounting Method

#### Introduction

You got multiple rclone teamdrive remotes that you want mounting on your box? This is a method to get them mounted in the cleanest way possible. I'm not an expert. But some super cool guy in a discord took the time to talk me through it so I'm sharing the process, in case anyone else had the same trouble I did mounting their teamdrives.

Rather than making multiple `.service` files for each mount, it's possible to make a template service file and feed it a config file. This method makes the process a lot more user friendly and requires only a 3 line `.config` file for each remote we want mounted.

#### Assumptions

This document assumes that the remotes you want to mount have already been setup with `rclone config` and you are able to get an output from `rclone lsd remotename:`. Where I use `remotename` this is the name of the remote you set up in rclone. Use some common sense. This is **NOT** a copy & paste guide. I did this on an Ubuntu box, with the latest version of rclone. In these examples I have specified the user:group as `youruser` and `yourgroup` in a few places. If you're using a different user and group, make sure to edit those to suit the setup.

#### Service File Templates

To keep things tidy we're going to use a templated service file that refrences a `.config` file. Its a much tidier way of doing it. The service files are going to sit in `/etc/systemd/system/`. The `.config` files will live in `/opt/teamdrives`.

#### `teamdrive@.service`

```sh
sudo nano /etc/systemd/system/teamdrive@.service
``` 
Create the new file in the location we want it.  Use `sudo` to get over any permission snags. Create the service file as below. 

```sh
[Unit]
Description=Rclone VFS
# Depend on network
After=network-online.target
# Check directories

[Service]
Type=notify

User=youruser
Group=yourgroup

# Mount command - You can add any extra flags you want here
EnvironmentFile=/opt/teamdrives/%i.conf
ExecStartPre=-/usr/bin/sudo /bin/mkdir -p $DESTINATION_DIR
ExecStartPre=-/usr/bin/sudo /bin/chmod -R 775 $DESTINATION_DIR
ExecStartPre=-/usr/bin/sudo /bin/chown -R youruser:yourgroup $DESTINATION_DIR
ExecStart=/usr/bin/rclone mount \
  --config=/home/youruser/.config/rclone/rclone.conf \
  --allow-other \
  --fast-list \
  --rc \
  --rc-addr=localhost:${RCLONE_RC_PORT} \
  --drive-skip-gdocs \
  --vfs-read-chunk-size=64M \
  --vfs-read-chunk-size-limit=2048M \
  --buffer-size=64M \
  --max-read-ahead=256M \
  --poll-interval=1m \
  --dir-cache-time=72h \
  --timeout=10m \
  --transfers=16 \
  --checkers=8 \
  --drive-chunk-size=64M \
  --umask=002 \
  --syslog \
  -vv \
 $SOURCE_REMOTE $DESTINATION_DIR

# Unmount on stop
ExecStop=/bin/umount -l $DESTINATION_DIR
Restart=on-abort
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=default.target
```
`ctrl+x` then `y` and `enter` to exit and save.

#### `teamdrive_primer@.service`

`sudo nano /etc/systemd/system/teamdrive_primer@.service` to create the new file in the location we want it. Use `sudo` to get over any permission snags. Then create service primer as below.

```
[Unit]
Description=%i Primer - Service
Requires=teamdrive@%i.service
After=teamdrive@%i.service

[Service]
EnvironmentFile=/opt/teamdrives/%i.conf
User=youruser
Group=yourgroup
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/rclone \
  --config /home/youruser/.config/rclone/rclone.conf \
  --timeout=1h \
  -vvv \
  --rc-addr=localhost:${RCLONE_RC_PORT} \
  rc vfs/refresh

[Install]
WantedBy=default.target
```
`ctrl+x` then `y` and `enter` to exit and save.


#### `teamdrive_primer@.timer`

`sudo nano /etc/systemd/system/teamdrive_primer@.timer` To create the new file in the location we want it. Use `sudo` to get over any permission snags. Then paste in the following.

```
[Unit]
Description=%i Primer - Timer

[Timer]
OnUnitInactiveSec=167h

[Install]
WantedBy=timers.target
[Service]
User=youruser
Group=yourgroup
```
`ctrl+x` then `y` and `enter` to exit and save.

#### Enviroment Files
Once the `.service` and `.timer` files are created, and safe inside `/systemd/system/` we need to create an enviroment file for each of the remotes we want mounting. These will be called `remotename.conf` and will sit in the `/opt/teamdrives/` directory. The `teamdrive_primer@.service` file will make sure that the mountpoint is present before the remote tries to mount, so theres no need to make the mountpoints before hand, just as long as it's defined in the `remotename,conf`. It's also advisable to make sure that each of the remotes runs on a different `RCLONE_RC_PORT`, just increasing each time by 1 is fine, just make sure the port isn't in use by anything else. If you have 5 teamdrives you wanted to mount, you'd need to make 5 of these files, named the same as the remote. It's also a good idea to keep a list of the enviroment files you've made. 

`sudo mkdir /opt/teamdrives/`

##### `remotename.conf`
```bash
RCLONE_RC_PORT=5576
SOURCE_REMOTE=remotename:
DESTINATION_DIR=/mnt/teamdrives/mountpoint/
```
#### Enabling the Mounts As Services
Now we need to enable these new service files we have just created and start them. We need to do this for each remote we have created enviroment files for.

```bash
sudo systemctl enable teamdrive@remotename.service
sudo systemctl enable teamdrive_primer@remotename.service
sudo systemctl enable teamdrive_primer@remotename.timer

sudo systemctl start teamdrive@remotename.service
sudo systemctl start teamdrive_primer@remotename.service
sudo systemctl start teamdrive_primer@remotename.timer
```
Once the mounts have been enabled, they should start at boot and the files be available at the `DESTINATION_DIR` specified in the `remotename.conf`.

You're Done!
