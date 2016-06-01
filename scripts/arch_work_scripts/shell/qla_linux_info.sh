#!/bin/bash
#####################################################################
# This script attempts to gather troubleshooting information on 
# a variety of Linux hosts.  Files that exist in one distribution of
# Linux may not exist in another distribution (SuSE vs Red Hat).
# Please ignore any errors reported about files not existing.
#
# Note: There may appear to be some inconsistencies where some
# commands are tested by "which" and others are not.  The "which" 
# tests will not generate outputs if the commands do not exist and
# eventually determine which outputs get posted to the dashboard.
#
# --Doug Gunderson
# --QLogic Technical Support
# --Intel Infiniband Technical Support
#
#####################################################################
ScriptVER="4.04.10"
#
#####################################################################

# So users can run the script using su or sudo
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH

####################################################################
# Test to see if run with with root permissions
#####################################################################
if [ `id -u` -ne 0 ]
then
   /bin/echo "This script must be run with root permissions.  Please rerun as root or with sudo."
   exit
fi

####################################################################
# Check to see if this is VMware 
#####################################################################
if [ -f /etc/vmware-release ]
then
   /bin/echo "This script is intended for RHEL or SLES distributions."
   /bin/echo "For VMware, please download and run the following:"
   /bin/echo "   ftp://ftp.qlogic.com/support/Hidden/scripts/qla_vmware_info.sh"
   /bin/echo "        or"
   /bin/echo "   ftp://ftp.qlogic.com/support/Hidden/scripts/qla_vmware_info.tar"
   exit
fi

####################################################################
# logger entry to identify start of script
#####################################################################
which logger > /dev/null 2>&1
if [ $? -eq 0 ]
then
   logger "qla_linux_info.sh starting with PID $$"
fi

#####################################################################
# Create temporary directory using HOSTNAME-DateTime to store output
#####################################################################
CurDate=`/bin/date +%y%m%d_%H%M%S`
HostName=`uname -n`
LOGNAME="$HostName-$CurDate"
LOGDIR="/tmp/$LOGNAME"
/bin/echo "Log data will be stored in $LOGDIR"
/bin/echo "Output results will be tar-zipped to $LOGDIR.tgz"
/bin/echo
mkdir $LOGDIR
mkdir $LOGDIR/script
cd $LOGDIR
touch $LOGDIR/script/ScriptVersion.$ScriptVER
mkdir $LOGDIR/OS

#####################################################################
# Gather OS info
#####################################################################
/bin/echo -n "Gathering OS info: "
OS_FILES=`ls /etc/*-release /etc/*_version 2>> $LOGDIR/script/misc_err.log`
for file in $OS_FILES
do
   if [ -f $file ]
   then
      cp -p $file $LOGDIR/OS
   fi
done

# Files useful if we need to duplicate the host install
if [ -f /root/anaconda-ks.cfg ]
then
   cp /root/anaconda-ks.cfg $LOGDIR/OS
fi
if [ -f /root/autoinst.xml ]
then
   cp /root/autoinst.xml $LOGDIR/OS
fi

rpm -qa  > $LOGDIR/OS/rpm_list.out
rpm --queryformat '[%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n]' -qa > /$LOGDIR/OS/rpm_detailed.out
uname -a > $LOGDIR/OS/uname

/bin/echo "... done"

#####################################################################
# Determine what hardware installed for gathering additional data
#####################################################################
/bin/echo -n "Gathering QLogic hardware info: "
mkdir $LOGDIR/misc
lspci -v                > $LOGDIR/misc/lspci.out 2>&1
# More details on QLogic, Netxen, Pathscale, Mellanox hardware
lspci -vvvxxx -d 1077:  > $LOGDIR/misc/lspci_detailed.out 2>&1
lspci -vvvxxx -d 4040: >> $LOGDIR/misc/lspci_detailed.out 2>&1
lspci -vvvxxx -d 1fc1: >> $LOGDIR/misc/lspci_detailed.out 2>&1
lspci -vvvxxx -d 15b3: >> $LOGDIR/misc/lspci_detailed.out 2>&1

FCINSTALLED=0
ISCSIINSTALLED=0
ETHERINSTALLED=0
IBINSTALLED=0
IBAINSTALLED=0
MLXINSTALLED=0
TESTHBA=`grep QLogic $LOGDIR/misc/lspci.out|grep "Fibre Channel:"`
if [ -n "$TESTHBA" ]
then
   FCINSTALLED=1
fi
TESTHBA=`grep QLogic $LOGDIR/misc/lspci.out|grep "Network controller:"`
if [ -n "$TESTHBA" ]
then
   ISCSIINSTALLED=1
fi
TESTHBA=`grep QLogic $LOGDIR/misc/lspci.out|grep "Ethernet controller:"`
if [ -n "$TESTHBA" ]
then
   ETHERINSTALLED=1
fi
TESTHBA=`grep NetXen $LOGDIR/misc/lspci.out|grep "Ethernet controller:"`
if [ -n "$TESTHBA" ]
then
   ETHERINSTALLED=1
fi
# QLE8042 uses Intel NIC - report only if FC Installed
TESTHBA=`grep "Intel Corporation 82598" $LOGDIR/misc/lspci.out|grep "Ethernet controller:"`
if [ -n "$TESTHBA" -a $FCINSTALLED -eq 1 ]
then
   ETHERINSTALLED=1
fi
TESTHBA=`grep QLogic $LOGDIR/misc/lspci.out|grep "InfiniBand:"`
if [ -n "$TESTHBA" ]
then
   IBINSTALLED=1
fi
TESTHBA=`grep Mellanox $LOGDIR/misc/lspci.out|egrep "InfiniBand:|Network controller:"`
if [ -n "$TESTHBA" ]
then
   IBINSTALLED=1
   MLXINSTALLED=1
fi

which iba_capture > /dev/null 2>&1
if [ $? -eq 0 ]
then
   IBAINSTALLED=1
fi
/bin/echo "... done"

#####################################################################
# Gather misc info
#####################################################################
/bin/echo -n "Gathering miscellaneous system info: "
uptime                 > $LOGDIR/misc/uptime.out 2>&1
dmidecode              >  $LOGDIR/misc/dmidecode.out 2>&1
fdisk -l               >  $LOGDIR/misc/fdisk.out 2>&1
ps -ewf                >  $LOGDIR/misc/ps.out
top -bH -n 1           >  $LOGDIR/misc/top.out 2>&1

ls -lF /usr/bin/*gcc*  >  $LOGDIR/misc/gcc.out 2>&1
/bin/echo "========"   >> $LOGDIR/misc/gcc.out
gcc --version          >> $LOGDIR/misc/gcc.out 2>&1

ldconfig -p            >  $LOGDIR/misc/ldconfig.out 2>&1
who -r                 >  $LOGDIR/misc/who_r.out 2>&1
runlevel               >  $LOGDIR/misc/runlevel.out 2>&1
env                    >  $LOGDIR/misc/env.out 2>&1
chkconfig --list       >  $LOGDIR/misc/chkconfig.out 2>&1
ls -alRF /usr/lib/     >  $LOGDIR/misc/ls_usrlib.out
if [ -d /usr/lib64 ]
then
   ls -alRF /usr/lib64/>  $LOGDIR/misc/ls_usrlib64.out
fi
which lsscsi > /dev/null 2>&1
if [ $? -eq 0 ]
then
   lsscsi              >  $LOGDIR/misc/lsscsi.out 2>&1
   lsscsi --verbose    >  $LOGDIR/misc/lsscsi_verbose.out 2>&1
fi
sysctl -a              >  $LOGDIR/misc/sysctl.out 2>&1
# DG: Problems on RHEL 6 ???
#lsof                  >  $LOGDIR/misc/lsof.out 2>&1
vmstat -a              >  $LOGDIR/misc/vmstat.out 2>&1
free                   >  $LOGDIR/misc/free.out 2>&1
ulimit -a              >  $LOGDIR/misc/ulimit.out 2>&1

if [ $IBINSTALLED -eq 0 ]
then
   if [ -f /etc/redhat-release ]
   then
      /bin/echo -n "... running sosreport "
      SOS_REPORT_FILE=`sosreport -o devicemapper,networking,udev,anaconda --batch 2>&1 | egrep bz2`
      if [ $? -eq 0 ]
      then
         cp $SOS_REPORT_FILE $LOGDIR/OS
      fi
   fi
   if [ -f /etc/SuSE-release ]
   then
      /bin/echo -n "... running supportconfig "
      SUSE_SUPPORTCONFIG=` supportconfig -g -i BOOT,DISK,LVM,MPIO,NET 2>&1 | grep var | grep ball`
      if [ $? -eq 0 ]
      then
         SUSE_SUPPORTCONFIG=`echo $SUSE_SUPPORTCONFIG | awk '{print $5}'`
         cp $SUSE_SUPPORTCONFIG $LOGDIR/OS
      fi
   fi
fi

/bin/echo "... done"

#####################################################################
# Gather /etc data
#####################################################################
/bin/echo -n "Gathering /etc files: "
mkdir $LOGDIR/etc
mkdir $LOGDIR/etc/sysconfig
ETC_FILES="/etc/modules.* \
/etc/modprobe.* \
/etc/qla*.conf \
/etc/hba.conf \
/etc/sysconfig/kernel \
/etc/sysconfig/hwconf \
/etc/sysctl.conf \
/etc/mtab \
/etc/fstab"

for file in $ETC_FILES
do
   if [ -f $file ]
   then
      cp -p $file $LOGDIR/$file
   fi
done

if [ -d /etc/modprobe.d ]
then
   ls -alRF /etc/modprobe.d > $LOGDIR/etc/ls_etc_modprobed.out
   mkdir $LOGDIR/etc/modprobe.d
   MODPROBE_FILES="/etc/modprobe.d/ib_qib.conf \
   /etc/modprobe.d/ib_ipoib.conf \
   /etc/modprobe.d/scsi_mod.conf \
   /etc/modprobe.d/qla2xxx.conf \
   /etc/modprobe.d/qla3xxx.conf \
   /etc/modprobe.d/qla4xxx.conf \
   /etc/modprobe.d/netxen_nic.conf \
   /etc/modprobe.d/nx_nic.conf \
   /etc/modprobe.d/qlge.conf \
   /etc/modprobe.d/blacklist \
   /etc/modprobe.d/blacklist.conf"
   for file in $MODPROBE_FILES
   do
      if [ -f $file ]
      then
         cp -p $file $LOGDIR/$file
      fi
   done

fi

ls -aldF /etc/rc*    > $LOGDIR/etc/ls_etcrcd.out
ls -alRF /etc/rc.d/ >> $LOGDIR/etc/ls_etcrcd.out

if [ $IBINSTALLED -eq 1 -a $IBAINSTALLED -eq 0 ]
then
   echo -n "... additional IB info ... "
   ETC_FILES="/etc/sysconfig/ics_inic.cfg* \
   /etc/sysconfig/ics_srp.cfg* \
   /etc/sysconfig/ipoib.cfg* \
   /etc/sysconfig/infiniband \
   /etc/sysconfig/boot \
   /etc/sysconfig/firstboot \
   /etc/sysconfig/*config \
   /etc/sysconfig/qlogic_fm.xml \
   /etc/sysconfig/opensm \
   /etc/dat.conf \
   /etc/tmi.conf \
   /etc/hosts"
   for file in $ETC_FILES
   do
      if [ -f $file ]
      then
         cp -p $file $LOGDIR/$file
      fi
   done
   if [ -d /etc/sysconfig/network ]
   then
      mkdir $LOGDIR/etc/sysconfig/network
      cp -p /etc/sysconfig/network/ifcfg* $LOGDIR/etc/sysconfig/network
   fi
   if [ -d /etc/sysconfig/network-scripts ]
   then
      mkdir $LOGDIR/etc/sysconfig/network-scripts
      cp -p /etc/sysconfig/network-scripts/ifcfg* $LOGDIR/etc/sysconfig/network-scripts
   fi
   if [ -d /etc/infiniband ]
   then
      mkdir $LOGDIR/etc/infiniband
      cp -p /etc/infiniband/* $LOGDIR/etc/infiniband
   fi
   if [ -d /etc/ofed ]
   then
      mkdir $LOGDIR/etc/ofed
      cp -pR /etc/ofed/* $LOGDIR/etc/ofed
   fi
   # RHEL 6 "ofed stack"
   if [ -d /etc/rdma ]
   then
      mkdir $LOGDIR/etc/rdma
      cp -pR /etc/rdma/* $LOGDIR/etc/rdma
   fi
   # iba_capture also copies files from /etc/sysconfig/iba (but that would be missing if no QLogic IB)
   #             and /etc/security (not sure why THAT directory)
   # Leaving them both out for now.
fi

/bin/echo "... done"

#####################################################################
# Gather /sys data
#####################################################################
if [ -d /sys ]
then
   /bin/echo -n "Gathering /sys files: "
   ls -alRF /sys > $LOGDIR/OS/ls_sys.out
   mkdir -p $LOGDIR/sys/class
   mkdir $LOGDIR/sys/class/scsi_host
   mkdir $LOGDIR/sys/class/fc_host
   mkdir $LOGDIR/sys/class/iscsi_host
   mkdir $LOGDIR/sys/class/net
   cp -pR /sys/class/scsi_host/*/      $LOGDIR/sys/class/scsi_host      2>  $LOGDIR/sys/copy_err.log
   cp -pR /sys/class/fc_host/*/        $LOGDIR/sys/class/fc_host        2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/class/iscsi_host/*/     $LOGDIR/sys/class/iscsi_host     2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/class/net/*/            $LOGDIR/sys/class/net            2>> $LOGDIR/sys/copy_err.log

   mkdir -p $LOGDIR/sys/module
   cp -pR /sys/module/scsi*            $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/qis*             $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/qla*             $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/qlge             $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/qlcnic           $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/ixgbe            $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/nx_nic           $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/netxen_nic       $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/8021q            $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   cp -pR /sys/module/bonding          $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log

   if [ $IBINSTALLED -eq 1 -a $IBAINSTALLED -eq 0 ]
   then
      IBDIRS=`ls -d /sys/class/*infiniband* 2>> $LOGDIR/script/misc_err.log`
      if [ -n "$IBDIRS" ]
      then
         for DIR in $IBDIRS
         do
            mkdir $LOGDIR/$DIR
            cp -pR $DIR/*/  $LOGDIR/$DIR  2>> $LOGDIR/sys/copy_err.log
         done
      fi
      # iba_capture does the following, but leaving it out for now
      #mkdir $LOGDIR/sys/class/scsi_device
      #cp -pR /sys/class/scsi_device/*/ $LOGDIR/sys/class/scsi_device    2>  $LOGDIR/sys/copy_err.log

      cp -pR /sys/module/ib_*          $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
      cp -pR /sys/module/iw_*          $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
      cp -pR /sys/module/ipoib*        $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
      cp -pR /sys/module/mlx*          $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
      cp -pR /sys/module/rdma*         $LOGDIR/sys/module 2>> $LOGDIR/sys/copy_err.log
   fi

   /bin/echo "... done"
