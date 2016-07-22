#Constants
checksum_sha512_bcm2835="94887f04616c3bea4e2cb5d265068208958777feffb88ccbb33a03e9d8b8a7f06f06d9744dae45cd33d24f17a29ae1fff437a23521084667a57de8208855105c"

#Download BCM2835 library
echo "Downloading bcm2835"
wget http://www.airspayce.com/mikem/bcm2835/bcm2835-1.50.tar.gz -O bcm2835-1.50.tar.gz || { echo "Failed to download bcm2835 library" && exit; }

#Verify the SHA512 Hash
bcm2835_sha512=$(sha512sum bcm2835-1.50.tar.gz | head -c 128)

if [ "$bcm2835_sha512"=="$checksum_sha512_bcm2835" ]
	then
		echo "Checksum verification PASSED"
	else
		echo "Checksum verification FAILED. Something went wrong while downloading bcm2835-1.44.tar.gz"
		echo "Exiting..."
		exit
fi

echo "Extracting the BCM2835 library"
tar -zxf bcm2835-1.50.tar.gz

#Compile
echo "Building BCM2835 library"
cd bcm2835-1.50
./configure
sudo make check
sudo make install

#create libbcm2835.so
cc -shared src/bcm2835.o -o src/libbcm2835.so
sudo cp -p src/libbcm2835.so /usr/lib/

#Switch to parent directory
cd ..

sudo apt-get update || { echo "Failed to apt-get update" && exit; }

#Install python-dev
sudo apt-get -y install python-dev || { echo "Failed to install python-dev" && exit; }

#Install other packages from the Raspbian Repository
sudo apt-get -y install i2c-tools || { echo "Failed to install i2c-tools" && exit; }
sudo apt-get -y install libi2c-dev || { echo "Failed to install libi2c-dev" && exit; }
sudo apt-get -y install python-smbus || { echo  "Failed to install python-smbus" && exit; }
sudo apt-get -y install python-pkg-resources || { echo "Failed to install python-pkg-resources" && exit; }
sudo apt-get -y install python-pip || { echo "Failed to install python-pip" && exit; }

#Uninstall Python Imaging Library because it leaks and doesn't play well with Pillow
sudo apt-get -y purge python-pil || { echo "Failed to unins python-pil" && exit; }
sudo apt-get -y purge python3-pil || { echo "Failed to uninstall python3-pil" && exit; }

#Replace PIL with Pillow==2.9.0 which doesn't leak and doesn't weird-out like >=3.0.0
sudo pip install Pillow==2.9.0

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

#Install Sensorian plugins into Node-RED nodes directory
mkdir -p ~/.node-red/nodes
sudo cp -p -r nodered-plugins/* /usr/lib/node_modules/node-red/nodes

#Get a reference to the current directory
builddir=$(pwd)

#Clone the latest version of the Sensorian Firmware repository Fixes branch into Sensorian
git clone https://github.com/sensorian/sensorian-firmware.git -b Fixes --single-branch ~/Sensorian
chmod +x ~/Sensorian/Handler_NodeRED/run_servers.sh

#Compile all needed .so files
#Enter PythonSharedObjectSrc
cd ~/Sensorian/Drivers_Python/PythonSharedObjectSrc

cd MPL3115A2
make
cd ..

cd FXOS8700CQR1
make
cd ..

cd CAP1203
make
cd ..

#Enter i2c-devices-interface
cd ~/Sensorian/Handler_Scratch/utilities/i2c-devices-interface
make

#Return to Sensorian directory
cd ~/Sensorian

#Copy the files into where they are needed
cp -p Drivers_Python/PythonSharedObjectSrc/MPL3115A2/libMPL.so Apps_Python/P03-Barometer/libMPL.so
cp -p Drivers_Python/PythonSharedObjectSrc/MPL3115A2/libMPL.so Apps_Python/P06-FlaskSensors/dashboard/libMPL.so

cp -p Drivers_Python/PythonSharedObjectSrc/FXOS8700CQR1/libFXO.so Apps_Python/P07-Dynamic\ Photo\ Frame/libFXO.so

cp -p Drivers_Python/PythonSharedObjectSrc/CAP1203/libCAP.so Apps_Python/P04-CapacitiveTouch/libCAP.so

cp -p Handler_Scratch/utilities/i2c-devices-interface/libsensorian.so Handler_Scratch/libsensorian.so
cp -p Handler_Scratch/utilities/i2c-devices-interface/libsensorian.so Handler_NodeRED/libsensorian.so

#Enable SPI and I2C interfaces
sudo sed -i 's/#dtparam=i2c_arm=on/dtparam=i2c_arm=on/g' /boot/config.txt
sudo sed -i 's/#dtparam=spi=on/dtparam=spi=on/g' /boot/config.txt
sudo sh -c 'echo i2c-dev >> /etc/modules'

#Build the IP demo
cd Apps_C/P05-IP
make

#Clone the latest version of the Sensorian Interface repository into SensorianInterface
git clone https://github.com/sensorian/SensorianInterface.git ~/SensorianInterface
chmod +x ~/SensorianInterface/C/install.sh
chmod +x ~/SensorianInterface/Python/install.sh

#Get additional requirements for Sensorian Interface
sudo apt-get -y install libcurl4-openssl-dev || { echo "Failed to install libcurl4-openssl-dev" && exit; }

#Compile Sensorian Interface
cd ~/SensorianInterface/C
make
cd ~/SensorianInterface/Python/i2c-devices-interface
make
cd ..
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
cd ..
cp -p PythonSharedObjectSrc/MPL3115A2/libMPL.so ./libMPL.so
cp -p PythonSharedObjectSrc/FXOS8700CQR1/libFXO.so ./libFXO.so
cp -p PythonSharedObjectSrc/CAP1203/libCAP.so ./libCAP.so
cp -p i2c-devices-interface/libsensorianplus.so ./libsensorianplus.so
cd ..

#Clone the latest version of the Sensorian Hub Client repository into SensorianHubClient
git clone https://github.com/sensorian/SensorianHubClient.git ~/SensorianHubClient
chmod +x ~/SensorianHubClient/install.sh

#Get additional requirements for Sensorian Hub Client
sudo pip install Flask-HTTPAuth==3.1.2
sudo pip install Flask-RESTful==0.3.5

#Compile Sensorian Hub Client
cd ~/SensorianHubClient/PythonSharedObjectSrc
cd MPL3115A2
make
cd ..
cd FXOS8700CQR1
make
cd ..
cd CAP1203
make
cd ..
cd ..
cp -p PythonSharedObjectSrc/MPL3115A2/libMPL.so ./libMPL.so
cp -p PythonSharedObjectSrc/FXOS8700CQR1/libFXO.so ./libFXO.so
cp -p PythonSharedObjectSrc/CAP1203/libCAP.so ./libCAP.so
cd ..

#Switch back to the build directory
cd $builddir

#Add the IP demo to the crontab
echo "@reboot /home/pi/Sensorian/Apps_C/P05-IP/IP" > mycron
sudo crontab mycron

#At this point, everything should be installed.
echo "Sensorian should now be configured. Reboot and enjoy!"
