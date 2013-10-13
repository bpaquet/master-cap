
package "sysfsutils"

service "sysfsutils" do
  supports :status => true, :restart => true
  action [:nothing]
end

template "/etc/sysfs.conf" do
  source "sysfs.conf.erb"
  mode "0644"
  notifies :restart, "service[sysfsutils]"
end

