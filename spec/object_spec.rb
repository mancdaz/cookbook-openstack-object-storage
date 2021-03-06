# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::object-server' do
  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @node.set['openstack']['object-storage']['disk_enum_expr'] = "[{ 'sda' => {}}]"
      @node.set['openstack']['object-storage']['disk_test_filter'] = [
        'candidate =~ /sd[^a]/ or candidate =~ /hd[^a]/ or candidate =~ /vd[^a]/ or candidate =~ /xvd[^a]/',
        "File.exist?('/dev/' + candidate)",
        "not system('/sbin/parted /dev/' + candidate + ' -s print | grep linux-swap')",
        "not info.has_key?('removable') or info['removable'] == 0.to_s"]

      # mock out an interface on the storage node
      @node.set['network'] = MOCK_NODE_NETWORK_DATA['network']

      @chef_run.converge 'openstack-object-storage::object-server'
    end

    it 'installs swift packages' do
      expect(@chef_run).to install_package 'swift-object'
    end

    it 'starts swift object services on boot' do
      %w{swift-object swift-object-replicator swift-object-auditor swift-object-updater}.each do |svc|
        expect(@chef_run).to enable_service(svc)
      end
    end

    describe '/var/spool/crontab/root' do

      it 'template contents' do
        pending 'TODO: check for recon script'
      end

    end

    describe '/etc/swift/object-server.conf' do

      before do
        @file = @chef_run.template '/etc/swift/object-server.conf'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('swift')
        expect(@file.group).to eq('swift')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '600'
      end

      { 'bind_ip' => '0.0.0.0',
        'bind_port' => '6000',
        'log_statsd_default_sample_rate' => '1',
        'log_statsd_metric_prefix' => 'openstack.swift.Fauxhai' }.each do |k, v|
        it "sets the #{k}" do
          expect(@chef_run).to render_file(@file.name).with_content(/^#{Regexp.quote("#{k} = #{v}")}$/)
        end
      end

    end

  end

end
