# frozen_string_literal: true
require 'simplecov'
require 'open3'

SimpleCov.start

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

RSpec.configure do |config|
  require 'redcord'

  Time.zone = 'UTC'

  def create_redis_cluster(num_nodes:)
    docker_network = 'redcord_spec_redis_cluster'
    cluster_node_port = 7000

    run_system_command(
      "docker network create #{docker_network}",
      # network maybe already exists
      allow_failure: true,
    )

    node_ips = []

    `docker container ls -a`.split("\n").each do |container|
      container_id = container.match(/(\w*)\s+.*redcord-spec-redis-node-\d+$/)&.send(:[], 1)
      if container_id
        run_system_command(
          "docker container rm #{container_id} -f",
          allow_failure: true,
        )
      end
    end

    File.open('redcord_spec_redis_cluster.config', 'w') do |f|
      f << <<~CONFIG
        port #{cluster_node_port}
        cluster-enabled yes
        cluster-config-file nodes.conf
        cluster-node-timeout 5000
        appendonly yes
      CONFIG
      f.flush


      node_ips = (1..num_nodes).map do |i|
        node_id = "redcord-spec-redis-node-#{i}"
        cmd = <<~CMD
          docker run -d \
            -v #{File.expand_path(f.path)}:/usr/local/etc/redis/redis.conf \
            --name #{node_id} \
            --net #{docker_network} \
            redis redis-server /usr/local/etc/redis/redis.conf
        CMD

        puts run_system_command(
          cmd,
          # network maybe already exists
          allow_failure: true,
        )
        cmd = <<~CMD
          docker inspect \
            -f '{{ (index .NetworkSettings.Networks "#{docker_network}").IPAddress }}' #{node_id}
        CMD
        ip, _ = run_system_command(cmd)
        ip.chomp
      end
      puts "Creating a Redis cluster using nodes: #{node_ips}"

      cmd = <<~CMD
        docker run -i --rm \
          --net #{docker_network} \
          redis sh -c 'redis-cli --cluster create #{
            node_ips.map { |ip| "#{ip}:#{cluster_node_port}" }.join(' ')
          } --cluster-yes'
      CMD
      run_system_command(cmd, allow_failure: true)
    end

    node_ips.map { |ip| "redis://#{ip}:#{cluster_node_port}" }
  end

  def run_system_command(cmd, allow_failure: false)
    puts "> #{cmd}"
    stdout, stderr, status = Open3.capture3(cmd)

    if !allow_failure
      $stderr.puts stderr
    end

    if !status.success? && !allow_failure
      exit status.exitstatus
    end

    [stdout, stderr]
  end

  if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
    $redcord_redis_cluster = create_redis_cluster(num_nodes: 3)
  end

  config.before(:each) do
    if ENV['REDCORD_SPEC_USE_CLUSTER'] == 'true'
      allow(Rails).to receive(:env).and_return('test')
      allow(Redcord::Base).to receive(:configurations).and_return(
        {
          'test' => {
            'default' => {
              'cluster' => $redcord_redis_cluster,
            },
          },
        },
      )
    end

    Redcord::Base.redis.flushdb
    Redcord.establish_connections
  end
end
