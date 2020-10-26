require 'redis'
require_relative '../lib/redcord'

class Session < T::Struct
  include Redcord::Base

  attribute :view_at, T.nilable(Time), index: true
  attribute :edit_at, T.nilable(Time), index: true
  attribute :resource_id, Integer
  attribute :user_id, Integer, index: true

  custom_index :view_base, [:resource_id, :user_id, :view_at]
  custom_index :edit_base, [:resource_id, :user_id, :edit_at]

  shard_by_attribute :resource_id
end

Session.redis = Redis.new(cluster: ENV.fetch('REDIS_CLUSTER_URLS').split(','))
Session.redis.flushdb
$records = []

def rand_int
  (Random.rand * 100000).to_i
end

def rand_time
  Time.at(Random.rand * 10_000_000_000)
end

module Operation
  def create
    $records << Session.create!(
      edit_at: rand_time,
      resource_id: rand_int,
      user_id: rand_int,
      view_at: rand_time,
    )
  end

  def update
    $records.sample(1)&.first&.update!(
      edit_at: rand_time,
      user_id: rand_int,
      view_at: rand_time,
    )
  rescue Redis::CommandError
  end

  def query_view_at
    Session.find_by(
      resource_id: rand_int,
      view_at: rand_time,
    )
  end

  def query_edit_at
    Session.find_by(
      resource_id: rand_int,
      edit_at: rand_time,
    )
  end

  def query_view_base
    Session.where(
      resource_id: rand_int,
      user_id: rand_int,
      view_at: rand_time,
    ).to_a
  end

  def query_edit_base
    Session.where(
      resource_id: rand_int,
      user_id: rand_int,
      edit_at: rand_time,
    ).to_a
  end

  def query_view_base_with_custom_index
    Session.where(
      resource_id: rand_int,
      user_id: rand_int,
      view_at: rand_time,
    ).with_index(:view_base).to_a
  end

  def query_edit_base_with_custom_index
    Session.where(
      resource_id: rand_int,
      user_id: rand_int,
      edit_at: rand_time,
    ).with_index(:edit_base).to_a
  end

  def delete
    $records.sample(1)&.first&.destroy
  rescue Redis::CommandError
  end
end

include Operation
start = Time.now
times = Hash.new { |h, k| h[k] = 0.0 }
counts = Hash.new { |h, k| h[k] = 0 }

threads = (1..3).map do
  Thread.new do
    Time.zone = 'UTC'
    while (Time.now - start).to_i < 60
      op = Operation.instance_methods.sample(1).first
      t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      send(op)
      t2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      times[op] += t2 - t1
      counts[op] += 1
    end
  end
end

begin
  threads.each(&:join)
ensure
  counts.each { |k, v|
    puts "#{v} x #{k}: avg = #{times[k] / v * 1000}"
  }
end
