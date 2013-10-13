
require 'master-cap/hypervisors/base'
require 'master-cap/hypervisors/ssh_helper'

class HypervisorLxc < Hypervisor

  include SshHelper

  def initialize(cap, params)
    super(cap, params)
    @params = params
    [:lxc_user, :lxc_host, :lxc_sudo].each do |x|
      raise "Missing params :#{x}" unless @params[x]
    end
    @ssh = SshDriver.new @params[:lxc_host], @params[:lxc_user], @params[:lxc_sudo]
  end

  def read_list
    @ssh.capture("lxc-ls").split("\n")
  end

  def start_vms l, no_dry
    return unless no_dry
    l.each do |name, vm|
      puts "Starting #{name}"
      @ssh.exec "lxc-start -d -n #{name}"
      wait_ssh vm[:hostname], @cap.fetch(:user)
    end
  end

  def stop_vms l, no_dry
    return unless no_dry
    l.each do |name, vm|
      puts "Stopping #{name}"
      @ssh.exec "lxc-stop -n #{name}"
    end
  end

  def create_vms l, no_dry
    return unless no_dry
    l.each do |name, vm|
      ip_config = vm[:host_ips][:admin]
      template_name = vm[:vm][:template_name] || @params[:default_vm][:template_name]
      template_opts = vm[:vm][:template_opts] || @params[:default_vm][:template_opts] || ""
      raise "No template specified for vm #{name}" unless template_name
      puts "Creating #{name}, using template #{template_name}, options #{template_opts}"
      network_gateway = vm[:vm][:network_gateway] || @params[:default_vm][:network_gateway] || @ssh.capture("/bin/sh -c '. /etc/default/lxc && echo \\$LXC_ADDR'").strip
      network_netmask = vm[:vm][:network_netmask] || @params[:default_vm][:network_netmask] || @ssh.capture("/bin/sh -c '. /etc/default/lxc && echo \\$LXC_NETMASK'").strip
      network_bridge = vm[:vm][:network_bridge] || @params[:default_vm][:network_bridge] || @ssh.capture("/bin/sh -c '. /etc/default/lxc && echo \\$LXC_BRIDGE'").strip
      network_dns = vm[:vm][:network_dns] || @params[:default_vm][:network_dns] || network_gateway
      puts "Network config for #{name} : #{ip_config[:ip]} / #{network_netmask}, gateway #{network_gateway}, bridge #{network_bridge}, dns #{network_dns}"

      ssh_keys = []
      ssh_keys += @params[:default_vm][:ssh_keys] if @params[:default_vm][:ssh_keys]
      ssh_keys += vm[:vm][:ssh_keys] if vm[:vm][:ssh_keys]

      lvm_mode = vm[:vm][:lvm] || @params[:default_vm][:lvm]

      if lvm_mode
        lvm_vg = vm[:vm][:lvm][:vg_name] || @params[:default_vm][:lvm][:vg_name]
        lvm_size = vm[:vm][:lvm][:root_size] || @params[:default_vm][:lvm][:root_size]
        raise "No vg for #{name}" unless lvm_vg
        raise "No size for #{name}" unless lvm_size
      end

      user = @cap.fetch(:user)

      iface = <<-EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address #{ip_config[:ip]}
  netmask #{network_netmask}
  gateway #{network_gateway}
EOF

      config = []

      config << "lxc.network.type = veth"
      config << "lxc.network.link = #{network_bridge}"
      config << "lxc.network.flags = up"
      config << ""
      config << "lxc.cgroup.memory.limit_in_bytes = #{vm[:vm][:memory]}" if vm[:vm][:memory]
      config << "lxc.cgroup.memory.memsw.limit_in_bytes = #{vm[:vm][:memory_swap]}" if vm[:vm][:memory_swap]
      config << "lxc.cgroup.cpu.shares = #{vm[:vm][:cpu_shares]}" if vm[:vm][:cpu_shares]
      config << ""
      config << ""
      @ssh.scp "/tmp/lxc_config", config.join("\n")
      command = "lxc-create -t #{template_name} -n #{name} -f /tmp/lxc_config"
      command += " -B lvm --vgname #{lvm_vg} --fssize #{lvm_size}" if lvm_mode
      command += " -- #{template_opts}"
      puts command
      @ssh.exec command
      @ssh.exec "mount /dev/#{lvm_vg}/#{name} /var/lib/lxc/#{name}/rootfs" if lvm_mode
      @ssh.exec "rm -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host*key*"
      @ssh.exec "ssh-keygen -t rsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_rsa_key -C root@#{name} -N '' -q "
      @ssh.exec "ssh-keygen -t dsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_dsa_key -C root@#{name} -N '' -q "
      @ssh.exec "ssh-keygen -t ecdsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_ecdsa_key -C root@#{name} -N '' -q"

      @ssh.scp "/var/lib/lxc/#{name}/rootfs/etc/network/interfaces", iface
      @ssh.exec "rm /var/lib/lxc/#{name}/rootfs/etc/resolv.conf"
      @ssh.exec "echo nameserver #{network_dns} | sudo tee /var/lib/lxc/#{name}/rootfs/etc/resolv.conf"

      # @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs userdel ubuntu"
      # @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs rm -rf /home/ubuntu"

      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs useradd #{user} --shell /bin/bash --create-home --home /home/#{user}"
      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs mkdir /home/#{user}/.ssh"
      @ssh.scp "/var/lib/lxc/#{name}/rootfs/home/#{user}/.ssh/authorized_keys", ssh_keys.join("\n")
      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs chown -R #{user} /home/#{user}/.ssh"
      @ssh.exec "echo 'chef   ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /var/lib/lxc/#{name}/rootfs/etc/sudoers"

      @ssh.exec "umount /dev/#{lvm_vg}/#{name}" if lvm_mode
      @ssh.exec "rm /tmp/lxc_config"
      @ssh.exec "lxc-start -d -n #{name}"
      @ssh.exec "ln -s /var/lib/lxc/#{name}/config /etc/lxc/auto/#{name}"
      wait_ssh ip_config[:ip], user
    end
  end

  def delete_vms l, no_dry
    return unless no_dry
    l.each do |name, vm|
      puts "Deleting #{name}"
      @ssh.exec "lxc-stop -n #{name}"
      @ssh.exec "lxc-destroy -n #{name}"
      @ssh.exec "rm -f /etc/lxc/auto/#{name}"
    end
  end

end