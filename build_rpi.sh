#User parameters to modify based on your configuration
USER_DEFAULT_GW="192.168.137.1"
USER_NAMESERVER="10.120.200.63"
USER_APT_SERVER="http://mirrordirector.raspbian.org/raspbian/"

#Constants
checksum_sha512_bcm2835="d1f006614cb1f95e1a6c33081e3a932984d54b00f535d6b7ccde774ff59ac40a858c5f7822e6f5103d207cacf8ee0a8325c2d36673607b54b4fdcdb090209c25"
py_spidev_commit="4f3f1dea5d4828c387e8822aa6bf3920a4119c64"

# Configure default gateway and nameserver - Change to suit your network
sudo route add default gw "$USER_DEFAULT_GW"
sudo sh -c 'echo "nameserver 10.120.200.63" > /etc/resolv.conf'

#Configure apt-caching proxy - Remove this line if you have none.
sudo sh -c 'echo "Acquire::http::Proxy \"http://192.168.137.3:3128\";" > /etc/apt/apt.conf'

#Download BCM2835 library
echo "Downloading bcm2835"
wget www.airspayce.com/mikem/bcm2835/bcm2835-1.44.tar.gz -O bcm2835-1.44.tar.gz || { echo "Failed to download bcm2835 library" && exit; }

#Verify the SHA512 Hash
bcm2835_sha512=$(sha512sum bcm2835-1.44.tar.gz | head -c 128)

if [ "$bcm2835_sha512"=="$checksum_sha512_bcm2835" ]
	then
		echo "Checksum verification PASSED"
	else
		echo "Checksum verification FAILED. Something went wrong while downloading bcm2835-1.44.tar.gz"
		echo "Exiting..."
		exit
fi

echo "Extracting the downloaded file"
tar -zxvf bcm2835-1.44.tar.gz

#Compile
echo "Building BCM2835 library"
cd bcm2835-1.44
./configure
sudo make check
sudo make install

#create libbcm2835.so
cc -shared src/bcm2835.o -o src/libbcm2835.so
sudo cp -p src/libbcm2835.so /usr/lib/

#Switch to parent directory
cd ..

#Setup apt sources with only wheezy repo, for now.
#mycmd='echo "deb $USER_APT_SERVER wheezy main contrib non-free rpi" > /etc/apt/sources.list'
sudo sh -c 'echo "deb http://mirrordirector.raspbian.org/raspbian/ wheezy main contrib non-free rpi" > /etc/apt/sources.list'
sudo apt-get update || { echo "Failed to apt-get update" && exit; }

#Install git
sudo apt-get -y install git || { echo "Failed to apt-get install git" && exit; }

#Install python-dev
sudo apt-get -y install python-dev || { echo "Failed to install python-dev" && exit; }

#Clone the py-spidev repository
#git clone https://github.com/doceme/py-spidev || { echo "Failed to clone py-spidev git repo" && exit; }

#cd py-spidev/

##Switch to a commit known to work
#git checkout "$py_spidev_commit"

##Verify the repository
#head_commit=$(git rev-parse --verify HEAD)

#if [ "$head_commit"=="$py_spidev_commit" ]
	#then
		#echo "Commit checksum verification PASSED"
	#else
		#echo "Commit checksum verification FAILED. Something is wrong with the py-spidev repository."
		#echo "Exiting..."
		#exit
#fi

##Install py-spidev
#sudo python setup.py install

#cd ..

#Install other packages from the Raspbian Repository
sudo apt-get -y install minicom || { echo "Failed to install minicom" && exit; }
sudo apt-get -y install i2c-tools || { echo "Failed to install i2c-tools" && exit; }
sudo apt-get -y install libi2c-dev || { echo "Failed to install libi2c-dev" && exit; }
sudo apt-get -y install python-smbus || { echo  "Failed to install python-smbus" && exit; }
sudo apt-get -y install python-numpy || { echo "Failed to install python-numpy" && exit; } 
sudo apt-get -y install python-imaging || { echo "Failed to install python-imaging" && exit; }
sudo apt-get -y install python-pkg-resources || { echo "Failed to install python-pkg-resources" && exit; }
sudo apt-get -y install python-pip || { echo "Failed to install python-pip" && exit; }
sudo apt-get -y install python-wtforms || { echo "Failed to install python-wtforms" && exit; }
sudo apt-get -y install sqlite3 || { echo "Failed to install sqlite3" && exit; }
sudo apt-get -y install apache2 || { echo "Failed to install apache2" && exit; }
sudo apt-get -y install libapache2-mod-wsgi || { echo "Failed to install libapache2-mod-wsgi" && exit; }

#Use Peep to install PyPy packages as it is cryptographically secure
# https://pypi.python.org/pypi/peep
sudo python peep.py install -r python_requirements.txt || { echo "peep install failed" && exit; }

#Copy helper programs needed for Node-RED Sensorian Interface
cd helper-programs

#Build LED_ON
cd LED_ON
make
#chown and set SETUID bit
sudo chown root LED_ON
sudo chmod u+s LED_ON
#Install
sudo cp -p LED_ON /usr/bin/
cd ..

#Build LED_OFF
cd LED_OFF
make
#chown and set SETUID bit
sudo chown root LED_OFF
sudo chmod u+s LED_OFF
#Install
sudo cp -p LED_OFF /usr/bin/
cd ..

