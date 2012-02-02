class User
  attr :username, :name, :email, :phone
  def self.exists?(user_name)
    !$redis.hget('user:'+user_name, 'name').nil?
  end

  def self.find(user_name)
   user = $redis.hgetall('user:'+user_name)
   if user == {}
     puts user.inspect
     puts "hello :("
     raise "User not found"
   end
   User.new(user['name'], user_name, user['email'], user['phone'])
  end

  def initialize(name, uname, email, phone)
    @name = name
    @username = uname
    @email = email
    @phone = phone
  end

  def self.create(name, uname, email, phone)
    $redis.hmset('user:'+uname, 'name', name, 'email', email, 'phone', phone)
  end
  
  def create_event(ttl)
    $redis.multi do
      $redis.sadd('active_users', @username)
      $redis.setex('user:'+@username+':active', ttl, 'yes')
    end
  end

  def self.get_all_active_users
    all = []
    $redis.smembers('active_users').each do |m|
      all << $redis.hgetall('user:'+m)
    end
    all
  end

  def get_active_friends()
    friends = $redis.sinter('user:'+@username+':friends', 'active_users')
    all = []
    friends.each do |f|
      if $redis.get('user:'+f+':active')
        all << $redis.hgetall('user:'+f)
      else
        $redis.del('user:'+f+':active')
      end
    end
    all
  end
end