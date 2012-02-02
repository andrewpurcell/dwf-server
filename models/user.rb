class User
  attr :fb_uid, :name, :email, :phone
  def self.exists?(fb_id)
    !$redis.hexists('user:'+fb_id, 'name').nil?
  end

  def self.find(fb_id)
   user = $redis.hgetall('user:'+fb_id)
   if user == {}
     puts user.inspect
     raise "User not found"
   end
   User.new(user['name'], fb_id, user['email'], user['phone'])
  end

  def initialize(name, fb_uid, email, phone)
    @name = name
    @fb_uid = fb_uid
    @email = email
    @phone = phone
  end

  def self.create(name, fb_uid, email, phone)
    $redis.hmset('user:'+fb_uid, 'name', name, 'email', email, 'phone', phone)
  end
  
  def self.add_friends(fid1, fid2)
    $redis.sadd('user:'+fid1+':friends', fid2)
    $redis.sadd('user:'+fid2+':friends', fid1)
  end
  
  def create_event(ttl)
    $redis.multi do
      $redis.sadd('active_users', @fb_uid)
      $redis.setex('user:'+@fb_uid+':active', ttl, 'yes')
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
    friends = $redis.sinter('user:'+@fb_uid+':friends', 'active_users')
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
  
  # for a given fb_uid, add all friends who are using DWF
  def find_existing_friends(user, friendlist)
    friendlist.each do |f|
      if User.exists? f.id
        User.add_friends(user.id, f.id)
    end
  end
end