require "sinatra"
require "mogli"
require 'erubis'
require 'redis'
require 'models/user'

enable :sessions
set :raise_errors, false
set :show_exceptions, false

# Scope defines what permissions that we are asking the user to grant.
# In this example, we are asking for the ability to publish stories
# about using the app, access to what the user likes, and to be able
# to use their pictures.  You should rewrite this scope with whatever
# permissions your app needs.
# See https://developers.facebook.com/docs/reference/api/permissions/
# for a full list of permissions
FACEBOOK_SCOPE = 'email,offline_access'

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

before do
  # HTTPS redirect
  if settings.environment == :production && request.scheme != 'https'
    redirect "https://#{request.env['HTTP_HOST']}"
  end
  configure :production do
    uri = URI.parse(ENV["REDISTOGO_URL"])
    $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  end

  configure :test, :development do
    $redis = Redis.new
  end
end

helpers do
  def url(path)
    base = "#{request.scheme}://#{request.env['HTTP_HOST']}"
    base + path
  end

  def post_to_wall_url
    "https://www.facebook.com/dialog/feed?redirect_uri=#{url("/close")}&display=popup&app_id=#{@app.id}";
  end

  def send_to_friends_url
    "https://www.facebook.com/dialog/send?redirect_uri=#{url("/close")}&display=popup&app_id=#{@app.id}&link=#{url('/')}";
  end

  def authenticator
    @authenticator ||= Mogli::Authenticator.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
  end

  def first_column(item, collection)
    return ' class="first-column"' if collection.index(item)%4 == 0
  end
  def print_info_on_active(user)
    "#{user["name"]}, #{user["email"]}"
  end

  def validate_post_contents(post)
    post[:time].to_i > 0 ? true : false
  end
  
  def get_me
    client = Mogli::Client.new(session[:at])
    app  = Mogli::Application.find(ENV["FACEBOOK_APP_ID"], client)
    Mogli::User.find("me", client)
  end
end

# the facebook session expired! reset ours and restart the process
error(Mogli::Client::HTTPException) do
  session[:at] = nil
  redirect "/auth/facebook"
end

get "/" do
  redirect "/auth/facebook" unless session[:at]
  @client = Mogli::Client.new(session[:at])

  # limit queries to 15 results
  @client.default_params[:limit] = 15

  @app  = Mogli::Application.find(ENV["FACEBOOK_APP_ID"], @client)
  @user = Mogli::User.find("me", @client)

  # access friends, photos and likes directly through the user instance
  # @friends = @user.friends[0, 4]

  # for other data you can always run fql
  # @friends_using_app = @client.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")

  @title = "DineWithFriends - social eating"
  erb :index
end

# used by Canvas apps - redirect the POST to be a regular GET
post "/" do
  redirect "/"
end

# used to close the browser window opened to post to wall/send to friends
get "/close" do
  "<body onload='window.close();'/>"
end

get "/auth/facebook" do
  session[:at] = nil
  redirect authenticator.authorize_url(:scope => FACEBOOK_SCOPE, :display => 'page')
end

# This is the crucial step for new user creation!!
get '/auth/facebook/callback' do
  client = Mogli::Client.create_from_code_and_authenticator(params[:code], authenticator)
  session[:at] = client.access_token
  me = Mogli::User.find("me", client)
  # unless User.exist? me.id
  #     User.create(me.name, me.id, me.email, client.access_token)
  #   end
  redirect '/'
end

get '/sync_friends' do
  redirect "/auth/facebook" unless session[:at]
  @user = get_me()
  @friends = User.add_existing_friends(@user.id, @user.friends)
  erb :sync_friends
end

get '/register' do
  redirect "/auth/facebook" unless session[:at]
  @client = Mogli::Client.new(session[:at])
  @app  = Mogli::Application.find(ENV["FACEBOOK_APP_ID"], @client)
  @user = Mogli::User.find("me", @client)
  User.create(@user.name, @user.id, @user.email, @client.access_token)
  erb :registered
end

get '/find_matches/:username' do
  if User.exists?(params[:username])
    @friends = User.find(params[:username]).get_active_friends()
    if @friends.length > 0
      erb :show_friends
    else
      erb :no_friends
    end
  else
    erb :no_such_user
  end
end

post '/post' do
  redirect "/auth/facebook" unless session[:at]
  if validate_post_contents(params)
    me = get_me()
    begin
      @user = User.find(me.id)
      @event = @user.create_event(params[:time])
      erb :post_success
    rescue
      erb :post_failed
    end
  else
    erb :post_failed_validation
  end
end

get '/active' do
  @all_users = User.get_all_active_users()
  erb :all_active
end

get '/users/:username' do
  begin
    @user = User.find(params[:username])
    erb :exists
  rescue
    erb :no_such_user
  end
end
