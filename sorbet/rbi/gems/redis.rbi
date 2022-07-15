# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi gems

# typed: ignore
#
# If you would like to make changes to this file, great! Please create the gem's shim here:
#
#   https://github.com/sorbet/sorbet-typed/new/master?filename=lib/redis/all/redis.rbi
#
# redis-4.7.1

class Redis
  def _client; end
  def _subscription(method, timeout, channels, block); end
  def close; end
  def commit; end
  def connected?; end
  def connection; end
  def disconnect!; end
  def dup; end
  def id; end
  def initialize(options = nil); end
  def inspect; end
  def multi(&block); end
  def pipelined(&block); end
  def queue(*command); end
  def self.current; end
  def self.current=(redis); end
  def self.deprecate!(message); end
  def self.exists_returns_integer; end
  def self.exists_returns_integer=(value); end
  def self.raise_deprecations; end
  def self.raise_deprecations=(arg0); end
  def self.silence_deprecations; end
  def self.silence_deprecations=(arg0); end
  def send_blocking_command(command, timeout, &block); end
  def send_command(command, &block); end
  def synchronize; end
  def with; end
  def with_reconnect(val = nil, &blk); end
  def without_reconnect(&blk); end
  include Redis::Commands
end
class Redis::BaseError < RuntimeError
end
class Redis::ProtocolError < Redis::BaseError
  def initialize(reply_type); end
end
class Redis::CommandError < Redis::BaseError
end
class Redis::BaseConnectionError < Redis::BaseError
end
class Redis::CannotConnectError < Redis::BaseConnectionError
end
class Redis::ConnectionError < Redis::BaseConnectionError
end
class Redis::TimeoutError < Redis::BaseConnectionError
end
class Redis::InheritedError < Redis::BaseConnectionError
end
class Redis::InvalidClientOptionError < Redis::BaseError
end
class Redis::Cluster
  def _scan(command, &block); end
  def assign_asking_node(err_msg); end
  def assign_node(command); end
  def assign_redirection_node(err_msg); end
  def call(command, &block); end
  def call_loop(command, timeout = nil, &block); end
  def call_pipeline(pipeline); end
  def call_with_timeout(command, timeout, &block); end
  def call_without_timeout(command, &block); end
  def connected?; end
  def connection_info; end
  def db; end
  def db=(_db); end
  def disconnect; end
  def fetch_cluster_info!(option); end
  def fetch_command_details(nodes); end
  def find_node(node_key); end
  def find_node_key(command, primary_only: nil); end
  def id; end
  def initialize(options = nil); end
  def process(commands, &block); end
  def send_client_command(command, &block); end
  def send_cluster_command(command, &block); end
  def send_command(command, &block); end
  def send_config_command(command, &block); end
  def send_memory_command(command, &block); end
  def send_pubsub_command(command, &block); end
  def send_script_command(command, &block); end
  def timeout; end
  def try_send(node, method_name, *args, retry_count: nil, &block); end
  def update_cluster_info!(node_key = nil); end
  def with_reconnect(val = nil, &block); end
end
class Redis::Cluster::InitialSetupError < Redis::BaseError
  def initialize(errors); end
end
class Redis::Cluster::OrchestrationCommandNotSupported < Redis::BaseError
  def initialize(command, subcommand = nil); end
end
class Redis::Cluster::CommandErrorCollection < Redis::BaseError
  def errors; end
  def initialize(errors, error_message = nil); end
end
class Redis::Cluster::AmbiguousNodeError < Redis::BaseError
  def initialize(command); end
end
class Redis::Cluster::CrossSlotPipeliningError < Redis::BaseError
  def initialize(keys); end
end
module Redis::Commands
  def call(*command); end
  def method_missing(*command); end
  def sentinel(subcommand, *args); end
  include Redis::Commands::Bitmaps
  include Redis::Commands::Cluster
  include Redis::Commands::Connection
  include Redis::Commands::Geo
  include Redis::Commands::Hashes
  include Redis::Commands::HyperLogLog
  include Redis::Commands::Keys
  include Redis::Commands::Lists
  include Redis::Commands::Pubsub
  include Redis::Commands::Scripting
  include Redis::Commands::Server
  include Redis::Commands::Sets
  include Redis::Commands::SortedSets
  include Redis::Commands::Streams
  include Redis::Commands::Strings
  include Redis::Commands::Transactions
end
module Redis::Commands::Bitmaps
  def bitcount(key, start = nil, stop = nil); end
  def bitop(operation, destkey, *keys); end
  def bitpos(key, bit, start = nil, stop = nil); end
  def getbit(key, offset); end
  def setbit(key, offset, value); end
