# RedisRecord
`yarr` (yet another redis record) is a a Ruby ORM API for Redis, inspired by ActiveRecord. 

In addition to providing a similar interface to [ActiveRecord](https://guides.rubyonrails.org/active_record_querying.html), this gem also provides:
- **Typechecking**: Redis stores records as simple key-value strings. RedisRecord handles the deserialization/serialization of types between Redis and the Ruby client, and provides a type checked Ruby interface via [Sorbet](https://sorbet.org/).
- **Atomic index queries**: RedisRecord strings together basic commands provided by Redis to perform complex queries atomically via Lua scripts.
- **Migrations**: Similar to [ActiveRecord migrations](https://guides.rubyonrails.org/active_record_migrations.html), RedisRecord migrations are intended to provide a backward compatible, push safe way to make changes to the data stored in Redis out of band from the normal application.

## Installation
RedisRecord is intended to work with Rails and [sorbet](https://sorbet.org/docs/adopting), a type checker for Ruby. 

To use RedisRecord, add the following to your Gemfile:
```
# -- Gemfile --

gem 'yarr'
```
### Configuration
Connections to your Redis instance are established by reading the connection configurations for the current Rails environment (development, test, or production). Redis connections can be set at the base level or model level. When a model level connection config is not found, the base level config will be used (which is a common case in the test environment).

For example, in with yaml file:
```
my_env:
  default:
    url: redis_url_1
  my_model:
    url: redis_url_2
```
All models other than my model will connect to redis_url_1. My_model connects to redis_url_2. You can read your configurations from the RedisRecord::Base module:
```RedisRecord::Base.configurations = YAML.load(ERB.new(File.read('config/redisrecord.yml')).result)```


## Features
### Creating a RedisRecord Model
RedisRecord uses `[T::Struct]`(https://sorbet.org/docs/tstruct) to validate the attribute types. The RedisRecord models need to inherit `T::Struct` and `include RedisRecord::Base`. To add a secondary index, the `index: true` option can be used. A time-to-live (TTL) can be set on a RedisRecord to automatically expire untouched records.

``` 
class MyRedisRecord < T::Struct
  include RedisRecord::Base
 
  ttl 1.hour 
  
  attribute :a, Integer, index: true
  attribute :b, String
end
```

### Write Operations
#### Create a RedisRecord
RedisRecord objects can be created from a hash using the `create!` method, or instantiated without being saved to Redis using the `new` method.
```
> instance = MyRedisRecord.create!(a: 1, b: "1")
[Redis] command=EVALSHA args="88645ca933a1451a24086ba4dedc898e59281a5d" 1 "RedisRecord:MyRedisRecord" :a 1 :b "1" :updated_at 1590697812.8310223 :created_at > 1590697812.8310223
[Redis] call_time=0.34 ms
=> <MyRedisRecord a=1, b="1", created_at=Thu, 28 May 2020 13:30:12 PDT -07:00, updated_at=Thu, 28 May 2020 13:30:12 PDT -07:00>
```
```
> instance = MyRedisRecord.new(a: 1, b: "1")
=> <MyRedisRecord a=1, b="1", created_at=nil, updated_at=nil>
```

#### Update a RedisRecord
RedisRecord hash fields can be updated via the `update!` method on the Model class, or `save!` on an instance.
``` 
=> <MyRedisRecord a=1, b="1", created_at=Thu, 28 May 2020 13:30:12 PDT -07:00, updated_at=Thu, 28 May 2020 13:30:12 PDT -07:00>
> instance.update!(a: 2)
[Redis] command=EVALSHA args="ba461696de5745eb21bc66d30bb77039969fcf86" 2 "RedisRecord:MyRedisRecord" 1 :a 2 :updated_at 1590704145.6728008
[Redis] call_time=0.32 ms
=> T::Private::Types::Void::VOID
> instance
=> <MyRedisRecord a=2, b="1", created_at=Thu, 28 May 2020 13:29:58 PDT -07:00, updated_at=Thu, 28 May 2020 15:15:45 PDT -07:00>
```
```
> instance = MyRedisRecord.new(a: 1, b: "1")
=> <MyRedisRecord a=1, b="1", created_at=nil, updated_at=nil>
> instance.save!
[Redis] command=EVALSHA args="88645ca933a1451a24086ba4dedc898e59281a5d" 1 "RedisRecord:MyRedisRecord" :created_at 1590703739.898089 :updated_at 1590703739.898089 :a 1 :b "1"
[Redis] call_time=0.42 ms
=> T::Private::Types::Void::VOID
``` 
#### Delete a RedisRecord
RedisRecord can be deleted using the `destroy` method on either the Model class and the primary key, or the instance directly.
``` 
> MyRedisRecord.destroy(1)
[Redis] command=EVALSHA args="71c839250cbe928109aeef9e18803f2e84cac5d7" 2 "RedisRecord:MyRedisRecord" 1
[Redis] call_time=0.30 ms
=> true
```
```
> instance.destroy
[Redis] command=EVALSHA args="71c839250cbe928109aeef9e18803f2e84cac5d7" 2 "RedisRecord:MyRedisRecord" 2
[Redis] call_time=0.26 ms
=> true
```

### Querying interface
#### Find by primary key
RedisRecords can be found using the `find` method and the primary key.
```
> test = MyRedisRecord.find(1)
[Redis] command=HGETALL args="RedisRecord:MyRedisRecord:id:1"
[Redis] call_time=0.27 ms
=> <MyRedisRecord a=1, b="1", created_at=Thu, 28 May 2020 13:29:58 PDT -07:00, updated_at=Thu, 28 May 2020 13:29:58 PDT -07:00>
```
#### Index queries by secondary key
RedisRecords can be queried by a secondary index using the where method.
```
> MyRedisRecord.where(a: 1).to_a
[Redis] command=EVALSHA args="a5f39c74fc60a4681b94b0d3150b09d0330b372a" 1 "RedisRecord:MyRedisRecord" :a 1 1
[Redis] call_time=0.34 ms
=> [<MyRedisRecord a=1, b="1", created_at=Thu, 28 May 2020 16:22:34 PDT -07:00, updated_at=Thu, 28 May 2020 16:22:34 PDT -07:00>,
 <MyRedisRecord a=1, b="1", created_at=Thu, 28 May 2020 16:22:35 PDT -07:00, updated_at=Thu, 28 May 2020 16:22:35 PDT -07:00>]
```
For datatypes `Integer`, `Float`, and `Time`, RedisRecords can be range queried using a `RedisRecord::RangeInterval` object.
```
> MyRedisRecord.where(a: RedisRecord::RangeInterval.new(max: 2)).to_a
[Redis] command=EVALSHA args="a5f39c74fc60a4681b94b0d3150b09d0330b372a" 1 "RedisRecord:MyRedisRecord" :a "-inf" "2"
[Redis] call_time=0.43 ms
=> [<MyRedisRecord a=1, b="1", created_at=Thu, 28 May 2020 16:22:34 PDT -07:00, updated_at=Thu, 28 May 2020 16:22:34 PDT -07:00>,
 <MyRedisRecord a=2, b="1", created_at=Thu, 28 May 2020 16:22:38 PDT -07:00, updated_at=Thu, 28 May 2020 16:22:38 PDT -07:00>,
 <MyRedisRecord a=1, b="1", created_at=Thu, 28 May 2020 16:22:35 PDT -07:00, updated_at=Thu, 28 May 2020 16:22:35 PDT -07:00>]
```
#### Method Chaining
Similar to [ActiveRecord](https://guides.rubyonrails.org/active_record_querying.html#understanding-the-method-chaining), RedisRecord chains index query methods together using a `RedisRecord::Relation` object. The query is not actually executed on Redis until the `.to_a` kicker method is called, or if the query returns a single object (e.g., the `count` query). This allows multiple queries to be optimized into a single db call to Redis.

Currently, RedisRecord supports chaining queries with `where`, `select` and `count`.
```
> relation = MyRedisRecord.where(a: 1).select(:b, :created_at)
=> #<RedisRecord::Relation:0x000055b9c8998108
 @model=MyRedisRecord,
 @query_conditions={:a=>[1, 1]},
 @select_attrs=#<Set: {:b, :created_at}>>
> relation.to_a
[Redis] command=EVALSHA args="f2e0f337d42e9fa0d580646244c367096523656d" 4 "RedisRecord:MyRedisRecord" :a 1 1 :b :created_at
[Redis] call_time=0.30 ms
=> [{:b=>"2", :created_at=>Tue, 09 Jun 2020 20:40:00 PDT -07:00, :id=>1},
 {:b=>"4", :created_at=>Tue, 09 Jun 2020 20:40:05 PDT -07:00, :id=>3},
 {:b=>"3", :created_at=>Tue, 09 Jun 2020 20:40:03 PDT -07:00, :id=>2}]
 ```
 ```
> relation = MyRedisRecord.where(a: 1).count
[Redis] command=EVALSHA args="5aca618019854a1275397a2ec745a306fa8d8fc9" 4 "RedisRecord:MyRedisRecord" :a 1 1
[Redis] call_time=0.30 ms
=> 3
```
### Migrations
Similar to ActiveRecord, model level changes should be done using a migration. RedisRecord migrations run out of band of the normal application and should be  to ensure push safety.
