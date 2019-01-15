
%define __jar_repack %{nil}
%define debug_package %{nil}
%define tomcat_home /usr/share/tomcat9
%define tomcat_group tomcat9
%define tomcat_user tomcat9

# distribution specific definitions
%define use_systemd (0%{?fedora} && 0%{?fedora} >= 18) || (0%{?rhel} && 0%{?rhel} >= 7)

%if 0%{?rhel}  == 6
Requires(pre): shadow-utils
Requires: initscripts >= 8.36
Requires(post): chkconfig
%endif

%if 0%{?rhel}  == 7
Requires(pre): shadow-utils
Requires: systemd
BuildRequires: systemd
%endif

%if 0%{?fedora} >= 18
Requires(pre): shadow-utils
Requires: systemd
BuildRequires: systemd
%endif

# end of distribution specific definitions

%global provider                apache.mediamirrors
%global provider_tld            org
%global project                 tomcat
%global project_repo            tomcat-9
#main url for tomcat9 source : http://apache.mediamirrors.org/tomcat/tomcat-9/v9.0.14/bin/apache-tomcat-9.0.14.tar.gz


Summary:    Apache Servlet/JSP Engine
Name:       tomcat9
Version:    9.0.14
Release:    1%{?dist}
BuildArch:  x86_64
License:    Apache License version 2
Group:      Applications/Internet
URL:        http://tomcat.apache.org/
Vendor:     Apache Software Foundation
Packager:   Sjir Bagmeijer <sjir.bagmeijer@ulyaoth.com>
Source0:    http://%{provider}.%{provider_tld}/%{project}/%{project_repo}/v%{version}/bin/apache-tomcat-%{version}.tar.gz
Source1:    tomcat9.service
Source2:    tomcat9.init
Source3:    tomcat9.logrotate
Source4:    tomcat9.conf
Source5:    tomcat9.default
BuildRoot:  %{_tmppath}/tomcat-%{version}-%{release}-root-%(%{__id_u} -n)

Provides: tomcat
Provides: tomcat9
Provides: apache-tomcat
Provides: ulyaoth-tomcat
Provides: ulyaoth-tomcat9

%description
Apache Tomcat is an open source software implementation of the Java Servlet and JavaServer Pages technologies. The Java Servlet and JavaServer Pages specifications are developed under the Java Community Process.

Apache Tomcat is developed in an open and participatory environment and released under the Apache License version 2. Apache Tomcat is intended to be a collaboration of the best-of-breed developers from around the world. We invite you to participate in this open development project. To learn more about getting involved, click here.

Apache Tomcat powers numerous large-scale, mission-critical web applications across a diverse range of industries and organizations. Some of these users and their stories are listed on the PoweredBy wiki page.

Apache Tomcat, Tomcat, Apache, the Apache feather, and the Apache Tomcat project logo are trademarks of the Apache Software Foundation.

%prep
%setup -q -n apache-tomcat-%{version}

%build

%install
install -d -m 755 %{buildroot}/%{tomcat_home}/
cp -R * %{buildroot}/%{tomcat_home}/

# Put logging in /var/log and link back.
rm -rf %{buildroot}/%{tomcat_home}/logs
install -d -m 755 %{buildroot}/var/log/tomcat9/
cd %{buildroot}/%{tomcat_home}/
ln -s /var/log/tomcat9/ logs
cd -

