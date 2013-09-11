
require 'master-cap/hypervisors/base'
require 'master-cap/hypervisors/ssh_helper'

class HypervisorLxc < Hypervisor

  include SshHelper

  def initialize(cap, params)
    super(cap, params)
    @params = params
    [:lxc_user, :lxc_host, :lxc_sudo, :template_name, :template_ip].each do |x|
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
      puts "Creating #{name}"
      @ssh.exec "lxc-clone -o #{@params[:template_name]} -n #{name}"
      @ssh.exec "sed -ie 's/#{@params[:template_ip]}/#{vm[:ip]}/' /var/lib/lxc/#{name}/rootfs/etc/network/interfaces"
      @ssh.exec "rm -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host*key*"
      @ssh.exec "ssh-keygen -t rsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_rsa_key -N ''"
      @ssh.exec "ssh-keygen -t dsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_dsa_key -N ''"
      @ssh.exec "ssh-keygen -t ecdsa -f /var/lib/lxc/#{name}/rootfs/etc/ssh/ssh_host_ecdsa_key -N ''"
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