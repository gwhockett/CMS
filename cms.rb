require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubi"
require "redcarpet"

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

root = File.expand_path("..", __FILE__)

get '/' do
  @files = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end

  erb :index
end

get '/:text_file' do
  file_path = File.join(root, "data", params[:text_file])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:text_file]} does not exist."
    redirect "/"
  end
end

#  Don’t rescue everything. A bare rescue will catch all exceptions, including
#  unrelated bugs (e.g., permission errors, nils, etc.), and turn them into
#  “does not exist,” which can hide real problems.
#  If you do rescue, rescue a specific error like Errno::ENOENT. 
# def load_file(root)
#   begin
#     File.read(session[:file_path] = root + "/data/" + params[:text_file])
#   rescue
#     session[:error] = "#{params[:text_file]} does not exist."
#     redirect '/'
#   end
# end