Redcord
-------------------------------
[![Gem Version](https://badge.fury.io/rb/redcord.svg)](https://badge.fury.io/rb/redcord)
[![codecov](https://codecov.io/gh/chanzuckerberg/redcord/branch/master/graph/badge.svg)](https://codecov.io/gh/chanzuckerberg/redcord)

A Ruby ORM like Active Record, but for Redis.

**Note:** This is a pre-release version.

## Getting Started
### 1. Add to your Gemfile
```ruby
# -- Gemfile --

gem 'redcord'
```

### 2. Connect to a Redis server
In `config/redcord.yml`, set a default Redis URL for all Redcord models in the test and development environment. **Note:** the local Redis server version needs to be >= 4.x.
```ruby
development:
  default:
    url: redis://127.0.0.1:6379/1

test:
  default:
    url: redis://127.0.0.1:6379/2
```

Learn more: [Redis Server Configurations](docs/redis_server_configurations.md)

### 3. Create a Redcord model
In the example, we create a UserSession model -- The in-memory Redis database is great for session management.
```ruby
class UserSession < T::Struct
  include Redcord::Base

  ttl 2.hours

  attribute :user_id, Integer, index: true
  attribute :session_id, String
end
```

Learn more: [Redcord Model](docs/redcord_model.md)

### 4. Reading and writing data
#### Read
Return the first user session that matches the user's id:
```ruby
UserSession.find_by(user_id: user.id)
```
**Note:** This query won’t work until we execute a Redcord migration for adding the index.

Like Active Record, created_at and updated_at are maintained automatically on each record. Find all user sessions created an hour ago:
```ruby
UserSession.where('created_at < ?',  Time.zone.now - 1.hour) # TODO: support this
```

#### Update
Once a Redcord object has been retrieved, its attributes can be modified and it can be saved to the Redis database.
```ruby
user_session = UserSession.find_by(user_id: user.id)
user_session.updated_at = Time.zone.now
user_session.save
```

A shorthand for this is to use a hash mapping attribute names to the desired value:
```ruby
user_session.update(updated_at: Time.zone.now) # TODO: support this
```

#### Delete
Once a Redcord object has been retrieved, it can be destroyed which removes it from the database.
```ruby
user_session = UserSession.find_by(user_id: user.id)
user_session.destroy
```

Learn more: [Querying interface](docs/querying_interface.md)

### 5. Migrations
Redcord provides a domain-specific language for updating model schemas on Redis called migrations. Migrations are stored in files which are executed against each Redis database used in the current Rails environment.

Here's a migration that adds an new index on user_id:
`db/redcord/migrate/20200504000000_add_index_user_id.rb`:
```ruby
class AddIndexUserId < Redcord::Migration
  def up
    add_index(UserSession, :user_id)
  end

  def down
    remove_index(UserSession, :user_id)
  end
end
```

Use the following rake command to run this migration
```bash
$ rake redis:migrate
redis                           direction                       version                         migration                       duration
redis://127.0.0.1:6379/0        UP                              20200504000000                  Add index user id               18.03934400959406 ms

Finished in 0.024 second
```
Note: Redcord starts to maintain new indices as soon as `index :true` is set on a model (new ttl is also applied immediately). Migrations are only needed for syncing existing records.

Learn more: [Migrations](docs/migrations.md)

### 6. Redis Cluster
Redcord supports data sharding on a Redis cluster by using [hast tag](https://redis.io/topics/cluster-spec) to partition data on different redis nodes.

When queries have to search through millions of records, the ZSET commands the queries use become CPU-intensive and might cause a spike in Redis server process CPU usage. Since Redis is mostly single-threaded,  scaling up the server to a larger instance won’t effectively absorb the load and relief the CPU. Under this circumstance, scaling out the server is the way to go!

Here is an example, an example of sharding by an index attribute `region`.

`user_session.rb`:
```ruby
class UserSession < T::Struct
  include Redcord::Base

  ttl 2.hours

  attribute :user_id, Integer, index: true
  attribute :session_id, String

  attribute :region, String, index: true
  shard_by_attribute :region
end
```

`config/redcord.yml`:
```ruby
...
production:
  # See also https://github.com/redis/redis-rb#cluster-support
  user_session:
    cluster:
    - redis://127.0.0.1:7000
    - redis://127.0.0.1:7001
    - redis://127.0.0.1:7002
```

Constraints:
1. The sharded attribute cannot be updated
2. All queries must have the sharded attribute as a query condition
3. Only equality query conditions are allowed on the sharded attribute: `UserSession.where(region: 'u.s.', ...)`
4. Operations cannot be atomic if they operate on different shards

### 7. Monitoring
Redcord reports metrics to a tracer (for example, [Datadog APM](https://docs.datadoghq.com/tracing/setup/ruby/#manual-instrumentation)) if it is configured.

In `config/initializers/redcord.rb`, provide a block with a Ruby object that responds to  `.trace(<span_name>, <options hash>)`.
```ruby
Redcord.configure do |config|
  # Don’t forget to enable manual-instrumentation in datadog’s configuration!
  config.tracer { Datadog.tracer }
end
```

## Related Projects; Yet Another Redcord
To the best of our knowledge, Redcord is the best Ruby ORM lib for Redis.

### https://github.com/soveran/ohm
This project is inspired by ohm. Redcord has the following features which Ohm does not have:
- An Active Record like API
- Range index queries support
- Atomic CRUD operations
- Runtime and statical type-checking (with sorbet)
- One Redis DB roundtrip per operation
- Migrations and push safety protection

### https://github.com/nateware/redis-objects
Redis object map Redis types directly to Ruby objects, but it does not provide an object-relational mapping.

### https://redisql.com/
- RediSQL is not ORM
- RediSQL does not support indexing
- RediSQL uses a Redis server extension, which is not supported by all Redis PaaSs. Redcord uses Lua scripts that are generally supported.

### Abandoned projects:
- https://github.com/malditogeek/redisrecord
- https://github.com/LoonyBin/redis_record
- https://rubygems.org/gems/redis_record

## Performance
Redcord is fast!

### TODO: Comparison with Postgres
### TODO: Benchmark results

## Fault tolerance
We recommend using Redcord on a Redis PaaS which has built-in failover support. If a Redis server is down, there will be downtime, but the Redis Platform would hopefully recover quickly.

**Note:**
- Set the Redis server to noevict
- (optional) Take screenshots of the server regularly
- Rely on fail-over instead of AOF persistency

## Contributing
Contributions and ideas are welcome! Please see our contributing guide and don't hesitate to open an issue or send a pull request to improve the functionality of this gem.
This project adheres to the Contributor Covenant code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to opensource@chanzuckerberg.com.

## License
This project is licensed under [MIT](LICENSE).
