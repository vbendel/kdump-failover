Name: 		kdump-failover
Version:	0.3
Release:	1%{?dist}
Summary:	Service exteding kdump's functionality to be able to specify a backup target in case of primary failure
URL:		https://github.com/vbendel/kdump-failover
License:	GPLv3+

%description
Kdump-failover is a simple bunch of scripts that are made to extend kdump's functionality so that a backup target can be specified in case of primary failure (currently kdump supports only failover to rootfs). It is specifically meant to be used when primary target is some storage over network (ex. NFS) and the backup should be some local disk/lvm.

%prep
rm -rf $RPM_BUILD_DIR/*
tar xf $RPM_SOURCE_DIR/kdump-failover.tar.gz


%install

install -d -m 755 $RPM_BUILD_ROOT/etc/
install -m 644 $RPM_BUILD_DIR/kdump-failover/kdump-failover.conf $RPM_BUILD_ROOT/etc/kdump-failover.conf
install -d -m 755 $RPM_BUILD_ROOT/var/crash/scripts
install -m 755 $RPM_BUILD_DIR/kdump-failover/kdump-post-local-failover.sh $RPM_BUILD_ROOT/var/crash/scripts/kdump-post-local-failover.sh
install -d -m 755 $RPM_BUILD_ROOT/usr/bin
install -m 755 $RPM_BUILD_DIR/kdump-failover/kdump-failover-config-generator.sh $RPM_BUILD_ROOT/usr/bin/kdump-failover-config-generator.sh
install -d -m 755 $RPM_BUILD_ROOT/etc/init.d/
install -m 755 $RPM_BUILD_DIR/kdump-failover/kdump-failover.init $RPM_BUILD_ROOT/etc/init.d/kdump-failover

%post
chkconfig --add kdump-failover

%files

%defattr(-,root,root,-)

/etc/kdump-failover.conf
/usr/bin/kdump-failover-config-generator.sh
/var/crash/scripts/kdump-post-local-failover.sh
/etc/init.d/kdump-failover

%preun
chkconfig --del kdump-failover