end
module Redis::Commands::Cluster
  def asking; end
  def cluster(subcommand, *args); end
end
module Redis::Commands::Connection
  def auth(*args); end
  def echo(value); end
  def ping(message = nil); end
  def quit; end
  def select(db); end
end
module Redis::Commands::Geo
  def _geoarguments(*args, options: nil, sort: nil, count: nil); end
  def geoadd(key, *member); end
  def geodist(key, member1, member2, unit = nil); end
  def geohash(key, member); end
  def geopos(key, member); end
  def georadius(*args, **geoptions); end
  def georadiusbymember(*args, **geoptions); end
end
module Redis::Commands::Hashes
  def hdel(key, *fields); end
  def hexists(key, field); end
  def hget(key, field); end
  def hgetall(key); end
  def hincrby(key, field, increment); end
  def hincrbyfloat(key, field, increment); end
  def hkeys(key); end
  def hlen(key); end
  def hmget(key, *fields, &blk); end
  def hmset(key, *attrs); end
  def hrandfield(key, count = nil, withvalues: nil, with_values: nil); end
  def hscan(key, cursor, **options); end
  def hscan_each(key, **options, &block); end
  def hset(key, *attrs); end
  def hsetnx(key, field, value); end
  def hvals(key); end
  def mapped_hmget(key, *fields); end
  def mapped_hmset(key, hash); end
end
module Redis::Commands::HyperLogLog
  def pfadd(key, member); end
  def pfcount(*keys); end
  def pfmerge(dest_key, *source_key); end
end
module Redis::Commands::Keys
  def _exists(*keys); end
  def _scan(command, cursor, args, match: nil, count: nil, type: nil, &block); end
  def copy(source, destination, db: nil, replace: nil); end
  def del(*keys); end
  def dump(key); end
  def exists(*keys); end
  def exists?(*keys); end
  def expire(key, seconds); end
  def expireat(key, unix_time); end
  def keys(pattern = nil); end
  def migrate(key, options); end
  def move(key, db); end
  def object(*args); end
  def persist(key); end
  def pexpire(key, milliseconds); end
  def pexpireat(key, ms_unix_time); end
  def pttl(key); end
  def randomkey; end
  def rename(old_name, new_name); end
  def renamenx(old_name, new_name); end
  def restore(key, ttl, serialized_value, replace: nil); end
  def scan(cursor, **options); end
  def scan_each(**options, &block); end
  def sort(key, by: nil, limit: nil, get: nil, order: nil, store: nil); end
  def ttl(key); end
  def type(key); end
  def unlink(*keys); end
end
module Redis::Commands::Lists
  def _bpop(cmd, args, &blk); end
  def _normalize_move_wheres(where_source, where_destination); end
  def blmove(source, destination, where_source, where_destination, timeout: nil); end
  def blpop(*args); end
  def brpop(*args); end
  def brpoplpush(source, destination, deprecated_timeout = nil, timeout: nil); end
  def lindex(key, index); end
  def linsert(key, where, pivot, value); end
  def llen(key); end
  def lmove(source, destination, where_source, where_destination); end
  def lpop(key, count = nil); end
  def lpush(key, value); end
  def lpushx(key, value); end
  def lrange(key, start, stop); end
  def lrem(key, count, value); end
  def lset(key, index, value); end
  def ltrim(key, start, stop); end
  def rpop(key, count = nil); end
  def rpoplpush(source, destination); end
  def rpush(key, value); end
  def rpushx(key, value); end
end
module Redis::Commands::Pubsub
  def psubscribe(*channels, &block); end
  def psubscribe_with_timeout(timeout, *channels, &block); end
  def publish(channel, message); end
  def pubsub(subcommand, *args); end
  def punsubscribe(*channels); end
  def subscribe(*channels, &block); end
  def subscribe_with_timeout(timeout, *channels, &block); end
  def subscribed?; end
  def unsubscribe(*channels); end
end
module Redis::Commands::Scripting
  def _eval(cmd, args); end
  def eval(*args); end
  def evalsha(*args); end
  def script(subcommand, *args); end
end
module Redis::Commands::Server
  def bgrewriteaof; end
  def bgsave; end
  def client(subcommand = nil, *args); end
  def config(action, *args); end
  def dbsize; end
  def debug(*args); end
  def flushall(options = nil); end
  def flushdb(options = nil); end
  def info(cmd = nil); end
  def lastsave; end
  def monitor(&block); end
  def save; end
  def shutdown; end
  def slaveof(host, port); end
  def slowlog(subcommand, length = nil); end
  def sync; end
  def time; end
