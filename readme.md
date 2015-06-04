## Usage

### Warning! This script will overwrite previous configs during reinstallation.

	wget --no-check-certificate https://raw.github.com/robertfoss/vps_setup/master/setup-debian.sh 
	chmod +x setup-debian.sh
	./setup-debian.sh system $vps_hostname $username $password $ssh_pub_key

#### Extras

##### Webmin

	./setup-debian.sh webmin

##### vzfree

Supported only on OpenVZ only, vzfree reports correct memory usage

	./setup-debian.sh vzfree

##### Classic Disk I/O and Network test

Run the classic Disk IO (dd) & Classic Network (cachefly) Test

	./setup-debian.sh test

##### Neat python script to report memory usage per app

Neat python script to report memory usage per app

	./setup-debian.sh ps_mem

##### sources.list updating (Ubuntu only)

Updates Ubuntu /etc/apt/sources.list to default based on whatever version you are running

	./setup-debian.sh apt

##### Info on Operating System, version and Architecture

	./setup-debian.sh info

    
##### Extras

Fixing locale on some OpenVZ Ubuntu templates

	./setup-debian.sh locale

Configure or reconfigure MOTD

	./setup-debian.sh motd


## Credits

- [LowEndBox admin (LEA)](https://github.com/lowendbox/lowendscript),
