# This file is autogenerated. Do not edit it by hand. Regenerate it with:
#   srb rbi gems

# typed: strict
#
# If you would like to make changes to this file, great! Please create the gem's shim here:
#
#   https://github.com/sorbet/sorbet-typed/new/master?filename=lib/actioncable/all/actioncable.rbi
#
# actioncable-5.2.4.3

module ActionCable
  def self.gem_version; end
  def self.server; end
  def self.version; end
  def server; end
  extend ActiveSupport::Autoload
end
module ActionCable::VERSION
end
module ActionCable::Helpers
end
module ActionCable::Helpers::ActionCableHelper
  def action_cable_meta_tag; end
end
class ActionCable::Engine < Rails::Engine
end
module ActionCable::Server
  extend ActiveSupport::Autoload
end
module ActionCable::Server::Broadcasting
  def broadcast(broadcasting, message, coder: nil); end
  def broadcaster_for(broadcasting, coder: nil); end
end
class ActionCable::Server::Broadcasting::Broadcaster
  def broadcast(message); end
  def broadcasting; end
  def coder; end
  def initialize(server, broadcasting, coder:); end
  def server; end
end
module ActionCable::Server::Connections
  def add_connection(connection); end
  def connections; end
  def open_connections_statistics; end
  def remove_connection(connection); end
  def setup_heartbeat_timer; end
end
class ActionCable::Server::Configuration
  def allow_same_origin_as_host; end
  def allow_same_origin_as_host=(arg0); end
  def allowed_request_origins; end
  def allowed_request_origins=(arg0); end
  def cable; end
  def cable=(arg0); end
  def connection_class; end
  def connection_class=(arg0); end
  def disable_request_forgery_protection; end
  def disable_request_forgery_protection=(arg0); end
  def initialize; end
  def log_tags; end
  def log_tags=(arg0); end
  def logger; end
  def logger=(arg0); end
  def mount_path; end
  def mount_path=(arg0); end
  def pubsub_adapter; end
  def url; end
  def url=(arg0); end
  def worker_pool_size; end
  def worker_pool_size=(arg0); end
end
class ActionCable::Server::Base
  def call(env); end
  def config; end
  def config=(obj); end
  def connection_identifiers; end
  def disconnect(identifiers); end
  def event_loop; end
  def initialize; end
  def logger(*args, &block); end
  def mutex; end
  def pubsub; end
  def remote_connections; end
  def restart; end
  def self.config; end
  def self.config=(obj); end
  def self.logger; end
  def worker_pool; end
  include ActionCable::Server::Broadcasting
  include ActionCable::Server::Connections
end
class ActionCable::Server::Worker
  def __callbacks; end
  def __callbacks?; end
  def _run_work_callbacks(&block); end
  def _work_callbacks; end
  def async_exec(receiver, *args, connection:, &block); end
  def async_invoke(receiver, method, *args, connection: nil, &block); end
  def connection; end
  def connection=(obj); end
  def executor; end
  def halt; end
  def initialize(max_size: nil); end
  def invoke(receiver, method, *args, connection:, &block); end
  def logger; end
  def self.__callbacks; end
  def self.__callbacks=(val); end
  def self.__callbacks?; end
  def self._work_callbacks; end
  def self._work_callbacks=(value); end
  def self.connection; end
  def self.connection=(obj); end
  def stopping?; end
  def work(connection); end
  extend ActiveSupport::Callbacks::ClassMethods
  extend ActiveSupport::DescendantsTracker
  include ActionCable::Server::Worker::ActiveRecordConnectionManagement
  include ActiveSupport::Callbacks
end
module ActionCable::Server::Worker::ActiveRecordConnectionManagement
  def with_database_connections; end
  extend ActiveSupport::Concern
end
module ActionCable::Connection
  extend ActiveSupport::Autoload
end
module ActionCable::Connection::Authorization
  def reject_unauthorized_connection; end
end
class ActionCable::Connection::Authorization::UnauthorizedError < StandardError
end
module ActionCable::Connection::Identification
  def connection_gid(ids); end
  def connection_identifier; end
  extend ActiveSupport::Concern