fi

#####################################################################
# Gather /proc data
#####################################################################
/bin/echo -n "Gathering /proc files: "
mkdir $LOGDIR/proc
PROC_FILES="/proc/modules \
/proc/pci \
/proc/interrupts \
/proc/cmdline \
/proc/buddyinfo \
/proc/ksyms \
/proc/cpuinfo \
/proc/partitions \
/proc/iomem \
/proc/meminfo \
/proc/mtrr \
/proc/devices \
/proc/filesystems \
/proc/ioports \
/proc/version \
/proc/uptime \
/proc/iba \
/proc/slabinfo"

for file in $PROC_FILES
do
   if [ -f $file ]
   then
      cp -p $file $LOGDIR/$file
   fi
done

# Make sure /proc/scsi directory exists before gathering data
if [ -d /proc/scsi ]
then
   cd $LOGDIR/proc
   cp -pR /proc/scsi $LOGDIR/proc
   cd $LOGDIR
fi

# Gather power management info - performance issues
if [ -d /proc/acpi/processor ]
then
   mkdir -p $LOGDIR/proc/acpi/processor
   cp -pR /proc/acpi/processor/* $LOGDIR/proc/acpi/processor
fi

# Gather network info for IPoIB, FCoE and Netxen
if [ $ETHERINSTALLED -eq 1 -o $IBINSTALLED -eq 1 ]
then
   mkdir $LOGDIR/proc/net
   # Make sure /proc/net/nx_nic directory exists before gathering data
   if [ -d /proc/net/nx_nic ]
   then
      cp -pR /proc/net/nx_nic $LOGDIR/proc/net
   fi
   # Make sure /proc/net/bonding directory exists before gathering data
   if [ -d /proc/net/bonding ]
   then
      cp -pR /proc/net/bonding $LOGDIR/proc/net
   fi
   # Make sure /proc/net/vlan directory exists before gathering data
   if [ -d /proc/net/vlan ]
   then
      cp -pR /proc/net/vlan $LOGDIR/proc/net
   fi
   # Other proc/net files
   PROC_FILES="/proc/net/arp \
   /proc/net/dev \
   /proc/net/dev_mcast \
   /proc/net/route \
   /proc/net/rt_cache"
   for file in $PROC_FILES
   do
      if [ -f $file ]
      then
         cp -p $file $LOGDIR/$file
      fi
   done
fi

# proc/driver files (mostly IB related)
if [ $IBINSTALLED -eq 1 -a $IBAINSTALLED -eq 0 ]
then
   mkdir $LOGDIR/proc/driver
   PROC_FILES="/proc/driver/ics_dsc \
   /proc/driver/dev \
   /proc/driver/ics_inic \
   /proc/driver/ics_srp \
   /proc/driver/ipoib \
   /proc/driver/sdp \
   /proc/driver/ics_offload \
   /proc/driver/ics_sdp \
   /proc/driver/rds"
   for file in $PROC_FILES
   do
      if [ -f $file ]
      then
         cp -p $file $LOGDIR/$file
      fi
   done
fi
/bin/echo "... done"

#####################################################################
# Gather module info
#####################################################################
/bin/echo -n "Gathering module information: "
mkdir $LOGDIR/modules
KERN_VER=`uname -r`
MAJ_VER=`/bin/echo $KERN_VER | head -c3`
if [ $MAJ_VER = "2.4" ]
then
   EXT=".o"
fi
if [ $MAJ_VER = "2.6" ]
then
   EXT=".ko"
fi

find /lib/modules/$KERN_VER/ -name qla\*$EXT -print \
  -exec modinfo {} \; -exec /bin/echo \; > $LOGDIR/modules/modinfo.out 2>&1

find /lib/modules/$KERN_VER/ -name qisioctl\*$EXT -print \
  -exec modinfo {} \; -exec /bin/echo \; >> $LOGDIR/modules/modinfo.out 2>&1
find /lib/modules/$KERN_VER/ -name qioctlmod\*$EXT -print \
  -exec modinfo {} \; -exec /bin/echo \; >> $LOGDIR/modules/modinfo.out 2>&1
find /lib/modules/$KERN_VER/ -name netxen\*$EXT -print \
  -exec modinfo {} \; -exec /bin/echo \; >> $LOGDIR/modules/modinfo.out 2>&1
find /lib/modules/$KERN_VER/ -name nx_\*$EXT -print \
  -exec modinfo {} \; -exec /bin/echo \; >> $LOGDIR/modules/modinfo.out 2>&1
find /lib/modules/$KERN_VER/ -name qlge\*$EXT -print \
  -exec modinfo {} \; -exec /bin/echo \; >> $LOGDIR/modules/modinfo.out 2>&1
find /lib/modules/$KERN_VER/ -name qlcnic\*$EXT -print \
  -exec modinfo {} \; -exec /bin/echo \; >> $LOGDIR/modules/modinfo.out 2>&1

# Gather qisioctl and qioctlmod info (if installed)
modinfo qisioctl  >> $LOGDIR/modules/qisioctl.out  2>> $LOGDIR/script/misc_err.log
modinfo qioctlmod >> $LOGDIR/modules/qioctlmod.out 2>> $LOGDIR/script/misc_err.log


ls -alRF /lib/modules/ > $LOGDIR/modules/ls_libmodules.out

lsmod                  > $LOGDIR/modules/lsmod.out 2>&1

#if [ $IBINSTALLED -eq 1 -a $IBAINSTALLED -eq 0 ]
if [ $IBINSTALLED -eq 1 ]
then
   touch $LOGDIR/modules/ibmodpaths.out $LOGDIR/modules/ibmodinfo.out
   for mod in ib_ipath ib_qib ipath_core ib_core ib_ipoib ib_sa ib_umad ib_mad ib_uverbs mlx4_ib ib_mthca kcopy
   do 
      modinfo -F filename $mod >> $LOGDIR/modules/ibmodpaths.out 2>&1
      modinfo $mod             >> $LOGDIR/modules/ibmodinfo.out 2>&1
      /bin/echo                >> $LOGDIR/modules/ibmodinfo.out 2>&1
   done
   depmod -ae > $LOGDIR/modules/depmod.out 2>&1
   sort $LOGDIR/modules/lsmod.out | egrep -i "ipath_|infinipath|_ipath|ib_qib" > $LOGDIR/modules/ipath_module_list.out 2>&1
   sort $LOGDIR/modules/lsmod.out | egrep -i "ib_qib|ipath_|infinipath|^ib_|[ ,]ib_|rdma_|_vnic|rds|findex" > $LOGDIR/modules/infiniband_modules.out 2>&1
fi

/bin/echo "... done"

#####################################################################
# Gather ethernet info
#####################################################################
/bin/echo -n "Gathering ethernet info: "
mkdir $LOGDIR/network
iptables --list > $LOGDIR/network/iptables.out 2>&1
ifconfig -a     > $LOGDIR/network/ifconfig.out 2>&1
ip addr show    > $LOGDIR/network/ipaddrshow.out 2>&1
ip -s link show > $LOGDIR/network/iplinkshow.out 2>&1
netstat -rn     > $LOGDIR/network/netstat.out
which ethtool > /dev/null 2>&1
if [ $? -eq 0 ]
then
   ETHDEVS=`grep "Link encap" $LOGDIR/network/ifconfig.out | cut -d " " -f1`
   if [ $IBINSTALLED -eq 1 ]
   then
      IB_IF="ipoib"
   else
      IB_IF="ZILCH"
   fi
   for file in $ETHDEVS
   do
      DRIVER=`ethtool -i $file 2>> $LOGDIR/script/misc_err.log | egrep "nx_nic|netxen_nic|qla|ixgbe|qlge|qlcnic|$IB_IF"`
      if [ $? -eq 0 ]
      then
         ethtool -i $file > $LOGDIR/network/ethtool-i.$file 2>&1
         ethtool -k $file > $LOGDIR/network/ethtool-k.$file 2>&1
         ethtool    $file > $LOGDIR/network/ethtool.$file 2>&1
         ifconfig   $file > $LOGDIR/network/ifconfig.$file 2>&1
# DG: add netxen /opt/netxen/nxflash components here including version info (-v option)
      fi
   done
fi

/bin/echo "... done"

#####################################################################
# Gather SANsurfer and driver source info
#####################################################################
/bin/echo -n "Gathering SANsurfer and driver source info: "
mkdir $LOGDIR/QLogic_tools

if [ -d /opt/QLogic* ]
then
   ls -alRF /opt/QLogic* > $LOGDIR/QLogic_tools/ls_optQLogic.out

   if [ -d /opt/QLogic_Corporation/FW_Dumps ]
   then
      mkdir $LOGDIR/QLogic_tools/firmwaredumps
      cp /opt/QLogic_Corporation/FW_Dumps/* $LOGDIR/QLogic_tools/firmwaredumps 2>> $LOGDIR/script/misc_err.log
   fi

   SS_LOC="/opt/QLogic_Corporation/SANsurfer/qlogic.jar"
   SS_CLASS="com/qlogic/qms/hba/Res.class"
   ISS_LOC="/opt/QLogic_Corporation/SANsurfer/skins/power/iscsi_skin.properties"
   if [ -f $ISS_LOC ]
   then
      ISSNAME=`grep iscsi.main.application.name $ISS_LOC |cut -d " " -f3-6`
      ISSVER=`grep iscsi.main.application.version $ISS_LOC |cut -d " " -f3`
      /bin/echo "$ISSNAME      Version $ISSVER" > $LOGDIR/QLogic_tools/sansurfer_iscsi_installed.txt
   else
      /bin/echo "SANsurfer iSCSI Manager not found or not installed" > $LOGDIR/QLogic_tools/sansurfer_iscsi_installed.txt
   fi
   if [ -x /usr/local/bin/iqlremote ]
   then
      IQLREMOTE=`/usr/local/bin/iqlremote -v|grep -m1 Version`
      /bin/echo "SANsurfer iSCSI Remote Agent $IQLREMOTE" >>$LOGDIR/QLogic_tools/sansurfer_iscsi_installed.txt
   else
      /bin/echo "SANsurfer iSCSI Remote Agent not found or not installed" >>$LOGDIR/QLogic_tools/sansurfer_iscsi_installed.txt
   fi

   if [ -f $SS_LOC ]
   then
      SSVER=`unzip -p $SS_LOC $SS_CLASS | strings | grep Build`
      /bin/echo "SANsurfer FC Manager         Version $SSVER" > $LOGDIR/QLogic_tools/sansurfer_fc_installed.txt
   else
      /bin/echo "SANsurfer FC Manager not found or not installed" > $LOGDIR/QLogic_tools/sansurfer_fc_installed.txt
   fi
   if [ -x /usr/local/bin/qlremote ]
   then
      QLREMOTE=`/usr/local/bin/qlremote -v|grep -m1 Version`
      /bin/echo "SANsurfer FC Remote Agent    $QLREMOTE" >>$LOGDIR/QLogic_tools/sansurfer_fc_installed.txt
   else
      /bin/echo "SANsurfer FC Remote Agent not found or not installed" >>$LOGDIR/QLogic_tools/sansurfer_fc_installed.txt
   fi
else
   /bin/echo "SANsurfer iSCSI Manager not found or not installed" > $LOGDIR/QLogic_tools/sansurfer_iscsi_installed.txt
   /bin/echo "SANsurfer iSCSI Remote Agent not found or not installed" >>$LOGDIR/QLogic_tools/sansurfer_iscsi_installed.txt
   /bin/echo "SANsurfer FC Manager not found or not installed" > $LOGDIR/QLogic_tools/sansurfer_fc_installed.txt
   /bin/echo "SANsurfer FC Remote Agent not found or not installed" >>$LOGDIR/QLogic_tools/sansurfer_fc_installed.txt
fi

touch $LOGDIR/QLogic_tools/api_installed.txt
APIFILES="/usr/lib/libqlsdm.so /usr/lib64/libqlsdm.so"
for file in $APIFILES
do
   if [ -f $file ]
   then
      APIVER=`strings $file | grep "library version"`
   else
      APIVER="Not Installed"
   fi
   /bin/echo "API $file:   $APIVER" >> $LOGDIR/QLogic_tools/api_installed.txt
done

ls -alRF /usr/local/bin > $LOGDIR/QLogic_tools/ls_usrlocalbin.out

if [ -d /usr/src ]
then
   ls -alRF /usr/src/ > $LOGDIR/QLogic_tools/ls_usrsrc.out
fi

if [ -d /usr/src/qlogic ]
then
   cd /usr/src/qlogic
   tar cf $LOGDIR/QLogic_tools/driver_logs.tar `find . -name \*.log -print`
   cd $LOGDIR
fi

/bin/echo "... done"

#####################################################################
# Gather System Log info
#####################################################################
/bin/echo -n "Gathering syslog info: "
mkdir $LOGDIR/logs
LOG_FILES="/var/log/localmessages* \
/var/log/warn* \
/var/log/dmesg* \
/var/log/boot*"

if [ $IBINSTALLED -eq 0 -o $IBAINSTALLED -eq 0 ]
then
   LOG_FILES="$LOG_FILES /var/log/messages*"
fi
if [ $IBINSTALLED -eq 1 -a $IBAINSTALLED -eq 0 ]
then
   LOG_FILES="$LOG_FILES \
   /var/log/ics_* \
   /var/log/iba* \
   /var/log/ksyms.* \
   /var/log/opensm*"
fi

for file in $LOG_FILES
do
   if [ -f $file ]
   then
      cp -p $file $LOGDIR/logs 2>> $LOGDIR/script/misc_err.log
   fi
done

dmesg > $LOGDIR/logs/dmesg.out
ls -alRF /var/crash > $LOGDIR/OS/ls_varcrash.out 2>> $LOGDIR/script/misc_err.log
/bin/echo "... done"

#####################################################################
# Gather boot info
#####################################################################
/bin/echo -n "Gathering boot info: "
mkdir $LOGDIR/boot
BOOT_FILES="/boot/grub/grub.conf \
/boot/grub/menu.lst \
/boot/efi/efi/SuSE/elilo.conf \
/boot/efi/efi/redhat/elilo.conf \
/etc/lilo.conf \
/etc/elilo.conf"

for file in $BOOT_FILES
do
   if [ -f $file ]
   then
      cp -p $file $LOGDIR/boot
   fi
done

if [ -f /etc/grub.conf ]
then
   cp -p /etc/grub.conf $LOGDIR/boot/etc_grub.conf
fi

ls -alRF /boot > $LOGDIR/boot/ls_boot.out
/bin/echo "... done"

#####################################################################
# Gather scli info
#####################################################################
/bin/echo -n "Searching for SANsurfer CLI ... "
if [ -x /opt/QLogic_Corporation/SANsurferCLI/scli ]
then
   /bin/echo "SANsurfer FC/CNA CLI" > $LOGDIR/QLogic_tools/scli_installed.txt
   /opt/QLogic_Corporation/SANsurferCLI/scli -v 2>> $LOGDIR/script/misc_err.log |grep -m1 Build >> $LOGDIR/QLogic_tools/scli_installed.txt
   /bin/echo -n "installed ... "
   /bin/echo -n "Gathering FC configuration information ... "
   /opt/QLogic_Corporation/SANsurferCLI/scli -z > $LOGDIR/QLogic_tools/scli.out 2>&1
   /bin/echo "done"
elif [ -x /opt/QLogic_Corporation/QConvergeConsoleCLI/scli ]
then
   /bin/echo "SANsurfer FC/CNA CLI" > $LOGDIR/QLogic_tools/scli_installed.txt
   /opt/QLogic_Corporation/QConvergeConsoleCLI/scli -v 2>> $LOGDIR/script/misc_err.log |grep -m1 Build >> $LOGDIR/QLogic_tools/scli_installed.txt
   /bin/echo -n "installed ... "
   /bin/echo -n "Gathering FC configuration information ... "
   /opt/QLogic_Corporation/QConvergeConsoleCLI/scli -z > $LOGDIR/QLogic_tools/scli.out 2>&1
   /bin/echo "done"
else
   /bin/echo "SANsurfer FC CLI not found or not installed" > $LOGDIR/QLogic_tools/scli_installed.txt
   /bin/echo "not installed"
fi

#####################################################################
# Gather iscli info (if installed)
#####################################################################
/bin/echo -n "Searching for SANsurfer iscli ... "
if [ -x /opt/QLogic_Corporation/SANsurferiCLI/iscli ]
then
   /bin/echo "SANsurfer iSCSI CLI" > $LOGDIR/QLogic_tools/iscli_installed.txt
   /opt/QLogic_Corporation/SANsurferiCLI/iscli -ver |egrep "Version|MAPI" >> $LOGDIR/QLogic_tools/iscli_installed.txt
   /bin/echo -n "installed ... "
   /bin/echo -n "Gathering iSCSI configuration information ... "
   /opt/QLogic_Corporation/SANsurferiCLI/iscli -z > $LOGDIR/QLogic_tools/iscli.out 2>&1
   /bin/echo "done"
elif [ -x /opt/QLogic_Corporation/QConvergeConsoleCLI/iscli ]
then
   /bin/echo "SANsurfer iSCSI CLI" > $LOGDIR/QLogic_tools/iscli_installed.txt
   /opt/QLogic_Corporation/QConvergeConsoleCLI/iscli -ver |egrep "Version|MAPI" >> $LOGDIR/QLogic_tools/iscli_installed.txt
   /bin/echo -n "installed ... "
   /bin/echo -n "Gathering iSCSI configuration information ... "
   /opt/QLogic_Corporation/QConvergeConsoleCLI/iscli -z > $LOGDIR/QLogic_tools/iscli.out 2>&1
   /bin/echo "done"
else
   /bin/echo "SANsurfer iSCSI CLI not found or not installed" > $LOGDIR/QLogic_tools/iscli_installed.txt
   /bin/echo "not installed!"
fi

#####################################################################
# Gather netscli info (if installed)
#####################################################################
/bin/echo -n "Searching for SANsurfer netscli ... "
if [ -x /opt/QLogic_Corporation/QConvergeConsoleCLI/netscli ]
then
   /bin/echo "SANsurfer CNA Networking CLI" > $LOGDIR/QLogic_tools/netscli_installed.txt
   /opt/QLogic_Corporation/QConvergeConsoleCLI/netscli -ver |egrep "version|MAPI" >> $LOGDIR/QLogic_tools/netscli_installed.txt
   /bin/echo -n "installed ... "
   /bin/echo -n "Gathering CNA Networking configuration information ... "
   /opt/QLogic_Corporation/QConvergeConsoleCLI/netscli -z > $LOGDIR/QLogic_tools/netscli.out 2>&1
   /bin/echo "done"
else
   /bin/echo "SANsurfer CNA Networking CLI not found or not installed" > $LOGDIR/QLogic_tools/netscli_installed.txt
   /bin/echo "not installed!"
fi

#####################################################################
# Gather Infiniband info
#
#####################################################################
if [ $IBINSTALLED -eq 1 ]
then
   /bin/echo -n "Gathering Infiniband info: "
   mkdir $LOGDIR/infiniband
   rpm -qa --qf \
        '%{NAME}-%{VERSION}-%{RELEASE} Vendor=%{VENDOR} %{URL} Built=%{BUILDTIME:date}\n' | \
        egrep -i openib\|openfabrics\|qlogic\|pathscale\|silverstorm | sort > $LOGDIR/infiniband/ib_rpms.out

   if [ -d /opt/iba ]
   then
      ls -alRF /opt/iba > $LOGDIR/infiniband/ls_opt_iba.out
   fi
   if [ -d /opt/infinipath ]
   then
      ls -alRF /opt/infinipath > $LOGDIR/infiniband/ls_opt_infinipath.out
   fi
   if [ -d /opt/qlogic_ofed ]
   then
      ls -alRF /opt/qlogic_ofed > $LOGDIR/infiniband/ls_opt_qlogic_ofed.out
   fi
   if [ -d /opt/qlogic_fm ]
   then
      ls -alRF /opt/qlogic_fm > $LOGDIR/infiniband/ls_opt_qlogic_fm.out
   fi

   ls -lF /dev/ipath* /dev/infiniband > $LOGDIR/infiniband/ls_dev_info.out 2>&1
   egrep infiniband\|ipath /etc/udev*/* /etc/udev*/*/* 2>/dev/null | grep -v multipath > $LOGDIR/infiniband/udev_info.out

   if [ -d /usr/mpi ]
   then
      ls -alRF /usr/mpi > $LOGDIR/infiniband/ls_usr_mpi.out
   fi
   which mpi-selector > /dev/null 2>&1
   if [ $? -eq 0 ]
   then
      /bin/echo "MPI List:"   >  $LOGDIR/infiniband/mpi-selector.out 2>&1
      mpi-selector --list     >> $LOGDIR/infiniband/mpi-selector.out 2>&1
      /bin/echo "Active MPI:" >> $LOGDIR/infiniband/mpi-selector.out 2>&1
      mpi-selector --query    >> $LOGDIR/infiniband/mpi-selector.out 2>&1
   fi

   if [ -f /opt/iba/src/mpi_apps/.prefix ]
   then
      cp /opt/iba/src/mpi_apps/.prefix $LOGDIR/infiniband/mpi_apps.prefix
   fi

   /bin/echo -n " ... adapter info "
   which ibv_devinfo > /dev/null 2>&1
   if [ $? -eq 0 ]
   then
      ibv_devinfo -v > $LOGDIR/infiniband/ibv_devinfo.out 2>&1
   fi
   which ibv_devices > /dev/null 2>&1
   if [ $? -eq 0 ]
   then
      ibv_devices    > $LOGDIR/infiniband/ibv_devices.out 2>&1
   fi
   which ibstatus > /dev/null 2>&1
   if [ $? -eq 0 ]
   then
      ibstatus       > $LOGDIR/infiniband/ibstatus.out 2>&1
   fi
   which ibstat > /dev/null 2>&1
   if [ $? -eq 0 ]
   then
      ibstat         > $LOGDIR/infiniband/ibstat.out 2>&1
   fi
   which perfquery > /dev/null 2>&1
   if [ $? -eq 0 ]
   then
      perfquery      > $LOGDIR/infiniband/perfquery.out 2>&1
   fi

   if [ $MLXINSTALLED -eq 1 ]
   then
#      HCAS=`grep InfiniBand $LOGDIR/misc/lspci.out | grep -vi bridge | grep -vi QLogic | cut -d\  -f1`
      HCAS=`grep Mellanox $LOGDIR/misc/lspci.out | grep -vi bridge | cut -d\  -f1`
      if [ -n "$HCAS" ]
      then
         for HCA in $HCAS
         do
            touch $LOGDIR/infiniband/mlx_hca_info.out
            echo "#####################" >> $LOGDIR/infiniband/mlx_hca_info.out
            mstvpd $HCA                  >> $LOGDIR/infiniband/mlx_hca_info.out 2>&1
            mstflint -d $HCA dc          >> $LOGDIR/infiniband/mlx_hca_info.out 2>&1
            mstflint -d $HCA q           >> $LOGDIR/infiniband/mlx_hca_info.out 2>&1
            mstflint -d $HCA v           >> $LOGDIR/infiniband/mlx_hca_info.out 2>&1
            echo "#####################" >> $LOGDIR/infiniband/mlx_hca_info.out
         done
      fi
   else
      which ipath_control > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         ipath_control -iv > $LOGDIR/infiniband/ipath_control.out 2>&1
      fi
   fi

   ADAPTERSTATUS=`grep -i state $LOGDIR/infiniband/ibstat.out $LOGDIR/infiniband/ibv_devinfo.out 2> $LOGDIR/script/misc_err.log|grep -i active`
   if [ $? -eq 0 ]
   then
      /bin/echo -n " ... fabric info "
      which ibnodes > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         ibnodes > $LOGDIR/infiniband/ibnodes.out 2>&1
      fi
      which iblinkinfo > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         iblinkinfo > $LOGDIR/infiniband/iblinkinfo.out 2>&1
      else
         which iblinkinfo.pl > /dev/null 2>&1
         if [ $? -eq 0 ]
         then
            iblinkinfo.pl > $LOGDIR/infiniband/iblinkinfo.out 2>&1
         fi
      fi
      ibnetdiscover -p > $LOGDIR/infiniband/ibnetdiscover.out 2>&1
      which ibqueryerrors > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         ibqueryerrors -r > $LOGDIR/infiniband/ibqueryerrors.out 2>&1
      else
         ibqueryerrors.pl -r > $LOGDIR/infiniband/ibqueryerrors.out 2>&1
      fi
      which sminfo > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         sminfo > $LOGDIR/infiniband/sminfo.out 2>&1
      fi
      which saquery > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         saquery      > $LOGDIR/infiniband/saquery.out 2>&1
         saquery LR   > $LOGDIR/infiniband/saquery_links.out 2>&1
# DG: PIR option is not what is expected with RHEL 5.4 and SLES 11
         saquery PIR  > $LOGDIR/infiniband/saquery_verbose.out 2>&1
         saquery -s  >> $LOGDIR/infiniband/sminfo.out 2>&1
      fi
      which fabric_info > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         /sbin/fabric_info > $LOGDIR/infiniband/fabric_info.out 2>&1
      fi
   else
      /bin/echo -n " ... no adapter status, skipping fabric info "
   fi

   /bin/echo "... done"

   if [ $IBAINSTALLED -eq 1 ]
   then
      /bin/echo "Running iba_capture ..."
      iba_capture -d 3 $LOGDIR/infiniband/iba_capture.tgz |grep -v iba_capture
   elif [ $MLXINSTALLED -eq 0 ]
   then
      which ipathstats > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         ipathstats > $LOGDIR/infiniband/ipathstats.out 2>&1
         /bin/echo >> $LOGDIR/infiniband/ipathstats.out 2>&1
         ipathstats -e >> $LOGDIR/infiniband/ipathstats.out 2>&1
      fi
      which ipath_trace > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
         ipath_trace -d > $LOGDIR/infiniband/ipath_trace.out 2>&1
      fi
   fi
fi

#####################################################################
# Place holder below for dashboard.sh
#####################################################################
# Start of dashboard.sh
#####################################################################
# Post-process script output into pdeudo-meaningful html
#####################################################################

# The next line (LOGDIR=$1) must be removed before merging in with 
# the main data gathering script
cd $LOGDIR

#####################################################################
# Create revisionhistory.txt for the script output
#####################################################################
cat > $LOGDIR/script/revisionhistory.txt <<!
QLogic Linux Information Gathering Script - Revision History

 Revision History
  Rev  4.04.10 2012/04/25
      - Minor mod for dashboard to scan correct file for FC Link state
  Rev  4.04.09 2012/02/07
      - Added netscli
  Rev  4.04.08 2011/11/29
      - Rather than trying to guess /sbin, /usr/sbin paths, just fix $PATH
      - Added "ip cmd show" to report address and link info (ifconfig deprecated)
      - Finally (so we hope) got rid of the duplicate driver params in the dashboard
  Rev  4.04.07 2011/10/05
      - Changes to include new path for fc/iscsi/nic cli tools
  Rev  4.04.06 2011/09/23
      - Added "top" output
      - Added /etc/modprobe.d/scsi_mod.conf (RHEL 6.x)
  Rev  4.04.05 2011/09/08
      - Tweaks to address Mellanox LOM 
      - Added /sbin and /usr/sbin for commands "hidden" by sudo
  Rev  4.04.04  2011/09/01
      - Changes to include /etc/modprobe.d/<module>.conf files
  Rev  4.04.03  2011/06/14
      - Added MPI queries
      - Temporarily removed "df" command due to some problems on RHEL 6
      - Started other changes for RHEL 6 issues
      - Added anaconda to sosreport and ~/anaconda-ks.cfg (RHEL) ~/autoinstall.xml (SLES) files
  Rev  4.04.02  2011/05/04
      - Added Rocks version to dashboard
      - Only gather IB fabric information if adapter state is active
      - "pulled" ibdiagnet because it has shown problems on some fabrics
  Rev  4.04.01  2011/04/13
      - Barely out of the box and have to make a change ...
      - Added /etc/tmi.conf
  Rev  4.04.00  2011/04/12
      - Major changes to include Infiniband host and fabric information
      - Restructure of qla_linux_info.sh to query QLogic hardware before querying
        product-related info
      - New script is qla_linux_ibinfo.sh
  Rev  4.02.08  2011/03/04
      - Added /opt/QLogic_Corporation/FW_Dumps/*
      - Added sosreport (RHEL) and supportconfig (SLES)
      - Added FC driver version check to detect RAMDISK mismatch
  Rev  4.02.07a 2010/05/17
      - Added some minor changes to capture more IB goodies
  Rev  4.02.07  2010/04/22
      - Added /etc/sysctl.conf for collection
  Rev  4.02.06  2010/04/02
      - Removed VMware info to new qla_vmware_info.sh script
      - Added a few Infiniband goodies in lieu of a major overhaul of the IB script
      - Minor tweaks to remove some more errors introduced with the new changes
  Rev  4.02.05  2010/03/05
      - Added ls /var/crash
      - Added a few more VMware goodies until qla_vmware_info.sh is complete
  Rev  4.02.04  2010/02/19
      - Minor fixes to remove error messages
      - Moved OS stuff to the front to check for VMware
      - Plans (commented for now) to check for VMware and exit when separate VMWare script done
      - Added esx and vmk commands if VMware 
  Rev  4.02.03  2010/01/19
      - Added vmware logs
  Rev  4.02.02  2009/11/24
      - Added ethtool -k to get offload info on QLogic NICs and CNAs.
      - Changed where we look to get scli information (go directly to /opt)
  Rev  4.02.01  2009/11/13
      - Minor fix to the "which xxx" commands.  Some OSes did not like the redirect.
      - Add /proc/net/bonding and /proc/net/vlan for FCoE and Netxen.
      - Modified sysfs gathering due to changes with SLES 11.
      - Finally got rid of index.html.
      - Added modinfo for qioctlmod module
  Rev  4.02.00  2009/09/02
      - Significant modifications to restructure dashboard and gather additional data
      - Added more FC info from /sys for inbox driver
      - Added separate modinfo query for qisioctl to more easily add to dashboard
      - Integrated SANsurfer / agent / [i]scli / API version info into mgmt tools section
      - Added section for ethernet info (FCoE and NetXen NICs)
      - Moved dashboard.html and details.html to root directory of tgz file and deprecated index.html
  Rev  4.01.01  2009/07/14
      - Fixed serious bug -NOT- changed title from Windows to Linux (can't be having that!)
      - Changed reference from "Readme" to "Details" (readme.html is now details.html)
  Rev  4.01.00  2009/05/14
      - Significant modifications to gather additional data (and clear the RFE stack)
      - Added logger entry for script start (pointless to do one at the end of the script)
      - Added more files collected from /proc directory
      - Added modinfo for qisioctl module
      - Added temporary tgz fix for /sys files causing extraction errors
      - Added version query for /usr/lib[64]/libqlsdm.so (API)
      - Added more command queries (lsscsi lsof free vmstat sysctl)
  Rev  4.00.06  2009/03/12
      - Added check for script run with root permissions
      - Added /etc/*-release /etc/*_version to verify supported distributions
  Rev  4.00.05  2009/01/27
      - Added dmidecode output
      - Changed datecode on the tgz filename from MMDDYY to YYMMDD
  Rev  4.00.04  2008/11/10
      - Added driver & scsi parameters to dashboard
  Rev  4.00.03  2008/10/27
      - Added GCC version to dashboard
  Rev  4.00.02  2008/08/13
      - Fix directory listing of 32-bit and 64-bit loadable libraries
  Rev  4.00.01  2008/08/06
      - Add directory listing of 32-bit and 64-bit loadable libraries
  Rev  4.00.00  2007/12/07
      - Major restructuring to add html dashboard
      - added /proc/cpuinfo
  Rev  3.00.01  2007/08/23
      - Add driver_logs.tar to capture driver installation logs
      - Change iscli to use the new "-z" option
  Rev  3.00.00  2007/01/18
      - Change output directory and tgz name to assure uniqueness
      - Add iscli_info.sh script to this script
  Rev  2.00.03  2006/12/18
      - Add uptime
  Rev  2.00.02  2006/04/19
      - Add gcc info
  Rev  2.00.01  2006/03/23
      - Add ls -alRF /sys
  Rev  2.00.00  2006/03/16
      - Major restructuring to remove OS-specific errors
  Rev  1.00.04  2006/12/06
      - Add ifconfig info
      - Add ls -alR /etc/rc.d/ /opt/QLogic* /usr/local/bin
      - Add chkconfig to list configured daemons
  Rev  1.00.03  2005/05/20
      - Add SuSE ia64 goodies
      - Add /etc/qla2xxx.conf
  Rev  1.00.02  2005/03/28
      - Add lspci -v (hwconf info)
      - Add scli -z all (if installed)
      - Add qla4xxx for QLA4010 on 2.6 kernel
      - Add dmesg command when no /var/log/dmesg file
  Rev  1.00.01  2005/03/28
      - Start of Revision History
!

#####################################################################
# Create dashboard.html for the script output
#####################################################################
DBH=$LOGDIR/dashboard.html
#
# Header
#
cat > $DBH <<!
<head><title>QLogic Linux Information Gathering Script - Dashboard</title></head> 
<body> 
<font face="Courier New"> 
 <a id="top"></a> 
<div align="center"> 
<b>QLogic Linux Information Gathering Script Dashboard</b><br> 
!
/bin/echo `date` >> $DBH
/bin/echo "<hr><hr></div>" >> $DBH

#
# Header
#
cat >> $DBH <<!
<pre>Script Version $ScriptVER
<b>Index:</b><hr> 
Dashboard Links:                                      Key File Links:
!
/bin/echo -n "<a href=\"#systeminfo\">System Information</a>                                    " >> $DBH
/bin/echo    "<a href=\"details.html\">details.html</a>  - detailed information on collected files" >> $DBH
/bin/echo -n "<a href=\"#mgmtinfo\">QLogic Management Tools Information</a>                   " >> $DBH
/bin/echo    "<a href=\"misc/lspci.out\">lspci.out</a>     - list of installed PCI/PCIe hardware" >> $DBH
#if [ $FCINSTALLED -eq 1 ]
#then
   /bin/echo -n "<a href=\"#fcinfo\">Fibre Channel Information</a>                             " >> $DBH
   if [ -f QLogic_tools/scli.out ]
      then
         /bin/echo "<a href=\"QLogic_tools/scli.out\">scli.out</a>      - scli output" >> $DBH
      else
         /bin/echo "scli.out      - scli output (Not Installed)" >> $DBH
   fi
#fi
#if [ $ISCSIINSTALLED -eq 1 ]
#then
   /bin/echo -n "<a href=\"#iscsiinfo\">iSCSI Information</a>                                     " >> $DBH
   if [ -f QLogic_tools/iscli.out ]
      then
         /bin/echo "<a href=\"QLogic_tools/iscli.out\">iscli.out</a>     - iscli output" >> $DBH
      else
         /bin/echo "iscli.out     - iscli output (Not Installed)" >> $DBH
   fi
#fi
/bin/echo -n "<a href=\"#etherinfo\">Ethernet Information</a>                                  " >> $DBH
/bin/echo    "<a href=\"modules/lsmod.out\">lsmod.out</a>     - list of loaded modules" >> $DBH
#if [ $IBINSTALLED -eq 1 ]
#then
   /bin/echo -n "<a href=\"#ibinfo\">Infiniband Information</a>                                " >> $DBH
   if [ -f infiniband/iba_capture.tgz ]
      then
         /bin/echo "<a href=\"infiniband/iba_capture.tgz\">iba_capture</a>   - iba_capture tgz output" >> $DBH
      else
         /bin/echo "iba_capture   - iba_capture tgz output (IFS Not Installed)" >> $DBH
   fi
#fi
/bin/echo -n "<a href=\"#fclogs\">Fibre Channel Message Logs</a>                            " >> $DBH
if [ -f misc/lsscsi.out ]
   then
      /bin/echo "<a href=\"misc/lsscsi.out\">lsscsi.out</a>    - list of scsi devices" >> $DBH
   elif [ -f proc/scsi/scsi ]
   then
      /bin/echo "<a href=\"proc/scsi/scsi\">scsi</a>          - list of scsi devices (/proc/scsi/scsi)" >> $DBH
   else
      /bin/echo "scsi          - No SCSI information found" >> $DBH
fi
/bin/echo -n "<a href=\"#iscsilogs\">iSCSI Message Logs</a>                                    " >> $DBH
if [ -f etc/modprobe.conf.local ]
   then
      /bin/echo "<a href=\"etc/modprobe.conf.local\">modprobe.conf</a> - list of module parameters (modprobe.conf.local)" >> $DBH
   elif [ -f etc/modprobe.conf ]
   then
      /bin/echo "<a href=\"etc/modprobe.conf\">modprobe.conf</a> - list of module parameters" >> $DBH
   else
      /bin/echo "<a href=\"etc/modules.conf\">modules.conf</a>  - list of module parameters" >> $DBH
fi
/bin/echo -n "<a href=\"#etherlogs\">Ethernet Message Logs</a>                                 " >> $DBH
/bin/echo    "<a href=\"network/ifconfig.out\">ifconfig.out</a>  - list of network interfaces" >> $DBH
/bin/echo "<a href=\"#iblogs\">Infiniband Message Logs</a><br>" >> $DBH 

#
# System Information
#
cat >> $DBH <<!
<hr><a id="systeminfo"></a><b><a href="details.html#osfiles">System Information:</a></b>     <a href="#top">top</a><hr> 
!
HOSTNAME=`cut -d " " -f2 < $LOGDIR/OS/uname`
/bin/echo "Host Name:                 $HOSTNAME" >> $DBH
if [ -f $LOGDIR/OS/redhat-release ]
then
   OSNAME=`cat $LOGDIR/OS/redhat-release`
   if [ -f $LOGDIR/OS/rocks-release ]
   then
      OSNAME="$OSNAME / `cat $LOGDIR/OS/rocks-release`"
   fi
elif [ -f $LOGDIR/OS/SuSE-release ]
then
   OSNAME=`grep -i suse $LOGDIR/OS/SuSE-release`
   OSVER=`grep VERSION $LOGDIR/OS/SuSE-release`
   OSPATCH=`grep -h PATCH $LOGDIR/OS/*release`
else
   OSNAME="unknown"
fi
/bin/echo "OS Name:                   $OSNAME" >> $DBH
if [ -f $LOGDIR/OS/SuSE-release ]
then
   /bin/echo "OS Version:                $OSVER,   $OSPATCH" >> $DBH
fi
KERNELVERSION=`cut -d " " -f3 < $LOGDIR/OS/uname`
/bin/echo "Kernel Version:            $KERNELVERSION" >> $DBH
/bin/echo "GCC Version:               `grep "gcc (" $LOGDIR/misc/gcc.out`" >> $DBH
/bin/echo "System Up Time:           `cat $LOGDIR/misc/uptime.out`" >> $DBH
PRODNAME=`sed -n '/System Information/,/Handle/p' $LOGDIR/misc/dmidecode.out |grep "Product Name" | cut -d ":" -f2`
MFGRNAME=`sed -n '/System Information/,/Handle/p' $LOGDIR/misc/dmidecode.out |grep "Manufacturer" | cut -d ":" -f2`
if [ -z "$PRODNAME" -o -z "$MFGRNAME" ]
then
PRODNAME=`sed -n '/Base Board Information/,/Handle/p' $LOGDIR/misc/dmidecode.out |grep "Product Name" | cut -d ":" -f2`
MFGRNAME=`sed -n '/Base Board Information/,/Handle/p' $LOGDIR/misc/dmidecode.out |grep "Manufacturer" | cut -d ":" -f2`
fi
/bin/echo "System Manufacturer:      $MFGRNAME" >> $DBH
/bin/echo "System Model:             $PRODNAME" >> $DBH
CPUMODEL=`grep "model name" $LOGDIR/proc/cpuinfo |uniq |cut -d " " -f3-9`
CPUCOUNT=`grep -c "model name" $LOGDIR/proc/cpuinfo`
CPUSPEED=`grep "cpu MHz" $LOGDIR/proc/cpuinfo |uniq |cut -d " " -f3-9`
/bin/echo "CPU Info:                  (x$CPUCOUNT) $CPUMODEL, $CPUSPEED MHz" >> $DBH
BIOSVEND=`sed -n '/BIOS Information/,/Handle/p' $LOGDIR/misc/dmidecode.out |grep "Vendor" | cut -d ":" -f2`
BIOSVERS=`sed -n '/BIOS Information/,/Handle/p' $LOGDIR/misc/dmidecode.out |grep "Version" | cut -d ":" -f2`
BIOSDATE=`sed -n '/BIOS Information/,/Handle/p' $LOGDIR/misc/dmidecode.out |grep "Release Date" | cut -d ":" -f2`
/bin/echo "BIOS Version:             $BIOSVEND  Version $BIOSVERS  $BIOSDATE" >> $DBH
/bin/echo >> $DBH

/bin/echo "<B>FC Driver Parameters:</B>" >> $DBH
if [ -f $LOGDIR/etc/modprobe.conf.local ]
then
   grep -h "options qla2" $LOGDIR/etc/modprobe.conf.local >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.conf ]
then
   grep -h "options qla2" $LOGDIR/etc/modprobe.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/qla2xxx.conf ]
then
   grep -h "options qla2" $LOGDIR/etc/modprobe.d/qla2xxx.conf >> $DBH
fi

/bin/echo "<B>iSCSI Driver Parameters:</B>" >> $DBH
if [ -f $LOGDIR/etc/modprobe.conf.local ]
then
   grep -h "options qla4" $LOGDIR/etc/modprobe.conf.local >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.conf ]
then
   grep -h "options qla4" $LOGDIR/etc/modprobe.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/qla4xxx.conf ]
then
   grep -h "options qla4" $LOGDIR/etc/modprobe.d/qla4xxx.conf >> $DBH
fi

/bin/echo "<B>Ethernet Module Parameters:</B>" >> $DBH
if [ -f $LOGDIR/etc/modprobe.conf.local ]
then
   grep -h options $LOGDIR/etc/modprobe.conf.local | egrep "qla3|qlge|qlcnic|nx_nic|netxen_nic" >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.conf ]
then
   grep -h options $LOGDIR/etc/modprobe.conf | egrep "qla3|qlge|qlcnic|nx_nic|netxen_nic" >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/qla3xxx.conf ]
then
   grep -h "options qla3" $LOGDIR/etc/modprobe.d/qla3xxx.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/qlge.conf ]
then
   grep -h "options qlge" $LOGDIR/etc/modprobe.d/qlge.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/qlcnic.conf ]
then
   grep -h "options qlcnic" $LOGDIR/etc/modprobe.d/qlcnic.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/nx_nic.conf ]
then
   grep -h "options nx_nic" $LOGDIR/etc/modprobe.d/nx_nic.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/netxen_nic.conf ]
then
   grep -h "options netxen_nic" $LOGDIR/etc/modprobe.d/netxen_nic.conf >> $DBH
fi

/bin/echo "<B>SCSI Module Parameters:</B>" >> $DBH
if [ -f $LOGDIR/etc/modprobe.conf.local ]
then
   grep -h "options scsi" $LOGDIR/etc/modprobe.conf.local >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.conf ]
then
   grep -h "options scsi" $LOGDIR/etc/modprobe.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/scsi.conf ]
then
   grep -h "options scsi" $LOGDIR/etc/modprobe.d/scsi.conf >> $DBH
fi

/bin/echo "<B>Infiniband Driver Parameters:</B>" >> $DBH
if [ -f $LOGDIR/etc/modprobe.conf.local ]
then
   grep -h "options ib_" $LOGDIR/etc/modprobe.conf.local >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.conf ]
then
   grep -h "options ib_" $LOGDIR/etc/modprobe.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/ib_qib.conf ]
then
   grep -h "options ib_qib" $LOGDIR/etc/modprobe.d/ib_qib.conf >> $DBH
fi
if [ -f $LOGDIR/etc/modprobe.d/ib_ipoib.conf ]
then
   grep -h "options ib_ipoib" $LOGDIR/etc/modprobe.d/ib_ipoib.conf >> $DBH
fi
/bin/echo >> $DBH

/bin/echo "<B>QLogic Adapters Installed:</B>" >> $DBH
if [ $FCINSTALLED -eq 1 ]
then
   grep QLogic $LOGDIR/misc/lspci.out|grep "Fibre Channel:" >> $DBH
else
   /bin/echo "No QLogic Fibre Channel Adapters Installed" >> $DBH
fi
if [ $ISCSIINSTALLED -eq 1 ]
then
   grep QLogic $LOGDIR/misc/lspci.out|grep "Network controller:" >> $DBH
else
   /bin/echo "No QLogic iSCSI Adapters Installed" >> $DBH
fi
if [ $ETHERINSTALLED -eq 1 ]
then
   grep QLogic $LOGDIR/misc/lspci.out|grep "Ethernet controller:" >> $DBH
   grep NetXen $LOGDIR/misc/lspci.out|grep "Ethernet controller:" >> $DBH
   # QLA8042 uses Intel NIC - report only if FC installed
   if [ $FCINSTALLED -eq 1 ]
   then
      grep "Intel Corporation 82598" $LOGDIR/misc/lspci.out|grep "Ethernet controller:" >> $DBH
   fi
else
   /bin/echo "No QLogic Ethernet Adapters Installed" >> $DBH
fi
if [ $IBINSTALLED -eq 1 ]
then
   grep QLogic $LOGDIR/misc/lspci.out|grep "InfiniBand:" >> $DBH
   grep Mellanox $LOGDIR/misc/lspci.out|egrep "InfiniBand:|Network controller:" >> $DBH
else
   /bin/echo "No QLogic Infiniband Adapters Installed" >> $DBH
fi
/bin/echo >> $DBH
 
#
# Management Tools Information
#
cat >> $DBH <<!
<hr><a id="mgmtinfo"></a><b><a href="details.html#QLogic_tools">QLogic Management Tools Information:</a></b>     <a href="#top">top</a><hr> 
!
cat >> $DBH <<!
<B>FC Adapter Tools:</B>
!
if [ $FCINSTALLED -eq 1 ]
then
   cat $LOGDIR/QLogic_tools/sansurfer_fc_installed.txt >> $DBH
   /bin/echo >> $DBH
   cat $LOGDIR/QLogic_tools/api_installed.txt >> $DBH
   /bin/echo >> $DBH
   cat $LOGDIR/QLogic_tools/scli_installed.txt >> $DBH
else
   /bin/echo "No FC Adapters installed" >> $DBH
fi
   /bin/echo >> $DBH

cat >> $DBH <<!
<B>iSCSI Adapter Tools:</B>
!
if [ $ISCSIINSTALLED -eq 1 ]
then
   cat $LOGDIR/QLogic_tools/sansurfer_iscsi_installed.txt | sed "s///" >> $DBH
   /bin/echo >> $DBH
   cat $LOGDIR/QLogic_tools/iscli_installed.txt >> $DBH
else
   /bin/echo "No iSCSI Adapters installed" >> $DBH
fi
/bin/echo >> $DBH

# Netxen and FCoE CNA Network Tools Version Information
cat >> $DBH <<!
<B>CNA Networking Tools:</B>
!
if [ $ETHERINSTALLED -eq 1 ]
then
   cat $LOGDIR/QLogic_tools/netscli_installed.txt >> $DBH
else
   /bin/echo "No Intelligent Ethernet Adapters installed" >> $DBH
fi
/bin/echo >> $DBH

# Placeholder for Infiniband Tools Version Information
cat >> $DBH <<!
<B>Infiniband Adapter Tools:</B>
!
if [ $IBINSTALLED -eq 1 ]
IBTOOLS=0
then
   if [ -f /etc/sysconfig/iba/version_ofed ]
   then
      /bin/echo -n "OFED Version:                  " >> $DBH
      cat /etc/sysconfig/iba/version_ofed >> $DBH
      IBTOOLS=1
   fi
   if [ -f /etc/sysconfig/iba/version_wrapper ]
   then
      /bin/echo -n "QLogic OFED+ Version:          " >> $DBH
      cat /etc/sysconfig/iba/version_wrapper >> $DBH
      IBTOOLS=1
   fi
   if [ -f /etc/sysconfig/iba/version_ff ]
   then
      /bin/echo -n "QLogic FastFabric Version:     " >> $DBH
      cat /etc/sysconfig/iba/version_ff >> $DBH
      IBTOOLS=1
   fi
   if [ -f /etc/sysconfig/iba/version_fmtools ]
   then
      /bin/echo -n "QLogic Fabric Manager Version: " >> $DBH
      cat /etc/sysconfig/iba/version_fmtools >> $DBH
      IBTOOLS=1
   fi
   if [ $IBTOOLS -eq 0 ]
   then
      /bin/echo "No QLogic Infiniband Tools installed" >> $DBH
   fi
else
   /bin/echo "No Infiniband Adapters installed" >> $DBH
fi
/bin/echo >> $DBH

#
# Fibre Channel Adapter Information
#
cat >> $DBH <<!
<hr><a id="fcinfo"></a><b><a href="details.html#procinfo">Fibre Channel Adapter Information:</a></b>     <a href="#top">top</a><hr> 
!
if [ $FCINSTALLED -eq 1 ]
then
   DRV_MOD_VER=`/sbin/modinfo qla2xxx | grep "^version" | cut -d " " -f 9`
   TESTDIR=`ls $LOGDIR/proc/scsi/|grep qla2`
   if [ -n "$TESTDIR" ]
   then
      PROCDIR=`ls $LOGDIR/proc/scsi/qla2*/[0-9]*`
      for FILE in $PROCDIR
      do
         grep Adapter $FILE|grep -v flag >> $DBH
         DRV_RUN_VER=`grep Driver $FILE | cut -d "," -f2 | sed "s/ //" | cut -d " " -f3`
         /bin/echo -n "Driver version $DRV_RUN_VER" >> $DBH
         if [ $DRV_MOD_VER = $DRV_RUN_VER -o ${DRV_MOD_VER}-fo = $DRV_RUN_VER ]
         then
            /bin/echo >> $DBH
         else
            /bin/echo "  <SPAN style='color:red'>Running driver version does not match installed driver version ($DRV_MOD_VER).  Update RAMDISK image.</SPAN>" >> $DBH
         fi
#         grep Driver $FILE | cut -d "," -f2 | sed "s/ //" >> $DBH
         grep Firmware $FILE | cut -d "," -f1 | sed "s/        //" >> $DBH
         grep Serial $FILE | cut -d "," -f2 | sed "s/ //" >> $DBH
         grep target $FILE|grep scsi >> $DBH
         /bin/echo >> $DBH
      done
   else
      TESTMOD=`grep "^qla2" $LOGDIR/modules/lsmod.out`
      if [ -n "$TESTMOD" ]
      then
         /bin/echo "No /proc information available for FC Driver" >> $DBH
         /bin/echo >> $DBH
         TESTDIR=`ls $LOGDIR/sys/class/scsi_host/ | grep host`
         if [ -n "$TESTDIR" ]
         then
            SYSDIR=`ls $LOGDIR/sys/class/scsi_host`
            for FILE in $SYSDIR
            do
               if [ -f $LOGDIR/sys/class/scsi_host/$FILE/driver_version ]
               then
                  ADAPTER=`cat $LOGDIR/sys/class/scsi_host/$FILE/model_name`
                  /bin/echo "Adapter Model: $ADAPTER" >> $DBH
                  DRV_RUN_VER=`cat $LOGDIR/sys/class/scsi_host/$FILE/driver_version`
                  /bin/echo -n "Driver Version: $DRV_RUN_VER" >> $DBH
                  if [ $DRV_MOD_VER = $DRV_RUN_VER -o ${DRV_MOD_VER}-fo = $DRV_RUN_VER ]
                  then
                     /bin/echo >> $DBH
                  else
                     /bin/echo "  <SPAN style='color:red'>Running driver version does not match installed driver version ($DRV_MOD_VER).  Update RAMDISK image.</SPAN>" >> $DBH
                  fi
                  FIRMWARE=`cat $LOGDIR/sys/class/scsi_host/$FILE/fw_version`
                  /bin/echo "Firmware Version: $FIRMWARE" >> $DBH
                  FLASHBIOS="$LOGDIR/sys/class/scsi_host/$FILE/optrom_bios_version"
                  if [ -f $FLASHBIOS ]; then /bin/echo "Flash BIOS Version: `cat $FLASHBIOS`" >> $DBH ; fi
                  FLASHEFI="$LOGDIR/sys/class/scsi_host/$FILE/optrom_efi_version"
                  if [ -f $FLASHEFI ]; then /bin/echo "Flash EFI Version: `cat $FLASHEFI`" >> $DBH ; fi
                  FLASHFCODE="$LOGDIR/sys/class/scsi_host/$FILE/optrom_fcode_version"
                  if [ -f $FLASHFCODE ]; then /bin/echo "Flash Fcode Version: `cat $FLASHFCODE`" >> $DBH ; fi
                  FLASHFW="$LOGDIR/sys/class/scsi_host/$FILE/optrom_fw_version"
                  if [ -f $FLASHFW ]; then /bin/echo "Flash Firmware Version: `cat $FLASHFW`" >> $DBH ; fi
                  MPIVER="$LOGDIR/sys/class/scsi_host/$FILE/mpi_version"
                  if [ -f $MPIVER ]; then /bin/echo "MPI Version: `cat $MPIVER`" >> $DBH ; fi
                  LINKSTATE="$LOGDIR/sys/class/scsi_host/$FILE/link_state"       # SLES uses different file than RHEL
                  if [ -f $LINKSTATE ]; then /bin/echo "Link State: `cat $LINKSTATE`" >> $DBH
                  else
                     LINKSTATE="$LOGDIR/sys/class/scsi_host/$FILE/state"
                     if [ -f $LINKSTATE ]; then /bin/echo "Link State: `cat $LINKSTATE`" >> $DBH ; fi
                  fi
                  NPIVVP="$LOGDIR/sys/class/scsi_host/$FILE/npiv_vports_inuse"
                  if [ -f $NPIVVP ]; then /bin/echo "NPIV VPorts: `cat $NPIVVP`" >> $DBH ; fi
                  VLANID="$LOGDIR/sys/class/scsi_host/$FILE/vlan_id"
                  if [ -f $VLANID ]; then /bin/echo "VLAN ID: `cat $VLANID`" >> $DBH ; fi
                  VNPORTMAC="$LOGDIR/sys/class/scsi_host/$FILE/vn_port_mac_address"
                  if [ -f $VNPORTMAC ]; then /bin/echo "VN Port MAC Address: `cat $VNPORTMAC`" >> $DBH ; fi
                  SERIAL=`cat $LOGDIR/sys/class/scsi_host/$FILE/serial_num`
                  /bin/echo "Serial #: $SERIAL" >> $DBH
                  /bin/echo >> $DBH
               fi
            done
         else
            /bin/echo "No /sys information available for FC Driver" >> $DBH
         fi
      else
         /bin/echo "Hardware present, but no FC drivers loaded" >> $DBH
         /bin/echo >> $DBH
      fi
   fi
else
   /bin/echo "No QLogic Fibre Channel Adapters Detected in system" >> $DBH
   /bin/echo >> $DBH
fi

#
# iSCSI Adapter Information
#
cat >> $DBH <<!
<hr><a id="iscsiinfo"></a><b><a href="details.html#procinfo">iSCSI Adapter Information:</a></b>     <a href="#top">top</a><hr> 
!
if [ $ISCSIINSTALLED -eq 1 ]
then
   TESTDIR=`ls $LOGDIR/proc/scsi/|grep qla4`
   if [ -n "$TESTDIR" ]
   then
      PROCDIR=`ls $LOGDIR/proc/scsi/qla4*/[0-9]*`
      for FILE in $PROCDIR
      do
         grep Adapter $FILE|grep -v flag >> $DBH
         grep Driver $FILE >> $DBH
         grep Firmware $FILE >> $DBH
         grep Serial $FILE >> $DBH
         grep target $FILE|grep scsi >> $DBH
         /bin/echo >> $DBH
      done
   else
      TESTMOD=`grep "^qla4" $LOGDIR/modules/lsmod.out`
      if [ -n "$TESTMOD" ]
      then
         /bin/echo "No /proc information available for iSCSI Driver" >> $DBH
         #Very slim pickings for qla4xxx information from /sys
         DRIVER="$LOGDIR/sys/module/qla4xxx/version"
         if [ -f $DRIVER ]
         then
            /bin/echo >> $DBH
            /bin/echo "iSCSI Driver Version: `cat $DRIVER`" >> $DBH
            /bin/echo "No additional /sys information available for iSCSI Driver" >> $DBH
            /bin/echo >> $DBH
         else
            /bin/echo "No /sys  information available for iSCSI Driver" >> $DBH
            /bin/echo >> $DBH
         fi
      else
         /bin/echo "Hardware present, but no iSCSI drivers loaded" >> $DBH
         /bin/echo >> $DBH
      fi
   fi
else
   /bin/echo "No QLogic iSCSI Adapters Detected in system" >> $DBH
   /bin/echo >> $DBH
fi

#
# Ethernet Adapter Information
#
cat >> $DBH <<!
<hr><a id="etherinfo"></a><b><a href="details.html#procinfo">Ethernet Adapter Information:</a></b>     <a href="#top">top</a><hr> 
!
if [ $ETHERINSTALLED -eq 1 -o $IBINSTALLED -eq 1 ]
then
   QLETHERDRIVER=0
   ETHDEVS=`grep "Link encap" $LOGDIR/network/ifconfig.out | cut -d " " -f1`
   for file in $ETHDEVS
   do
      if [ -f $LOGDIR/network/ethtool-i.$file ]
      then
         QLETHERDRIVER=1    
         /bin/echo "Interface:        $file" >> $DBH
         /bin/echo -n "Driver Module:    " >> $DBH
         grep driver $LOGDIR/network/ethtool-i.$file | cut -d " " -f2 >> $DBH
         /bin/echo -n "Driver Version:   " >> $DBH
         grep "^version" $LOGDIR/network/ethtool-i.$file | cut -d " " -f2 >> $DBH
         /bin/echo -n "Firmware Version: " >> $DBH
         grep firmware $LOGDIR/network/ethtool-i.$file | cut -d " " -f2 >> $DBH
         /bin/echo -n "Link Detected:    " >> $DBH
         LINKSTATE=`grep Link $LOGDIR/network/ethtool.$file | cut -d " " -f3`
         if [ -n "$LINKSTATE" ]; then /bin/echo $LINKSTATE >> $DBH ; else /bin/echo >>$DBH ; fi
         /bin/echo -n "Interface State:  " >> $DBH
         grep UP $LOGDIR/network/ifconfig.$file > /dev/null
         if [ $? -eq 0 ]; then /bin/echo UP >> $DBH
         else /bin/echo DOWN >> $DBH
         fi
         /bin/echo -n "HW Address:       " >> $DBH
         grep HWaddr $LOGDIR/network/ifconfig.$file | cut -d "W" -f2|cut -d " " -f2 >> $DBH
         /bin/echo -n "Inet Address:     " >> $DBH
         INETADDR=`grep "inet addr" $LOGDIR/network/ifconfig.$file | cut -d " " -f12-16`
         if [ -n "$INETADDR" ]; then /bin/echo $INETADDR >> $DBH ; else /bin/echo "Undefined" >> $DBH; fi
         /bin/echo -n "Inet6 Address:    " >> $DBH
         INET6ADDR=`grep "inet6 addr" $LOGDIR/network/ifconfig.$file | cut -d " " -f12-14`
         if [ -n "$INET6ADDR" ]; then /bin/echo $INET6ADDR >> $DBH ; else /bin/echo "Undefined" >> $DBH ; fi
         /bin/echo >> $DBH
      fi
   done
   if [ $QLETHERDRIVER -eq 0 ]
   then
      /bin/echo "No QLogic ethernet driver information available" >> $DBH
   fi
else
   /bin/echo "No QLogic Ethernet Adapters Detected in system" >> $DBH
fi

/bin/echo >> $DBH

#
# Infiniband Adapter and Fabric Information
#
cat >> $DBH <<!
<hr><a id="ibinfo"></a><b><a href="details.html#ibinfo">Infiniband Adapter and Fabric Information:</a></b>     <a href="#top">top</a><hr> 
!
if [ $IBINSTALLED -eq 1 ]
then
   cd $LOGDIR/infiniband
   if [ -f ipath_control.out ]
   then
      cat ipath_control.out >> $DBH
   fi
   if [ -f ibv_devinfo.out ]
   then
      cat ibv_devinfo.out >> $DBH
   elif [ -f ibstat.out ]
   then
      cat ibstat.out >> $DBH
   else
      /bin/echo "No Infiniband port information available" >> $DBH
   fi
   /bin/echo >> $DBH

   if [ -f fabric_info.out ]
   then
      cat fabric_info.out >> $DBH
   elif [ -f sminfo.out -a -f ibnodes.out -a -f saquery_links.out -a -f iblinkinfo.out ]
   then
      /bin/echo "Fabric Information:" >> $DBH
      SMINFO=`grep guid sminfo.out 2>> $LOGDIR/script/misc_err.log`
      if [ $? -eq 0 ]
      then
         /bin/echo $SMINFO >> $DBH
         grep EndPortLid sminfo.out >> $DBH
      else
         /bin/echo "SM: No SM information available" >> $DBH
      fi
      /bin/echo "Number of CAs:" `grep Adapter saquery.out |wc -l` >> $DBH
      /bin/echo "Number of Switch Chips:" `grep Switch saquery.out |wc -l` >> $DBH
      /bin/echo "Number of Links:" $(($(grep LinkRecord saquery_links.out |wc -l) / 2)) >> $DBH
      /bin/echo "Number of 1x Ports:" `grep 1X iblinkinfo.out | wc -l` >> $DBH
   else
      /bin/echo "Insufficient data to report fabric information" >> $DBH
   fi
   cd $LOGDIR
else
   /bin/echo "No Infiniband Adapters Detected in system" >> $DBH
fi
/bin/echo >> $DBH

#
# Fibre Channel Message Logs
#
cat >> $DBH <<!
<hr><a id="fclogs"></a><b><a href="details.html#loginfo">Fibre Channel Message Logs:</a></b>     <a href="#top">top</a><hr> 
!
if [ -f $LOGDIR/logs/vmkernel ]
then
   grep qla2 $LOGDIR/logs/vmkernel* |tail -50 >> $DBH
fi
grep qla2 /var/log/messages |tail -50 >> $DBH
/bin/echo >> $DBH

#
# iSCSI Message Logs
#
cat >> $DBH <<!
<hr><a id="iscsilogs"></a><b><a href="details.html#loginfo">iSCSI Message Logs:</a></b>     <a href="#top">top</a><hr> 
!
if [ -f $LOGDIR/logs/vmkernel ]
then
   grep qla4 $LOGDIR/logs/vmkernel* |tail -50 >> $DBH
fi
grep qla4 /var/log/messages |tail -50 >> $DBH
/bin/echo >> $DBH

#
# Ethernet Message Logs
#
cat >> $DBH <<!
<hr><a id="etherlogs"></a><b><a href="details.html#loginfo">Ethernet Message Logs:</a></b>     <a href="#top">top</a><hr> 
!
if [ -f $LOGDIR/logs/vmkernel ]
then
   egrep "netxen_nic|nx_nic|qla3|qla2xip|qlge|qlcnic|ixgbe" $LOGDIR/logs/vmkernel* |tail -50 >> $DBH
fi
egrep "netxen_nic|nx_nic|qla3|qla2xip|qlge|qlcnic|ixgbe" /var/log/messages |tail -50 >> $DBH
/bin/echo >> $DBH

#
# Infiniband Message Logs
#
cat >> $DBH <<!
<hr><a id="iblogs"></a><b><a href="details.html#loginfo">Infiniband Message Logs:</a></b>     <a href="#top">top</a><hr> 
!
egrep "infinipath|ipath_|_ipath|ib_qib|ib_mthca|mlx" /var/log/messages |tail -50 >> $DBH
/bin/echo >> $DBH

#
# Wrap it up
#
# Temporary cleanup of $LOGDIR/sys to avoid extraction errors
cd $LOGDIR
if test -d ./sys
then
   tar czf $LOGDIR/OS/sys_files.tgz ./sys
   rm -rf $LOGDIR/sys
fi
# Now back to our regularly scheduled program

cat >> $DBH <<!
<hr><a id="bottom"></a> <a href="#top">top</a><hr> 
<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br> 
</pre> 
</font> 
</body>
!

#####################################################################
# Place holder below for details.sh
#####################################################################
# Start of details.sh
#####################################################################
# Post-process script output into pdeudo-meaningful html
#####################################################################

cd $LOGDIR

#####################################################################
# Create details.html for the script output
#####################################################################
DTL=$LOGDIR/details.html
#
# Header
#
cat > $DTL <<!
<head><title>QLogic Linux Information Gathering Script - Details</title></head> 
<body> 
<font face="Courier New"> 
 <a id="top"></a> 
<div align="center"> 
<b>QLogic Linux Information Gathering Script Details</b><br> 
!
/bin/echo `date` >> $DTL
/bin/echo "<hr><hr></div>" >> $DTL

#
# Index
#
cat >> $DTL <<!
<pre>
<b>Index:</b><hr>
<a href="#about">About</a>
<a href="#osfiles">OS Information Files</a>
<a href="#etcfiles">/etc Information</a>
<a href="#modules">Module Information</a>
<a href="#procinfo">/proc Information</a>
<a href="#etherinfo">Ethernet Information</a>
<a href="#QLogic_tools">QLogic Tools (SANsurfer/CLI) Information</a>
<a href="#ibinfo">Infiniband Information</a>
<a href="#loginfo">System Log Information</a>
<a href="#miscinfo">Miscellaneous Information</a><br>
!

#
# About
#
cat >> $DTL <<!
<hr><a id="about"></a><b><a href="details.html">About:</a></b>     <a href="#top">top</a><hr>
This details file will walk through the information gathered by the information gathering script.

<a href="dashboard.html">dashboard.html</a>
This file is the starting place for all your basic troubleshooting needs.  It displays an overview
of the server, reports Adapter driver / firmware versions, and identifies installed QLogic applications.

<a href="details.html">details.html</a>
This file.

<a href="script/revisionhistory.txt">revisionhistory.txt</a>
This file contains the revision history for the Linux Information Gathering script.

!

#
# OS Information Files
#
cat >> $DTL <<!
<hr><a id="osfiles"></a><b><a href="details.html">OS Information Files:</a></b>     <a href="#top">top</a><hr>
!
OS_FILES=`ls OS/*release OS/*version OS/uname 2>> $LOGDIR/script/misc_err.log`
for FILE in $OS_FILES
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "The files listed above include the OS release version and the running kernel version (uname)." >> $DTL
/bin/echo >> $DTL
OS_FILES=`ls OS/rpm*  2>> $LOGDIR/script/misc_err.log`
for FILE in $OS_FILES
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "The file(s) above include the installed RPMs." >> $DTL
/bin/echo >> $DTL
OS_FILES=`ls OS/ls_* OS/sys_files.tgz  2>> $LOGDIR/script/misc_err.log`
for FILE in $OS_FILES
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "The files above include the output of ls -alRF for /sys and /var/crash as well as a tar/zip" >> $DTL
/bin/echo "of the collected files from /sys." >> $DTL
/bin/echo >> $DTL

#
# Boot files
#
BOOTFILES=`ls boot`
for FILE in $BOOTFILES
do
   /bin/echo -n "<a href=\"boot/$FILE\">boot/$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "The above files include boot configuration files and a list of files in the /boot directory." >> $DTL
/bin/echo >> $DTL

#
# /etc Information
#
cat >> $DTL <<!
<hr><a id="etcfiles"></a><b><a href="details.html">/etc Information:</a></b>     <a href="#top">top</a><hr>
!
ETC_FILES="etc/modprobe.conf etc/modprobe.conf.local etc/modprobe.conf.dist etc/modules.conf etc/modules.conf.local etc/sysconfig/kernel"
for FILE in $ETC_FILES
do
   if [ -f $FILE ]
   then
      /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
   fi
done
/bin/echo >> $DTL
/bin/echo "The files above are used to determine the order modules are loaded, specify optional module parameters," >> $DTL
/bin/echo "and determine which modules are included in the ramdisk image during bootup (SLES uses /etc/sysconfig/kernel)." >> $DTL
/bin/echo >> $DTL

ETC_FILES="etc/qla2xxx.conf etc/qla2300.conf etc/qla2200.conf etc/hba.conf"
ATLEASTONEFILE=0
for FILE in $ETC_FILES
do
   if [ -f $FILE ]
   then
      ATLEASTONEFILE=1
      /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
   fi
done
if [ $ATLEASTONEFILE -eq 1 ]
then
   /bin/echo >> $DTL
   /bin/echo "The file qla*.conf, if present, is used to store an ascii representation of persistent binding and" >> $DTL
   /bin/echo "LUN masking as defined by SANsurfer or scli.  The file hba.conf, if present, points to the proper " >> $DTL
   /bin/echo "dynamic loadable library for the SNIA API (HBAAPI)." >> $DTL
   /bin/echo >> $DTL
fi

ETC_FILES="etc/fstab etc/mtab"
for FILE in $ETC_FILES
do
   if [ -f $FILE ]
   then
      /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
   fi
done
/bin/echo >> $DTL
/bin/echo "The files above identify static and dynamic filesystem mount information." >> $DTL
/bin/echo >> $DTL

/bin/echo -n "<a href=\"etc/ls_etcrcd.out\">etc/ls_etcrcd.out</a>    " >> $DTL
/bin/echo >> $DTL
/bin/echo "Directory listing of all startup files executed at various runlevels at boot/shutdown" >> $DTL
/bin/echo >> $DTL

if [ -f etc/sysctl.conf ]
then
   /bin/echo -n "<a href=\"etc/sysctl.conf\">etc/sysctl.conf</a>    " >> $DTL
   /bin/echo >> $DTL
   /bin/echo "Kernel tuning configuration file." >> $DTL
   /bin/echo >> $DTL
fi

if [ -f etc/sysconfig/hwconf ]
then
   /bin/echo -n "<a href=\"etc/sysconfig/hwconf\">etc/sysconfig/hwconf</a>    " >> $DTL
   /bin/echo >> $DTL
   /bin/echo "List of installed hardware including PCI bus, vendor and driver module information." >> $DTL
   /bin/echo >> $DTL
fi
# DG: Major rework needed to list and describe files that are IB-specific
if [ $IBINSTALLED -eq 1 -a $IBAINSTALLED -eq 0 ]
then
   /bin/echo "Files listed below are additional files gathered for Infiniband troubleshooting." >> $DTL
   /bin/echo >> $DTL
fi

#
# Module Information
#
cat >> $DTL <<!
<hr><a id="modules"></a><b><a href="details.html">Module Information:</a></b>     <a href="#top">top</a><hr>
!
MODFILES="modules/ls_libmodules.out modules/lsmod.out modules/modinfo.out modules/qisioctl.out modules/qioctlmod.out"
for FILE in $MODFILES
do
   if test -f $FILE
   then
      /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
   fi
done
/bin/echo >> $DTL
/bin/echo "The file ls_libmodules.out is a list of all modules for the current running kernel.  The file " >> $DTL
/bin/echo "lsmod.out is a list of all currently loaded modules.  The file modinfo.out is a list of modinfo" >> $DTL
/bin/echo "output of all QLogic modules in the current running kernel." >> $DTL
/bin/echo >> $DTL

#
# /proc Information
#
cat >> $DTL <<!
<hr><a id="procinfo"></a><b><a href="details.html">/proc Information:</a></b>     <a href="#top">top</a><hr>
!
PROCFILES=`ls proc`
for FILE in $PROCFILES
do
   if test -f proc/$FILE
   then
      /bin/echo -n "<a href=\"proc/$FILE\">proc/$FILE</a>    " >> $DTL
   fi
done
/bin/echo >> $DTL
/bin/echo "These files include CPU information, running modules, and (optionally) pci information as     " >> $DTL
/bin/echo "reported in the /proc filesystem.                                                             " >> $DTL
/bin/echo >> $DTL

if test -d proc/scsi
then
   if test -f proc/scsi/scsi
   then
      /bin/echo "<a href=\"proc/scsi/scsi\">proc/scsi/scsi</a>    " >> $DTL
      /bin/echo "This is a list of all devices scanned by the SCSI module as reported in the /proc filesystem. " >> $DTL
      /bin/echo >> $DTL
   fi
   TESTDIR=`ls proc/scsi/|grep qla2`
   if test -n "$TESTDIR"
   then
      for DIR in $TESTDIR
      do
         QLAFILE=`ls proc/scsi/$DIR/[0-9]*`
         for FILE in $QLAFILE
         do
            /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
         done
         /bin/echo >> $DTL
      done
      /bin/echo "QLogic FC driver instance files." >>$DTL
      /bin/echo >> $DTL
   else
      /bin/echo "No QLogic FC driver info found in /proc filesystem." >> $DTL
      /bin/echo >> $DTL
   fi
   TESTDIR=`ls proc/scsi/|grep qla4`
   if test -n "$TESTDIR"
   then
      for DIR in $TESTDIR
      do
         QLAFILE=`ls proc/scsi/$DIR/[0-9]*`
         for FILE in $QLAFILE
         do
            /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
         done
         /bin/echo >> $DTL
      done
      /bin/echo "QLogic iSCSI driver instance files." >>$DTL
      /bin/echo >> $DTL
   else
      /bin/echo "No QLogic iSCSI driver info found in /proc filesystem." >> $DTL
      /bin/echo >> $DTL
   fi
else
   /bin/echo "No SCSI info found in /proc filesystem." >> $DTL
   /bin/echo >> $DTL
fi

#
# Ethernet Information
#
cat >> $DTL <<!
<hr><a id="etherinfo"></a><b><a href="details.html">Ethernet Information:</a></b>     <a href="#top">top</a><hr>
!
/bin/echo -n "<a href=\"network/ifconfig.out\">network/ifconfig.out</a>  " >> $DTL
/bin/echo -n "<a href=\"network/netstat.out\">network/netstat.out</a>  " >> $DTL
/bin/echo "<a href=\"network/iptables.out\">network/iptables.out</a>" >> $DTL
/bin/echo "These files include network interface configurations and interface routing information." >> $DTL
/bin/echo >> $DTL
if test $ETHERINSTALLED -eq 1
then
   QLETHERDRIVER=0
   ETHDEVS=`grep "Link encap" $LOGDIR/network/ifconfig.out | cut -d " " -f1`
   for file in $ETHDEVS
   do
      if test -f $LOGDIR/network/ethtool-i.$file
      then
         QLETHERDRIVER=1    
         /bin/echo -n "<a href=\"network/ifconfig.$file\">network/ifconfig.$file</a>  " >> $DTL
         /bin/echo -n "<a href=\"network/ethtool-i.$file\">network/ethtool-i.$file</a>  " >> $DTL
         /bin/echo -n "<a href=\"network/ethtool-k.$file\">network/ethtool-k.$file</a>  " >> $DTL
         /bin/echo "<a href=\"network/ethtool.$file\">network/ethtool.$file</a>" >> $DTL
      fi
   done
   if test $QLETHERDRIVER -eq 1
   then
      /bin/echo "These files include details about specific QLogic network interfaces." >> $DTL
   else
      /bin/echo "No QLogic ethernet driver information available" >> $DTL
# DG bonding, netxen and vlan stuff goes here.
# Still need to add in the Netxen /proc/net/devX files in the format
# devX/file1 devX/file2 devX/file3 ... devX/file7
# devY/file1 devY/file2 devY/file3 ... devY/file7
# See ts80lx52/dev/sda13 and ts80lx56/dev/sdb1 for script outputs
   fi
else
   /bin/echo "No QLogic Ethernet Adapters Detected in system" >> $DTL
fi 
/bin/echo >> $DTL

#
# QLogic Tools (SANsurfer/CLI) Info
#
cat >> $DTL <<!
<hr><a id="QLogic_tools"></a><b><a href="details.html">QLogic Tools (SANsurfer/CLI) Information:</a></b>     <a href="#top">top</a><hr>
!
SMSINSTALL=`ls QLogic_tools/sansurfer*`
for FILE in $SMSINSTALL
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "SANsurfer GUI installation status and version information" >> $DTL
/bin/echo >> $DTL

SMSINSTALL=`ls QLogic_tools/*scli_install*`
for FILE in $SMSINSTALL
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "SANsurfer CLI installation status and version information" >> $DTL
/bin/echo >> $DTL

SMSLISTS=`ls QLogic_tools/ls_*`
for FILE in $SMSLISTS
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "Directory listing of default SANsurfer GUI/CLI locations" >> $DTL
/bin/echo >> $DTL

if test -f QLogic_tools/scli.out
then
   /bin/echo -n "<a href=\"QLogic_tools/scli.out\">QLogic_tools/scli.out</a>    " >> $DTL
   /bin/echo " scli output for all FC Adapters." >> $DTL
   /bin/echo >> $DTL
fi
if test -f QLogic_tools/iscli.out
then
   /bin/echo -n "<a href=\"QLogic_tools/iscli.out\">QLogic_tools/iscli.out</a>    " >> $DTL
   /bin/echo "iscli output for all iSCSI Adapters." >> $DTL
   /bin/echo >> $DTL
fi

#
# System Log Information
#
cat >> $DTL <<!
<hr><a id="loginfo"></a><b><a href="details.html">System Log Information:</a></b>     <a href="#top">top</a><hr>
!
BOOTFILES=`ls logs/boot*`
for FILE in $BOOTFILES
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "Boot logs" >> $DTL
/bin/echo >> $DTL
MSGFILES=`ls logs/message* 2>> $LOGDIR/script/misc_err.log`
for FILE in $MSGFILES
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "System messages files" >> $DTL
/bin/echo >> $DTL
MSGFILES=`ls logs/* | grep -v "logs/message" | grep -v boot`
for FILE in $MSGFILES
do
   /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
done
/bin/echo >> $DTL
/bin/echo "Other log files" >> $DTL
/bin/echo >> $DTL

#
# Misc Information
#
cat >> $DTL <<!
<hr><a id="miscinfo"></a><b><a href="details.html">Miscellaneous Information:</a></b>     <a href="#top">top</a><hr>
!
/bin/echo -n "<a href=\"misc/fdisk.out\">misc/fdisk.out</a>     " >> $DTL
/bin/echo "<a href=\"misc/df.out\">misc/df.out</a>" >> $DTL
/bin/echo "List of devices recognized by the OS SCSI disk module and list of mounted disks." >> $DTL
/bin/echo >> $DTL
/bin/echo -n "<a href=\"misc/chkconfig.out\">misc/chkconfig.out</a>   " >> $DTL
/bin/echo "System runlevel configuration." >> $DTL
/bin/echo -n "<a href=\"misc/gcc.out\">misc/gcc.out</a>         " >> $DTL
/bin/echo "List of installed gcc binaries and version information." >> $DTL
/bin/echo -n "<a href=\"misc/lspci.out\">misc/lspci.out</a>       " >> $DTL
/bin/echo "List of hardware installed as recognized by <i>lspci -v</i>" >> $DTL
/bin/echo -n "<a href=\"misc/dmidecode.out\">misc/dmidecode.out</a>   " >> $DTL
/bin/echo "Lists Motherboard and BIOS information as recognized by <i>dmidecode</i>" >> $DTL
/bin/echo -n "<a href=\"misc/ps.out\">misc/ps.out</a>          " >> $DTL
/bin/echo "List of all running processes." >> $DTL
/bin/echo -n "<a href=\"misc/uptime.out\">misc/uptime.out</a>      " >> $DTL
/bin/echo "System uptime." >> $DTL
/bin/echo -n "<a href=\"misc/ls_usrlib.out\">misc/ls_usrlib.out</a>   " >> $DTL
/bin/echo "32-bit Loadable libraries" >> $DTL
if test -f misc/ls_usrlib64.out
then
   /bin/echo -n "<a href=\"misc/ls_usrlib64.out\">misc/ls_usrlib64.out</a> " >> $DTL
   /bin/echo "64-bit Loadable libraries" >> $DTL
fi
/bin/echo >> $DTL
OTHERMISCFILES="misc/lsscsi.out misc/lsscsi_verbose.out misc/sysctl.out misc/vmstat.out misc/free.out misc/lsof.out"
for FILE in $OTHERMISCFILES
do
   if test -f $FILE
   then
      /bin/echo -n "<a href=\"$FILE\">$FILE</a>    " >> $DTL
   fi
done
/bin/echo >> $DTL
/bin/echo "Other miscellaneous files listing various system resources." >> $DTL
/bin/echo >> $DTL

#
# Wrap it up
#
cat >> $DTL <<!
<hr><a id="bottom"></a> <a href="#top">top</a><hr> 
<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br> 
</pre> 
</font> 
</body>
!

#####################################################################
# Create compressed archive of results ... then clean up
#####################################################################
/bin/echo -n "Creating compressed archive and cleaning up ... "

cd /tmp
tar czf $LOGNAME.tgz ./$LOGNAME
if test $? -ne 0 
then
   /bin/echo "*!*! Error while archiving the support data."
   /bin/echo "     Please tar and compress $LOGDIR by hand"
   /bin/echo "     and Email it to support@qlogic.com"
else
   rm -rf /tmp/$LOGNAME
   /bin/echo "done"
   /bin/echo
   /bin/echo "Please attach the file: $LOGDIR.tgz to your case at http://support.qlogic.com"
fi

#####################################################################
# All done ...
#####################################################################
exit
