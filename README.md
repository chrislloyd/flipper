# Flipper

Feature flipping is the act of enabling or disabling features or parts of your application, ideally without re-deploying or changing anything in your code base.

The goal of this gem is to make turning features on or off so easy that everyone does it. Whatever your data store, throughput, or experience, feature flipping should be easy and relatively no extra burden to your application.

## Why not use &lt;insert gem name here, most likely rollout&gt;?

I've used rollout extensively in the past and it was fantastic. The main reason I reinvented the wheel to some extent is:

* API - For whatever reason, I could never remember the API for rollout.
* Adapter Based - Rather than force redis, if you can implement a few simple methods, you can use the data store of your choice to power your flippers (memory, file system, mongo, redis, sql, etc.). It is also dead simple to front your data store with memcache if you so desire since feature checking is read heavy, as opposed to write heavy.

## Coming Soon™

* [Web UI](https://github.com/jnunemaker/flipper-ui) (think resque UI for features toggling/status)

## Usage

The goal of the API for flipper was to have everything revolve around features and what ways they can be enabled. Start with top level and dig into a feature, then dig in further and enable that feature for a given type of access, as opposed to thinking about how the feature will be accessed first (ie: stats.enable vs activate_group(:stats, ...)).

```ruby
require 'flipper'

# pick an adapter
require 'flipper/adapters/memory'
adapter = Flipper::Adapters::Memory.new

# get a handy dsl instance
flipper = Flipper.new(adapter)

# grab a feature
search = flipper[:search]

# check if that feature is enabled
if search.enabled?
  puts 'Search away!'
else
  puts 'No search for you!'
end

puts 'Enabling Search...'
search.enable

# check if that feature is enabled again
if search.enabled?
  puts 'Search away!'
else
  puts 'No search for you!'
end
```

Of course there are more [examples for you to peruse](https://github.com/jnunemaker/flipper/tree/master/examples).

## Types

Out of the box several types of enabling are supported. They are checked in this order.

### 1. Boolean

All on or all off. Think top level things like :stats, :search, :logging, etc. Also, an easy way to release a new feature as once a feature is boolean enabled it is on for every situation.

```ruby
flipper = Flipper.new(adapter)
flipper[:stats].enable # turn on
flipper[:stats].disable # turn off
flipper[:stats].enabled? # check
```

### 2. Group

Turn on feature based on value of block. Super flexible way to turn on a feature for multiple things (users, people, accounts, etc.)

```ruby
Flipper.register(:admins) do |actor|
  actor.respond_to?(:admin?) && actor.admin?
end

flipper = Flipper.new(adapter)
flipper[:stats].enable flipper.group(:admins) # turn on for admins
flipper[:stats].disable flipper.group(:admins) # turn off for admins
person = Person.find(params[:id])
flipper[:stats].enabled? person # check if enabled, returns true if person.admin? is true
```

There is no requirement that the thing yielded to the block be a user model or whatever. It can be anything you want therefore it is a good idea to check that the thing passed into the group block actually responds to what you are trying.

### 3. Individual Actor

Turn on for individual thing. Think enable feature for someone to test or for a buddy.

```ruby
flipper = Flipper.new(adapter)

# convert user or person or whatever to flipper actor for storing and checking
actor = flipper.actor(user.id)

flipper[:stats].enable actor
flipper[:stats].enabled? actor # true

flipper[:stats].disable actor
flipper[:stats].disabled? actor # true
```

### 4. Percentage of Actors

Turn this on for a percentage of actors (think user, member, account, group, whatever). Consistently on or off for this user as long as percentage increases. Think slow rollout of a new feature to a percentage of things.

```ruby
flipper = Flipper.new(adapter)

# convert user or person or whatever to flipper actor for checking if in percentage
actor = flipper.actor(user.id)

# returns a percentage of actors instance set to 10
percentage = flipper.actors(10)

# turn stats on for 10 percent of users in the system
flipper[:stats].enable percentage

# checks if actor's identifier is in the enabled percentage
flipper[:stats].enabled? actor

```

### 5. Percentage of Random

Turn this on for a random percentage of time. Think load testing new features behind the scenes and such.

```ruby
flipper = Flipper.new(adapter)

# get percentage of random instance set to 5
percentage = flipper.random(5)

# turn on logging for 5 percent of the time randomly
# could be on during one request and off the next
# could even be on first time in request and off second time
flipper[:logging].enable percentage
```

Randomness is probably not a good idea for enabling new features in the UI. Most of the time you want a feature on or off for a user, but there are definitely times when I have found percentage of random to be very useful.

## Adapters

I plan on supporting [in-memory](https://github.com/jnunemaker/flipper/blob/master/lib/flipper/adapters/memory.rb), [Mongo](https://github.com/jnunemaker/flipper-mongo), and [Redis](https://github.com/jnunemaker/flipper-redis) as adapters for flipper. Others are welcome so please let me know if you create one.

### Memory

You can use the [in-memory adapter](https://github.com/jnunemaker/flipper/blob/master/lib/flipper/adapters/memory.rb) for tests if you want. That is pretty much all I use it for.

### Mongo

Currently, the [mongo adapter](https://github.com/jnunemaker/flipper-mongo) comes in two flavors.

The [vanilla mongo adapter](https://github.com/jnunemaker/flipper-mongo/blob/master/lib/flipper/adapters/mongo.rb) stores each key in its own document. This means for each gate checked per feature there will be a query to mongo.

Personally, the adapter I prefer is the [single document adapter](https://github.com/jnunemaker/flipper-mongo/blob/master/lib/flipper/adapters/mongo_single_document.rb), which stores all features and gates in a single document. If you combine this adapter with the [local cache middleware](https://github.com/jnunemaker/flipper/blob/master/lib/flipper/middleware/local_cache.rb), the document will only be queried once per request, which is pretty awesome.

### Redis

Redis is great for this type of stuff and it only took a few minutes to implement a [redis adapter](https://github.com/jnunemaker/flipper-redis). The only real problem with redis right now is that automated failover isn't that easy so relying on it for every code path in my app would make me nervous.

## Optimization

One optimization that flipper provides is a local cache. Once you have a flipper instance you can use the local cache to store each adapter key lookup in memory for as long as you want.

Out of the box there is a middleware that will store each key lookup for the duration of the request. This means you will only actually query your adapter's data store once per feature per gate that is checked. You can use the middleware from a Rails initializer like so:

```ruby
require 'flipper/middleware/local_cache'

# create flipper dsl instance, see above examples for more details
flipper = Flipper.new(...)

# ensure entire request is wrapped, `use` would probably be ok instead of `insert_after`, but I noticed that Rails used `insert_after` for their identity map, which this is akin to, and figured it was for a reason.
Rails.application.config.middleware.insert_after \
  ActionDispatch::Callbacks,
  Flipper::Middleware::LocalCache,
  flipper
```

## Installation

Add this line to your application's Gemfile:

    gem 'flipper'

And then execute:

    $ bundle

Or install it yourself with:

    $ gem install flipper

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