end
module Redis::Commands::Sets
  def sadd(key, member); end
  def scard(key); end
  def sdiff(*keys); end
  def sdiffstore(destination, *keys); end
  def sinter(*keys); end
  def sinterstore(destination, *keys); end
  def sismember(key, member); end
  def smembers(key); end
  def smismember(key, *members); end
  def smove(source, destination, member); end
  def spop(key, count = nil); end
  def srandmember(key, count = nil); end
  def srem(key, member); end
  def sscan(key, cursor, **options); end
  def sscan_each(key, **options, &block); end
  def sunion(*keys); end
  def sunionstore(destination, *keys); end
end
module Redis::Commands::SortedSets
  def _zsets_operation(cmd, *keys, weights: nil, aggregate: nil, with_scores: nil); end
  def _zsets_operation_store(cmd, destination, keys, weights: nil, aggregate: nil); end
  def bzpopmax(*args); end
  def bzpopmin(*args); end
  def zadd(key, *args, nx: nil, xx: nil, lt: nil, gt: nil, ch: nil, incr: nil); end
  def zcard(key); end
  def zcount(key, min, max); end
  def zdiff(*keys, with_scores: nil); end
  def zdiffstore(*args); end
  def zincrby(key, increment, member); end
  def zinter(*args); end
  def zinterstore(*args); end
  def zlexcount(key, min, max); end
  def zmscore(key, *members); end
  def zpopmax(key, count = nil); end
  def zpopmin(key, count = nil); end
  def zrandmember(key, count = nil, withscores: nil, with_scores: nil); end
  def zrange(key, start, stop, byscore: nil, by_score: nil, bylex: nil, by_lex: nil, rev: nil, limit: nil, withscores: nil, with_scores: nil); end
  def zrangebylex(key, min, max, limit: nil); end
  def zrangebyscore(key, min, max, withscores: nil, with_scores: nil, limit: nil); end
  def zrangestore(dest_key, src_key, start, stop, byscore: nil, by_score: nil, bylex: nil, by_lex: nil, rev: nil, limit: nil); end
  def zrank(key, member); end
  def zrem(key, member); end
  def zremrangebyrank(key, start, stop); end
  def zremrangebyscore(key, min, max); end
  def zrevrange(key, start, stop, withscores: nil, with_scores: nil); end
  def zrevrangebylex(key, max, min, limit: nil); end
  def zrevrangebyscore(key, max, min, withscores: nil, with_scores: nil, limit: nil); end
  def zrevrank(key, member); end
  def zscan(key, cursor, **options); end
  def zscan_each(key, **options, &block); end
  def zscore(key, member); end
  def zunion(*args); end
  def zunionstore(*args); end
end
module Redis::Commands::Streams
  def _xread(args, keys, ids, blocking_timeout_msec); end
  def xack(key, group, *ids); end
  def xadd(key, entry, approximate: nil, maxlen: nil, id: nil); end
  def xautoclaim(key, group, consumer, min_idle_time, start, count: nil, justid: nil); end
  def xclaim(key, group, consumer, min_idle_time, *ids, **opts); end
  def xdel(key, *ids); end
  def xgroup(subcommand, key, group, id_or_consumer = nil, mkstream: nil); end
  def xinfo(subcommand, key, group = nil); end
  def xlen(key); end
  def xpending(key, group, *args); end
  def xrange(key, start = nil, range_end = nil, count: nil); end
  def xread(keys, ids, count: nil, block: nil); end
  def xreadgroup(group, consumer, keys, ids, count: nil, block: nil, noack: nil); end
  def xrevrange(key, range_end = nil, start = nil, count: nil); end
  def xtrim(key, maxlen, approximate: nil); end
end
module Redis::Commands::Strings
  def append(key, value); end
  def decr(key); end
  def decrby(key, decrement); end
  def get(key); end
  def getdel(key); end
  def getex(key, ex: nil, px: nil, exat: nil, pxat: nil, persist: nil); end
  def getrange(key, start, stop); end
  def getset(key, value); end
  def incr(key); end
  def incrby(key, increment); end
  def incrbyfloat(key, increment); end
  def mapped_mget(*keys); end
  def mapped_mset(hash); end
  def mapped_msetnx(hash); end
  def mget(*keys, &blk); end
  def mset(*args); end
  def msetnx(*args); end
  def psetex(key, ttl, value); end
  def set(key, value, ex: nil, px: nil, exat: nil, pxat: nil, nx: nil, xx: nil, keepttl: nil, get: nil); end
  def setex(key, ttl, value); end
  def setnx(key, value); end
  def setrange(key, offset, value); end
  def strlen(key); end
