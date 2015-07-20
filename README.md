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
