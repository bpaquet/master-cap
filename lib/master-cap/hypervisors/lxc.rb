
require 'master-cap/hypervisors/base'
require 'master-cap/hypervisors/ssh_helper'

class HypervisorLxc < Hypervisor

  include SshHelper

  def initialize(cap, params)
    super(cap, params)
    @params = params
    [:lxc_user, :lxc_host, :lxc_sudo, :template, :vg_name, :ssh_keys].each do |x|
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
      puts "Creating #{name} (#{vm[:ip]})"
      gateway = @ssh.capture("/bin/sh -c '. /etc/default/lxc && echo \\$LXC_ADDR'").strip
      netmask = @ssh.capture("/bin/sh -c '. /etc/default/lxc && echo \\$LXC_NETMASK'").strip

      iface = <<-EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address #{vm[:ip]}
  netmask #{netmask}
  gateway #{gateway}
EOF
      @ssh.scp "/tmp/iface", iface

      config = []
      config << "lxc.cgroup.memory.limit_in_bytes = #{vm[:vm][:memory]}" if vm[:vm][:memory]
      config << "lxc.cgroup.memory.memsw.limit_in_bytes = #{vm[:vm][:memory_swap]}" if vm[:vm][:memory_swap]
      config << "lxc.cgroup.cpu.shares = #{vm[:vm][:cpu_shares]}" if vm[:vm][:cpu_shares]
      config << ""
      @ssh.scp "/tmp/config", config.join("\n")
      command = "lxc-create -t #{@params[:template]} -n #{name} -B lvm --vgname #{@params[:vg_name]}"
      command += " --fssize #{vm[:vm][:root_disk]}"
      @ssh.exec command
      @ssh.exec "cat /tmp/config | sudo tee -a /var/lib/lxc/#{name}/config"
      @ssh.exec "mount /dev/#{@params[:vg_name]}/#{name} /var/lib/lxc/#{name}/rootfs"
      @ssh.exec "rm -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host*key*"
      @ssh.exec "ssh-keygen -t rsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_rsa_key -C root@#{name} -N ''"
      @ssh.exec "ssh-keygen -t dsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_dsa_key -C root@#{name} -N ''"
      @ssh.exec "ssh-keygen -t ecdsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_ecdsa_key -C root@#{name} -N ''"

      @ssh.exec "cp /tmp/iface /var/lib/lxc/#{name}/rootfs/etc/network/interfaces"
      @ssh.exec "rm /var/lib/lxc/#{name}/rootfs/etc/resolv.conf"
      @ssh.exec "echo nameserver #{gateway} | sudo tee /var/lib/lxc/#{name}/rootfs/etc/resolv.conf"

      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs userdel ubuntu"
      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs rm -rf /home/ubuntu"

      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs useradd #{@cap.fetch(:user)} --shell /bin/bash --create-home --home /home/#{@cap.fetch(:user)}"
      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs mkdir /home/#{@cap.fetch(:user)}/.ssh"
      @ssh.scp "/var/lib/lxc/#{name}/rootfs/home/#{@cap.fetch(:user)}/.ssh/authorized_keys", @params[:ssh_keys].join("\n")
      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs chown -R #{@cap.fetch(:user)} /home/#{@cap.fetch(:user)}/.ssh"
      @ssh.exec "echo 'chef   ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /var/lib/lxc/#{name}/rootfs/etc/sudoers"

      @ssh.exec "chroot /var/lib/lxc/#{name}/rootfs apt-get install curl -y"

      @ssh.exec "umount /dev/#{@params[:vg_name]}/#{name}"
      @ssh.exec "rm /tmp/config"
      @ssh.exec "rm /tmp/iface"
      @ssh.exec "lxc-start -d -n #{name}"
      @ssh.exec "ln -s /var/lib/lxc/#{name}/config /etc/lxc/auto/#{name}"
      wait_ssh vm[:ip], @cap.fetch(:user)
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