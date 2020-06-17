YARR - Yet Another Redis Record
-------------------------------
Redis Record provides an object-relational mapping like Active Record, but for Redis.

**Note:** This is a pre-release version.

## Getting Started
### 1. Add yarr to your Gemfile
```ruby
# -- Gemfile --

gem 'yarr'
```

### 2. Connect to a Redis server
### TODO: `config/redisrecord.yml` -> `config/redis_record.yml`
In `config/redis_record.yml`, set a default Redis URL for all Redis Record models in the test and development environment. **Note:** the local Redis server version needs to be >= 4.x.
```ruby
development:
  default:
    url: redis://127.0.0.1:6379/1

test:
  default:
    url: redis://127.0.0.1:6379/2
```

Learn more: [Redis Server Configurations](docs/redis_server_configurations.md)

### 3. Create a Redis Record model
In the example, we create a UserSession model -- The in-memory Redis database is great for session management.
```ruby
class UserSession < T::Struct
  include RedisRecord::Base

  ttl 2.hours

  attribute :user_id, Integer, index: true
  attribute :session_id, String
end
```

Learn more: [Redis Record Model](docs/redis_record_model.md)

### 4. Reading and writing data
#### Read
Return the first user session that matches the user's id:
```ruby
UserSession.find_by(user_id: user.id) # TODO: support this
```
**Note:** This query won’t work until we execute a Redis Record migration for adding the index.

Like Active Record, created_at and updated_at are maintained automatically on each record. Find all user sessions created an hour ago:
```ruby
UserSession.where('created_at < ?',  Time.zone.now - 1.hour) # TODO: support this
```

#### Update
Once a Redis Record object has been retrieved, its attributes can be modified and it can be saved to the Redis database.
```ruby
user_session = UserSession.find_by(user_id: user.id)
user_session.updated_at = Time.zone.now
user_session.save # TODO: support this
```

A shorthand for this is to use a hash mapping attribute names to the desired value:
```ruby
user_session.update(updated_at: Time.zone.now) # TODO: support this
```

#### Delete
Once a Redis Record object has been retrieved, it can be destroyed which removes it from the database.
```ruby
user_session = UserSession.find_by(user_id: user.id)
user_session.destroy
```

Learn more: [Querying interface](docs/querying_interface.md)

### 5. Migrations
Redis Record provides a domain-specific language for updating model schemas on Redis called migrations. Migrations are stored in files which are executed against each Redis database used in the current Rails environment.

Here's a migration that adds an index on user_id and adds a TTL on each user session:
### TODO: db/redisrecord -> db/redis_record 
`db/redis_record/migrate/20200504000000_create_user_session.rb`:
```ruby
class CreateUserSession < RedisRecord::Migration
  def up
    change_ttl_passive(UserSession)
    add_index(UserSession, :user_id)
  end

  def down
    change_ttl_passive(UserSession, nil)
    remove_index(UserSession, :user_id)
  end
end
```

Use the following rake command to run this migration
```bash
$ rake redis:migrate
redis                           direction                       version                         migration                       duration
redis://127.0.0.1:6379/0        UP                              20200504000000                  Create user session           18.03934400959406 ms

Finished in 0.024 second
```

Learn more: [Migrations](docs/migrations.md)

## Related Projects; Yet Another Redis Record
To the best of our knowledge, YARR is the best Ruby ORM lib for Redis.

### https://github.com/soveran/ohm
This project is inspired by ohm. YARR has the following features which Ohm does not have:
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
- RediSQL uses a Redis server extension, which is not supported by all Redis PaaSs. Redis Record uses Lua scripts that are generally supported.

### Abandoned projects:
- https://github.com/malditogeek/redisrecord/
- https://github.com/LoonyBin/redis_record
- https://rubygems.org/gems/redis_record

## Performance
Redis Record is fast!

### TODO: Comparison with Postgres
### TODO: Benchmark results

## Fault tolerance
We recommend using Redis Record on a Redis PaaS which has built-in failover support. If a Redis server is down, there will be downtime, but the Redis Platform would hopefully recover quickly.

**Note:**
- Set the Redis server to noevict
- (optional) Take screenshots of the server regularly
- Do not use Redis Cluster
- Rely on fail-over instead of AOF persistency

## Contributing
Contributions and ideas are welcome! Please see our contributing guide and don't hesitate to open an issue or send a pull request to improve the functionality of this gem.
This project adheres to the Contributor Covenant code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to opensource@chanzuckerberg.com.

## License
This project is licensed under [MIT](LICENSE).