#Install ReadAltitude.py , ReadPressure.py , ReadTemperature.py , ReadAmbientLight.py
chmod +x ReadAltitude.py
sudo cp -p ReadAltitude.py /usr/bin/SensorianReadAltitude.py
chmod +x ReadPressure.py
sudo cp -p ReadPressure.py /usr/bin/SensorianReadPressure.py
chmod +x ReadTemperature.py
sudo cp -p ReadTemperature.py /usr/bin/SensorianReadTemperature.py
chmod +x ReadAmbientLight.py
sudo cp -p ReadAmbientLight.py /usr/bin/SensorianReadAmbientLight.py

#Leave helper-programs directory
cd ..

#Create .sensorian hidden directory and mmap files for IPC
mkdir ~/.sensorian
head /dev/zero -c 2 > ~/.sensorian/mmap_altitude
head /dev/zero -c 2 > ~/.sensorian/mmap_ambientlight
head /dev/zero -c 2 > ~/.sensorian/mmap_pressure
head /dev/zero -c 2 > ~/.sensorian/mmap_temperature

#nodejs and npm need to be installed from the Raspbian Jessie repo. So let's setup apt-pinning.
sudo sh -c 'echo "deb http://mirrordirector.raspbian.org/raspbian/ jessie main contrib non-free rpi" >> /etc/apt/sources.list'
sudo sh -c 'echo "Package: *" > /etc/apt/preferences'
sudo sh -c 'echo "Pin: release a=wheezy" >> /etc/apt/preferences'
sudo sh -c 'echo "Pin-Priority: 700" >> /etc/apt/preferences'
sudo sh -c 'echo "Package: *" >> /etc/apt/preferences'
sudo sh -c 'echo "Pin: release a=jessie" >> /etc/apt/preferences'
sudo sh -c 'echo "Pin-Priority: 650" >> /etc/apt/preferences'
sudo apt-get update || { echo "Wheezy and Jessie apt-get update failed" && exit; }

#Download and install Node.js for Raspberry Pi from Jessie repo
sudo apt-get -y -t jessie install nodejs || { echo "Failed to install nodejs" && exit; }

#soft-link /usr/bin/node to /usr/bin/nodejs
sudo ln -s -T /usr/bin/nodejs /usr/bin/node

#Install Node Package Manager (NPM)
sudo apt-get -y -t jessie install npm || { echo "Failed to install npm" && exit; }

#Download and install Node-RED
sudo npm install -g --unsafe-perm node-red || { echo "Failed to install node-RED" && exit; }

#Install Sensorian plugins into Node-RED nodes directory
sudo cp -p -r nodered-plugins/* /usr/local/lib/node_modules/node-red/nodes/

#Create and populate ~/Sensorian/
tar -xvf sensorian_directory.tar.gz -C ~
chmod +x ~/Sensorian/Handler_NodeRED/run_servers.sh

#Compile all needed .so files
#Enter PythonSharedObjectSrc
cd PythonSharedObjectSrc

cd MPL3115A2
make
cd ..

cd FXOS8700CQR1
make
cd ..

cd CAP1203
make
cd ..

#Leave PythonSharedObjectSrc
cd ..

#Enter i2c-devices-interface
cd i2c-devices-interface

make

#Leave i2c-devices-interface
cd ..

#Copy the files into where they are needed
cp -p PythonSharedObjectSrc/MPL3115A2/libMPL.so ~/Sensorian/Drivers_Python/MPL3115A2/libMPL.so
cp -p PythonSharedObjectSrc/MPL3115A2/libMPL.so ~/Sensorian/Apps_Python/P03-Barometer/libMPL.so
cp -p PythonSharedObjectSrc/MPL3115A2/libMPL.so ~/Sensorian/Apps_Python/P06-FlaskSensors/Dashboard/libMPL.so

cp -p PythonSharedObjectSrc/FXOS8700CQR1/libFXO.so ~/Sensorian/Drivers_Python/FXOS8700CQR1/libFXO.so
cp -p PythonSharedObjectSrc/FXOS8700CQR1/libFXO.so ~/Sensorian/Apps_Python/P07-Dynamic\ Photo\ Frame/libFXO.so

cp -p PythonSharedObjectSrc/CAP1203/libCAP.so ~/Sensorian/Drivers_Python/CAP1203/libCAP.so
cp -p PythonSharedObjectSrc/CAP1203/libCAP.so ~/Sensorian/Apps_Python/P04-CapacitiveTouch/libCAP.so

cp -p i2c-devices-interface/libsensorian.so ~/Sensorian/Handler_Scratch/libsensorian.so
cp -p i2c-devices-interface/libsensorian.so ~/Sensorian/Handler_NodeRED/libsensorian.so

#Scratch is already configured in Raspbian-Wheezy-2015-05-05 with MESH enabled so nothing to do here.

#Enable SPI and I2C interfaces
sudo sed -i 's/#dtparam=i2c_arm=on/dtparam=i2c_arm=on/g' /boot/config.txt
sudo sed -i 's/#dtparam=spi=on/dtparam=spi=on/g' /boot/config.txt
sudo sh -c 'echo i2c-dev >> /etc/modules'

#Get a reference to the current directory
builddir=$(pwd)

#Build the IP demo
cd ~/Sensorian/Apps_C/P05-IP
make

#Switch back to the build directory
cd $builddir

#Add the IP demo to the crontab
echo "@reboot /home/pi/Sensorian/Apps_C/P05-IP/IP" > mycron
sudo crontab mycron

#At this point, everything should be installed.
echo "Sensorian should now be configured. Reboot and enjoy!"
