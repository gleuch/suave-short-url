require 'rubygems'
require 'sinatra'
require 'configatron'
require 'haml'

configure do
  %w(redirect).each{ |lib| require lib }

  ROOT = File.expand_path(File.dirname(__FILE__))
  configatron.configure_from_yaml("#{ROOT}/settings.yml", :hash => Sinatra::Application.environment.to_s)

  unless configatron.enable_public_creation
    require "sinatra-authentication"
    use Rack::Session::Cookie, :secret => 'OMGANOTHERSHORTURLAPP'
  end

  DataMapper.setup(:default, configatron.db_connection.gsub(/ROOT/, ROOT))
  DataMapper.auto_upgrade!
end


helpers do

end #helpers


# Homepage
get '/' do
  haml :index
end

# List all redirects
get '/list' do
 haml :list
end

# Show redirect info
get '/show' do
  haml :show
end

# Redirect create form
get '/new' do
  haml :new
end

# Create the redirect
post '/create' do
  # Create
end

# Redirect edit form
get %r{\/([\w\/]+)\/edit} do
  slug = params[:captures].first
  # Edit
end

# Update the redirect
post %r{\/([\w\/]+)\/update} do
  slug = params[:captures].first
  # Update
end

# Delete URL (does deactivate, not hard delete)
delete %r{\/([\w\/]+)\/delete} do
  slug = params[:captures].first
  # Delete
end


# Default redirection
get %r{\/([\w\/]+)} do
  slug = params[:captures].first
  @redirect = Redirect.find_by_short_code(slug) rescue nil

  unless @redirect.blank?
    redirect_to(@redirect.service_url.blank? ? @redirect.destination_url : @redirect.service_url) and return
  else
    if configatron.enable_default_redirect
      redirect_to configatron.default_redirect_url.gsub(/\%s/, slug) and return
    else
      haml :not_found
    end
  end 
end