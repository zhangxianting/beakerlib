url --url=$tree
key $getVar('key', '49af89414d147589')
auth  --useshadow  --enablemd5
# System bootloader configuration
bootloader --location=mbr
# Use text mode install
text
# Firewall configuration
firewall --enabled
# Run the Setup Agent on first boot
firstboot --disable
# System keyboard
keyboard $getVar('keyboard', 'us')
# System language
lang $getVar('lang','en_us.UTF-8')
$yum_repo_stanza
reboot
#Root password
rootpw --iscrypted $getVar('password', '\$1\$mF86/UHC\$WvcIcX2t6crBz2onWxyac.')
# SELinux configuration
selinux $getVar('selinux','--enforcing')
# Do not configure the X Window System
skipx
# System timezone
timezone  $getVar('timezone', 'America/New_York')
# Install OS instead of upgrade
install
network --bootproto=dhcp

$SNIPPET("main_partition_select")
$SNIPPET("main_packages_select")

%pre
$kickstart_start
$SNIPPET("rhts_pre_partition_select")
$SNIPPET("pre_packages_select")

%post
$yum_config_stanza
$SNIPPET("rhts_post_install_kernel_options")
$SNIPPET("rhts_recipe")
$kickstart_done
