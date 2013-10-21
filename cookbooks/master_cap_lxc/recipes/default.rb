
add_apt_repository "stgraber" do
  url "http://ppa.launchpad.net/stgraber/stgraber.net/ubuntu"
  key "0E7716B13"
  key_server "keyserver.ubuntu.com"
end

include_recipe "master_cap_lxc::ksm"

package "lxc"

template "/usr/share/lxc/templates/lxc-ubuntu-chef" do
  source "lxc-ubuntu-chef.erb"
  mode '0755'
  variables node.master_cap_lxc
end

template "/etc/sysctl.d/20-inotify.conf" do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :restart, "service[procps]", :immediately
end