end
module ActionCable::Connection::Identification::ClassMethods
  def identified_by(*identifiers); end
end
module ActionCable::Connection::InternalChannel
  def internal_channel; end
  def process_internal_message(message); end
  def subscribe_to_internal_channel; end
  def unsubscribe_from_internal_channel; end
  extend ActiveSupport::Concern
end
class ActionCable::Connection::Base
  def allow_request_origin?; end
  def beat; end
  def close; end
  def cookies; end
  def decode(websocket_message); end
  def dispatch_websocket_message(websocket_message); end
  def encode(cable_message); end
  def env; end
  def event_loop(*args, &block); end
  def finished_request_message; end
  def handle_close; end
  def handle_open; end
  def identifiers; end
  def identifiers=(val); end
  def identifiers?; end
  def initialize(server, env, coder: nil); end
  def invalid_request_message; end
  def logger; end
  def message_buffer; end
  def new_tagged_logger; end
  def on_close(reason, code); end
  def on_error(message); end
  def on_message(message); end
  def on_open; end
  def process; end
  def protocol; end
  def pubsub(*args, &block); end
  def receive(websocket_message); end
  def request; end
  def respond_to_invalid_request; end
  def respond_to_successful_request; end
  def self.identifiers; end
  def self.identifiers=(val); end
  def self.identifiers?; end
  def send_async(method, *arguments); end
  def send_welcome_message; end
  def server; end
  def started_request_message; end
  def statistics; end
  def subscriptions; end
  def successful_request_message; end
  def transmit(cable_message); end
  def websocket; end
  def worker_pool; end
  extend ActionCable::Connection::Identification::ClassMethods
  include ActionCable::Connection::Authorization
  include ActionCable::Connection::Identification
  include ActionCable::Connection::InternalChannel
end
class ActionCable::Connection::ClientSocket
  def alive?; end
  def begin_close(reason, code); end
  def client_gone; end
  def close(code = nil, reason = nil); end
  def emit_error(message); end
  def env; end
  def finalize_close; end
  def initialize(env, event_target, event_loop, protocols); end
  def open; end
  def parse(data); end
  def protocol; end
  def rack_response; end
  def receive_message(data); end
  def self.determine_url(env); end
  def self.secure_request?(env); end
  def start_driver; end
  def transmit(message); end
  def url; end
  def write(data); end
end
class ActionCable::Connection::MessageBuffer
  def append(message); end
  def buffer(message); end
  def buffered_messages; end
  def connection; end
  def initialize(connection); end
  def process!; end
  def processing?; end
  def receive(message); end
  def receive_buffered_messages; end
  def valid?(message); end
end
class ActionCable::Connection::Stream
  def clean_rack_hijack; end
  def close; end
  def each(&callback); end
  def flush_write_buffer; end
  def hijack_rack_socket; end
  def initialize(event_loop, socket); end
  def receive(data); end
  def shutdown; end
  def write(data); end
end
class ActionCable::Connection::StreamEventLoop
  def attach(io, stream); end
  def detach(io, stream); end
  def initialize; end
  def post(task = nil, &block); end
  def run; end
  def spawn; end
  def stop; end
  def timer(interval, &block); end
  def wakeup; end
  def writes_pending(io); end
end
class ActionCable::Connection::Subscriptions
  def add(data); end
  def connection; end
  def execute_command(data); end
  def find(data); end
  def identifiers; end
  def initialize(connection); end
  def logger(*args, &block); end
  def perform_action(data); end
  def remove(data); end
  def remove_subscription(subscription); end
  def subscriptions; end
  def unsubscribe_from_all; end
end
class ActionCable::Connection::TaggedLoggerProxy
  def add_tags(*tags); end
  def debug(message); end
  def error(message); end
  def fatal(message); end
  def info(message); end
  def initialize(logger, tags:); end
  def log(type, message); end
  def tag(logger); end
  def tags; end
  def unknown(message); end
  def warn(message); end
end
