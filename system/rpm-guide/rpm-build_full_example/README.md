Mainly inspired by : https://github.com/ulyaoth/repository/tree/master/ulyaoth-tomcat
Adaptation required for "lapin" env ( mainly $PATH )

Strongly  following for meetic specs https://gitlab.meetic.ilius.net/infra-prod/rpm-tomcat8
Strongly inspired from "https://jdebp.eu/FGA/systemd-house-of-horror/tomcat.html for " for service configuration dedicated to systemd.

Mostly build for os => centos 7 using systemd 

short resume : 
```
$ lsb_release -d
Description:	CentOS Linux release 7.4.1708 (Core) 

$rpmdev-setuptree
$sudo yum-builddep -y /home/$USER/rpmbuild/SPECS/tomcat9.spec
# Download additional files specified in spec file.
$spectool /home/$USER/rpmbuild/SPECS/tomcat9.spec -g -R
# Build the rpm.
rpmbuild -ba /home/$USER/rpmbuild/SPECS/tomcat9.spec
```
