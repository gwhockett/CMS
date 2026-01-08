ENV["RACK_ENV"] = "test"
require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin"} }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document "history.txt", "history tested"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "history tested"
  end

  def test_viewing_markdown_document
    create_document "about.md", "## Markdown tested"

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h2>Markdown tested</h2>"
  end

#  def test_document_not_found - old test
#    # create_document "nofile.ext" # execute to ensure that the test can fail
#    
#    get "/nofile.ext" # Attempt to access a nonexistent file
#
#    assert_equal 302, last_response.status # Assert that the user was redirected
#
#    get last_response["Location"] # Request the page that the user was redirected to
#
#    assert_equal 200, last_response.status
#    assert_includes last_response.body, "nofile.ext does not exist"
#
#    get "/" # Reload the page
#    refute_includes last_response.body, "nofile.ext does not exist"
#    # Assert that our message has been removed
#  end

  def test_document_not_found
  # create_document "nofile.ext" # uncomment to ensure that test can fail

    get "/nofile.ext"

    assert_equal 302, last_response.status
    assert_equal "nofile.ext does not exist.", session[:message]

    get "/"
    get "/" # Reload the page to delete message
    refute_includes last_response.body, "nofile.ext does not exist."
  end

  def test_editing_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_ditiing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    create_document "changes.txt"
    
    post "/changes.txt", {content: "new content tested"}, admin_session

    assert_equal 302, last_response.status

    # get last_response["Location"]
    # assert_includes last_response.body, "changes.txt has been updated"

    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content tested"
  end

  def test_updating_document_signed_out
    create_document "changes.txt"
    
    post "/changes.txt", {content: "new content tested"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_document_form_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    post "/create", {filename: "test.txt"}, admin_session
    assert_equal 302, last_response.status

    # get last_response["Location"]
    # assert_includes last_response.body, "test.txt has been created"

    assert_equal "test.txt has been created.", session[:message]

    get "/"
    # assert_includes last_response.body, "test.txt"
    assert_includes last_response.body, %q(href="/test.txt") # checks for the link
  end

  def test_create_new_document_signed_out
    post "/create", {filename: "test.txt"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_codcument_without_filename
    post "/create", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end


  def test_deleting_document
    create_document("test_doc.txt")

    post "/test_doc.txt/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "test_doc.txt has been deleted.", session[:message]

    # get last_response["Location"]
    # assert_includes last_response.body, "test_doc.txt has been deleted"


    get "/"
    # refute_includes last_response.body, "test_doc.txt"
    refute_includes last_response.body, %q(href="/test.txt") # checks for the link
  end

  def test_deleting_document_signed_out
    create_document("test_doc.txt")

    post "/test_doc.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status

    assert_equal "You Got In!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    # assert_includes last_response.body, "You Got In!"
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:message]
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    # post "/users/signin", username: "admin", password: "secret"
    # get last_response["Location"]
    get "/", {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "User Signed Out.", session[:message]
    
    get last_response["Location"]
    # assert_includes last_response.body, "User Signed Out."
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end