
add_apt_repository "libvirt_backports" do
  url "http://ppa.launchpad.net/ubuntu-virt/ppa/ubuntu"
  key "CE339E50"
  key_server "keyserver.ubuntu.com"
end

include_recipe "master_cap_lxc::ksm"

package "lxc"

template "/usr/lib/lxc/templates/lxc-ubuntu-chef" do
  source "lxc-ubuntu-chef.erb"
  mode '0755'
end

template "/etc/sysctl.d/20-inotify.conf" do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, "service[procps]", :immediately
end