# Copy files in appropriate directories
install -d -m 755 %{buildroot}/etc/tomcat9/
cp -R %{buildroot}/%{tomcat_home}/conf/* %{buildroot}/etc/tomcat9/
rm -rf %{buildroot}/%{tomcat_home}/conf
cd %{buildroot}/%{tomcat_home}/
ln -s /etc/tomcat9/ conf
cd -

install -d -m 755 %{buildroot}/var/cache/tomcat9/temp/
cp -R %{buildroot}/%{tomcat_home}/temp/* %{buildroot}/var/cache/tomcat9/temp/
rm -rf %{buildroot}/%{tomcat_home}/temp
cd %{buildroot}/%{tomcat_home}/
ln -s /var/cache/tomcat9/temp/ temp
cd -

install -d -m 755 %{buildroot}/var/lib/tomcat9/webapps
#cp -R %{buildroot}/%{tomcat_home}/webapps/* %{buildroot}/var/lib/tomcat9/webapps
rm -rf %{buildroot}/%{tomcat_home}/webapps
cd %{buildroot}/%{tomcat_home}/
ln -s /var/lib/tomcat9/webapps/ webapps
cd -

install -d -m 755 %{buildroot}/var/cache/tomcat9/work
#cp -R %{buildroot}/%{tomcat_home}/work/* %{buildroot}/var/cache/tomcat9/work
rm -rf %{buildroot}/%{tomcat_home}/work
cd %{buildroot}/%{tomcat_home}/
ln -s /var/cache/tomcat9/work/ work
cd -

%if %{use_systemd}
# install systemd-specific files
%{__mkdir} -p $RPM_BUILD_ROOT%{_unitdir}
%{__install} -m644 %SOURCE1 \
        $RPM_BUILD_ROOT%{_unitdir}/tomcat9.service
%else
# install SYSV init stuff
%{__mkdir} -p $RPM_BUILD_ROOT%{_initrddir}
%{__install} -m755 %{SOURCE2} \
   $RPM_BUILD_ROOT%{_initrddir}/tomcat
%endif

# install log rotation stuff
%{__mkdir} -p $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d
%{__install} -m 644 -p %{SOURCE3} \
   $RPM_BUILD_ROOT%{_sysconfdir}/logrotate.d/tomcat9

# install sysconfig stuff
%{__mkdir} -p $RPM_BUILD_ROOT%{_sysconfdir}/tomcat9
%{__install} -m 644 -p %{SOURCE4} \
   $RPM_BUILD_ROOT%{_sysconfdir}/tomcat9/tomcat9.conf

# install sysconfig stuff
%{__mkdir} -p $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig
%{__install} -m 644 -p %{SOURCE5} \
   $RPM_BUILD_ROOT%{_sysconfdir}/sysconfig/tomcat9

# Clean webapps
%{__rm} -rf %{buildroot}/%{tomcat_home}/webapps/*

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%pre
getent group %{tomcat_group} >/dev/null || groupadd -r %{tomcat_group}
getent passwd %{tomcat_user} >/dev/null || /usr/sbin/useradd --comment "Tomcat Daemon User" --shell /bin/bash -M -r -g %{tomcat_group} --home %{tomcat_home} %{tomcat_user}


%files
%defattr(-,%{tomcat_user},%{tomcat_group})
%{tomcat_home}/*
%{_localstatedir}/lib/tomcat9/*
%{_localstatedir}/cache/tomcat9/*
%dir %{tomcat_home}
%dir %{_localstatedir}/log/tomcat9
%dir %{_localstatedir}/lib/tomcat9
%dir %{_localstatedir}/cache/tomcat9
%dir %{_sysconfdir}/tomcat9/ 
%config(noreplace) %{_sysconfdir}/tomcat9/web.xml
%config(noreplace) %{_sysconfdir}/tomcat9/tomcat-users.xml
%config(noreplace) %{_sysconfdir}/tomcat9/tomcat-users.xsd
%config(noreplace) %{_sysconfdir}/tomcat9/server.xml
%config(noreplace) %{_sysconfdir}/tomcat9/logging.properties
%config(noreplace) %{_sysconfdir}/tomcat9/context.xml
%config(noreplace) %{_sysconfdir}/tomcat9/catalina.properties
%config(noreplace) %{_sysconfdir}/tomcat9/catalina.policy
%config(noreplace) %{_sysconfdir}/tomcat9/tomcat9.conf
%config(noreplace) %{_sysconfdir}/tomcat9/jaspic-providers.xml
%config(noreplace) %{_sysconfdir}/tomcat9/jaspic-providers.xsd



%defattr(-,root,root)
%config(noreplace) %{_sysconfdir}/logrotate.d/tomcat9
%config(noreplace) %{_sysconfdir}/sysconfig/tomcat9
%if %{use_systemd}
%{_unitdir}/tomcat9.service
%else
%{_initrddir}/tomcat9
%endif


%post
# Register the tomcat service
if [ $1 -eq 1 ]; then
%if %{use_systemd}
    /usr/bin/systemctl preset tomcat9.service >/dev/null 2>&1 ||:
%else
    /sbin/chkconfig --add tomcat9
%endif

cat <<BANNER
----------------------------------------------------------------------

Thank you for using ulyaoth-tomcat9!

Please find the official documentation for tomcat here:
* http://tomcat.apache.org/

For any additional information or help regarding this rpm:
Website: https://ulyaoth.com
Forum: https://community.ulyaoth.com

----------------------------------------------------------------------
BANNER
fi

%preun
if [ $1 -eq 0 ]; then
%if %use_systemd
    /usr/bin/systemctl --no-reload disable tomcat9.service >/dev/null 2>&1 ||:
    /usr/bin/systemctl stop tomcat9.service >/dev/null 2>&1 ||:
%else
    /sbin/service tomcat9 stop > /dev/null 2>&1
    /sbin/chkconfig --del tomcat9
%endif
fi

%postun
%if %use_systemd
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 ||:
%endif
if [ $1 -ge 1 ]; then
    /sbin/service tomcat9 status  >/dev/null 2>&1 || exit 0
fi

%changelog
* Thu Jan 10 2019 bob  <lapin@lapin.net> 9.0.14-1
- Updating to Tomcat 9.0.14 and Adaptation for meetic group path and specs

* Mon Nov 12 2018 Sjir Bagmeijer <sjir.bagmeijer@ulyaoth.com> 9.0.13-1
- Updating to Tomcat 9.0.13.

* Fri Nov 9 2018 Sjir Bagmeijer <sjir.bagmeijer@ulyaoth.com> 9.0.12-1
- Updating to Tomcat 9.0.12.

* Wed May 23 2018 Sjir Bagmeijer <sjir.bagmeijer@ulyaoth.net> 9.0.8-1
- Updating to Tomcat 9.0.8.

* Fri Jan 5 2018 Sjir Bagmeijer <sjir.bagmeijer@ulyaoth.net> 9.0.2-1
- Updating to Tomcat 9.0.2.

* Wed Nov 15 2017 Sjir Bagmeijer <sjir.bagmeijer@ulyaoth.net> 9.0.1-1
- Updating to Tomcat 9.0.1.

* Sat Jul 1 2017 Sjir Bagmeijer <sjir.bagmeijer@ulyaoth.net> 9.0.0-15
- Updating to Tomcat 9.0.0.M22.

* Sat May 20 2017 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-14
- Updating to Tomcat 9.0.0.M21.

* Sat Apr 22 2017 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-13
- Updating to Tomcat 9.0.0.M20.

* Sat Apr 8 2017 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-12
- Updating to Tomcat 9.0.0.M19.

* Fri Mar 17 2017 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-11
- Updating to Tomcat 9.0.0.M18.

* Mon Feb 13 2017 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-10
- Updating to Tomcat 9.0.0.M17.

* Sun Nov 13 2016 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-9
- Updating to Tomcat 9.0.0.M13.

* Sat Oct 15 2016 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-8
- Updating to Tomcat 9.0.0.M11.

* Sat Sep 10 2016 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-7
- Updating to Tomcat 9.0.0.M10.

* Tue Jul 19 2016 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-6
- Updating to Tomcat 9.0.0.M9.

* Thu Jun 16 2016 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-5
- Updating to Tomcat 9.0.0.M8.

* Sat May 21 2016 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-4
- Updating to Tomcat 9.0.0.M6.

* Fri Mar 18 2016 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-3
- Updating to Tomcat 9.0.0.M4.

* Fri Feb 12 2016 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-2
- Updating to Tomcat 9.0.0.M3.

* Sat Nov 28 2015 Sjir Bagmeijer <sbagmeijer@ulyaoth.net> 9.0.0-1
- Initial release for Tomcat 9.0.0.M1.
