class User
  attr :fb_uid, :name, :email, :auth_token
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

  def initialize(name, fb_uid, email, auth_token)
    @name = name
    @fb_uid = fb_uid
    @email = email
    @auth_token = auth_token
  end

  def self.create(name, fb_uid, email, auth_token)
    $redis.hmset('user:'+fb_uid, 'name', name, 'email',
      email, 'auth_token', auth_token )
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
  
  def self.friends? (fid1, fid2)
    $redis.sismember('user:'+fid1+':friends', fid2)
  end
  
  # for a given fb_uid, add all friends who are using DWF
  def self.add_existing_friends(id, friends)
    added = []
    friends.each do |f|
      if User.exists? f.id
        unless User.friends? id, f.id
          User.add_friends(id, f.id)
          added << f.name
        end
      end
    end
    added
  end
end