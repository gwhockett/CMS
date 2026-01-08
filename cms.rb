# consider completing " 19. Next Steps" from Project: File-based CMS
# also 20. security steps

require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubi"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions

  set :erb, :escape_html => true
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(file_path)
  content = File.read(file_path)
  case File.extname(file_path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    render_markdown(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_list
  user_credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(user_credentials_path)
end

def valid_user_credentials?(username, password)
  credentials = load_user_list

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def user_signed_in?
  !!session[:username]
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

get "/new" do
  require_signed_in_user

  erb :new
end

post "/create" do
  require_signed_in_user
  filename = params[:filename].to_s

  if filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)
    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created."
    redirect "/"
  end
end

get '/:filename' do
  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])
  
  @filename = params[:filename]
  @content = File.read(file_path)
  
  erb :edit
end

post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])
  
  File.write(file_path, params[:content])
  
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"   
end

post "/:filename/delete" do
  require_signed_in_user
  
  file_path = File.join(data_path, params[:filename])
  
  File.delete(file_path)
  
  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]

  if valid_user_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "You Got In!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "User Signed Out."
  redirect "/"
end

#  Don’t rescue everything. A bare rescue will catch all exceptions, including
#  unrelated bugs (e.g., permission errors, nils, etc.). Here it will turn them into
#  “[something] does not exist,” which can hide real problems.
#  If you do rescue, rescue a specific error like Errno::ENOENT. 
# def load_file(root)
#   begin
#     File.read(session[:file_path] = root + "/data/" + params[:text_file])
#   rescue
#     session[:error] = "#{params[:text_file]} does not exist."
#     redirect '/'
#   end
# end