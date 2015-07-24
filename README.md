# sensorian-imagebuilder
Build scripts used for configuring a Raspbian OS image to work with Sensorian in C, Python, Scratch, and Node-RED

Usage
-----

1. Create the ~/install\_from\_here directory on the Raspberry Pi.
2. Copy all files from this repository into that directory.
3. Open in a text editor, such as nano, build\_rpi.sh and read
`# Configure default gateway and nameserver - Change to suit your network`.
Modify those lines with your default gateway and nameserver. Read `#Configure apt-caching proxy - Remove this line if you have none.`
and modify the program to use your network's apt-caching proxy, if it exists.
 Save the file and exit the editor.
4. Make the file executable. chmod +x build\_rpi.sh
5. Run the build script. ./build\_rpi.sh

Pre-Built Images
----------------

Download pre-built images built with these scripts for
[Raspberry Pi 1](https://drive.google.com/file/d/0B7xb\_sonUfKtQy1CZ0Z4LTNVTEU/view?usp=sharing)
and [Raspberry Pi 2](https://drive.google.com/file/d/0B7xb_sonUfKtekJWclhLa1JocXM/view?usp=sharing)

Advisories
----------

* By default, the built image uses an apt-caching proxy at `192.168.137.3:3128`.
If you do not have this on your network and want to download packages directly, remove
`/etc/apt/apt.conf` by running `sudo rm /etc/apt/apt.conf`. This should resolve any
apt-get errors.

* The default password for the user `pi` is `raspberry`. If working in an untrusted
environment it is recommended that you change it by running `sudo passwd pi`.

* The default ssh host key is not unique and it is recommended that you change it
if working in an untrusted environment. To do so run `sudo rm /etc/ssh/ssh_host_*`.
Then run `sudo dpkg-reconfigure openssh-server`. 