end
module Redis::Commands::Transactions
  def discard; end
  def exec; end
  def multi(&block); end
  def unwatch; end
  def watch(*keys); end
end
module Redis::Connection
  def self.drivers; end
end
module Redis::Connection::CommandHelper
  def build_command(args); end
  def encode(string); end
end
module Redis::Connection::SocketMixin
  def _read_from_socket(nbytes, buffer = nil); end
  def gets; end
  def initialize(*args); end
  def read(nbytes); end
  def timeout=(timeout); end
  def write(buffer); end
  def write_timeout=(timeout); end
end
class Redis::Connection::TCPSocket < Socket
  def self.connect(host, port, timeout); end
  def self.connect_addrinfo(addrinfo, port, timeout); end
  include Redis::Connection::SocketMixin
end
class Redis::Connection::UNIXSocket < Socket
  def self.connect(path, timeout); end
  include Redis::Connection::SocketMixin
end
class Redis::Connection::SSLSocket < OpenSSL::SSL::SSLSocket
  def self.connect(host, port, timeout, ssl_params); end
  def wait_readable(timeout = nil); end
  def wait_writable(timeout = nil); end
  include Redis::Connection::SocketMixin
end
class Redis::Connection::Ruby
  def connected?; end
  def disconnect; end
  def format_bulk_reply(line); end
  def format_error_reply(line); end
  def format_integer_reply(line); end
  def format_multi_bulk_reply(line); end
  def format_reply(reply_type, line); end
  def format_status_reply(line); end
  def get_tcp_keepalive; end
  def initialize(sock); end
  def read; end
  def self.connect(config); end
  def set_tcp_keepalive(keepalive); end
  def set_tcp_nodelay; end
  def timeout=(timeout); end
  def write(command); end
  def write_timeout=(timeout); end
  include Redis::Connection::CommandHelper
end
class Redis::Client
  def _parse_driver(driver); end
  def _parse_options(options); end
  def call(command); end
  def call_loop(command, timeout = nil); end
  def call_pipeline(pipeline); end
  def call_pipelined(pipeline); end
  def call_with_timeout(command, extra_timeout, &blk); end
  def call_without_timeout(command, &blk); end
  def close; end
  def command_map; end
  def connect; end
  def connect_timeout; end
  def connected?; end
  def connection; end
  def db; end
  def db=(db); end
  def disconnect; end
  def driver; end
  def ensure_connected; end
  def establish_connection; end
  def host; end
  def id; end
  def inherit_socket?; end
  def initialize(options = nil); end
  def io; end
  def location; end
  def logger; end
  def logger=(arg0); end
  def logging(commands); end
  def options; end
  def password; end
  def path; end
  def port; end
  def process(commands); end
  def read; end
  def read_timeout; end
  def reconnect; end
  def scheme; end
  def timeout; end
  def username; end
  def with_reconnect(val = nil); end
  def with_socket_timeout(timeout); end
  def without_reconnect(&blk); end
  def without_socket_timeout(&blk); end
  def write(command); end
end
class Redis::Client::Connector
  def check(client); end
  def initialize(options); end
  def resolve; end
end
class Redis::Client::Connector::Sentinel < Redis::Client::Connector
  def check(client); end
  def initialize(options); end
  def resolve; end
  def resolve_master; end
  def resolve_slave; end
  def sentinel_detect; end
end
class Redis::Cluster::Command
  def determine_first_key_position(command); end
  def determine_optional_key_position(command, option_name); end
  def dig_details(command, key); end
  def extract_first_key(command); end
  def extract_hash_tag(key); end
  def initialize(details); end
  def pick_details(details); end
  def should_send_to_master?(command); end
  def should_send_to_slave?(command); end
end
module Redis::Cluster::CommandLoader
  def fetch_command_details(node); end
  def load(nodes); end
  def self.fetch_command_details(node); end
  def self.load(nodes); end
end
module Redis::Cluster::KeySlotConverter
  def convert(key); end
  def self.convert(key); end
end
class Redis::Cluster::Node
  def build_clients(options); end
  def call_all(command, &block); end
  def call_master(command, &block); end
  def call_slave(command, &block); end
  def each(&block); end
  def find_by(node_key); end
  def initialize(options, node_flags = nil, with_replica = nil); end
  def master?(node_key); end
  def process_all(commands, &block); end
  def replica_disabled?; end
  def sample; end
  def scale_reading_clients; end
  def slave?(node_key); end
  def try_map; end
  include Enumerable
end
class Redis::Cluster::Node::ReloadNeeded < StandardError
end
module Redis::Cluster::NodeKey
  def build_from_host_port(host, port); end
  def build_from_uri(uri); end
  def optionize(node_key); end
  def self.build_from_host_port(host, port); end
  def self.build_from_uri(uri); end
  def self.optionize(node_key); end
  def self.split(node_key); end
  def split(node_key); end
end
module Redis::Cluster::NodeLoader
  def fetch_node_info(node); end
  def load_flags(nodes); end
  def self.fetch_node_info(node); end
  def self.load_flags(nodes); end
end
class Redis::Cluster::Option
  def add_common_node_option_if_needed(options, node_opts, key); end
  def add_node(host, port); end
  def build_node_options(addrs); end
  def initialize(options); end
  def parse_node_addr(addr); end
  def parse_node_option(addr); end
  def parse_node_url(addr); end
  def per_node_key; end
  def update_node(addrs); end
  def use_replica?; end
end
class Redis::Cluster::Slot
  def build_slot_node_key_map(available_slots); end
  def exists?(slot); end
  def find_node_key_of_master(slot); end
  def find_node_key_of_slave(slot); end
  def initialize(available_slots, node_flags = nil, with_replica = nil); end
  def master?(node_key); end
  def put(slot, node_key); end
  def replica_disabled?; end
  def slave?(node_key); end
end
module Redis::Cluster::SlotLoader
  def fetch_slot_info(node); end
  def load(nodes); end
  def parse_slot_info(arr, default_ip:); end
  def self.fetch_slot_info(node); end
  def self.load(nodes); end
  def self.parse_slot_info(arr, default_ip:); end
  def self.stringify_node_key(arr, default_ip); end
  def stringify_node_key(arr, default_ip); end
end
class Redis::PipelinedConnection
  def call_pipeline(pipeline); end
  def db; end
  def db=(db); end
  def initialize(pipeline); end
  def pipelined; end
  def send_blocking_command(command, timeout, &block); end
  def send_command(command, &block); end
  def synchronize; end
  include Redis::Commands
end
class Redis::Pipeline
  def call(command, timeout: nil, &block); end
  def call_pipeline(pipeline); end
  def call_with_timeout(command, timeout, &block); end
  def client; end
  def commands; end
  def db; end
  def db=(arg0); end
  def empty?; end
  def finish(replies, &blk); end
  def futures; end
  def initialize(client); end
  def materialized_futures; end
  def self.deprecation_warning(method, caller_locations); end
  def shutdown?; end
  def timeout; end
  def timeouts; end
  def with_reconnect(val = nil); end
  def with_reconnect?; end
  def without_reconnect(&blk); end
  def without_reconnect?; end
end
class Redis::Pipeline::Multi < Redis::Pipeline
  def commands; end
  def finish(replies); end
  def materialized_futures; end
  def timeouts; end
end
class Redis::DeprecatedPipeline < Anonymous_Delegator_1
  def __getobj__; end
  def initialize(pipeline); end
end
class Redis::DeprecatedMulti < Anonymous_Delegator_2
  def __getobj__; end
  def initialize(pipeline); end
end
class Redis::FutureNotReady < RuntimeError
  def initialize; end
end
class Redis::Future < BasicObject
  def ==(_other); end
  def _command; end
  def _set(object); end
  def class; end
  def initialize(command, transformation, timeout); end
  def inspect; end
  def is_a?(other); end
  def timeout; end
  def value; end
end
class Redis::MultiFuture < Redis::Future
  def _set(replies); end
  def initialize(futures); end
end
class Redis::SubscribedClient
  def call(command); end
  def initialize(client); end
  def psubscribe(*channels, &block); end
  def psubscribe_with_timeout(timeout, *channels, &block); end
  def punsubscribe(*channels); end
  def subscribe(*channels, &block); end
  def subscribe_with_timeout(timeout, *channels, &block); end
  def subscription(start, stop, channels, block, timeout = nil); end
  def unsubscribe(*channels); end
end
class Redis::Subscription
  def callbacks; end
  def initialize; end
  def message(&block); end
  def pmessage(&block); end
  def psubscribe(&block); end
  def punsubscribe(&block); end
  def subscribe(&block); end
  def unsubscribe(&block); end
end
class Redis::Deprecated < StandardError
end
