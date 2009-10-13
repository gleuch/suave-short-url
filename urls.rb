require 'rubygems'
require 'sinatra'

configure do
  %w(dm-core dm-types dm-aggregates dm-timestamps haml configatron slug).each{ |lib| require lib }

  ROOT = File.expand_path(File.dirname(__FILE__))
  configatron.configure_from_yaml("#{ROOT}/settings.yml", :hash => Sinatra::Application.environment.to_s)

  unless configatron.enable_public_creation
    require "sinatra-authentication"
    use Rack::Session::Cookie, :secret => 'OMGANOTHERSHORTURLAPP'

    class User
      # Is the user admin?
      def has_urls?; self.permission_level == 2; end
    end    
  end

  DataMapper.setup(:default, configatron.db_connection.gsub(/ROOT/, ROOT))
  DataMapper.auto_upgrade!
end



helpers do
  # Does vistior/user have permission?
  def allowed_to
    redirect '/login' and return if !configatron.enable_public_creation && !current_user.has_urls?
  end

  # Get the redirect information via the slug
  def get_redirect(slug)
    @redirect = Redirect.first(:slug => slug) rescue nil
  end

  def smart_title
    if request.path =~ /\/login/i;      @title = 'Login'
    elsif request.path =~ /\/signup/i;  @title = 'Signup'
    elsif request.path =~ /\/logout/i;  @title = 'Logout'
    elsif request.path =~ /\/users/i;   @title = 'Users'; end
    (@title ||= '') << "#{!@title.blank? ? ' / ' : ''}#{configatron.site_name}"
    @title
  end

  # Allow custom templating w/ haml
  def smart_haml(view, opts={})
    view = configatron.template_folder_path.gsub(/\%s/, view.to_s).to_sym
    opts = opts.merge(:layout => configatron.template_folder_path.gsub(/\%s/, 'layout').to_sym)
    haml(view, opts)
  end

end #helpers



# Homepage
get '/' do
  smart_haml :index
end

# List all redirects
get '/list' do
  allowed_to
  @redirects = Redirect.all
  smart_haml :list
end

# Redirect create form
get '/new' do
  allowed_to
  @redirect = Redirect.new
  smart_haml :edit
end

# Create the redirect
post '/create' do
  allowed_to

  if @redirect = Redirect.create(params[:slug].merge(:active => true))
    redirect("/#{@redirect.slug}/info", :status => 303)
  else
    @error = 'An error occured while attempting to create this redirect.'
    haml :error
  end
end

# Redirect edit form
get %r{\/([\w\/]+)\/edit} do
  allowed_to

  slug = params[:captures].first
  get_redirect(slug)

  smart_haml (!@redirect.blank? ? :edit : :not_found)
end

# Update the redirect
post %r{\/([\w\/]+)\/update} do
  allowed_to

  slug = params[:captures].first
  get_redirect(slug)
  smart_haml :not_found and return if @redirect.blank?

  unless @redirect.blank?
    if @redirect.update_attributes(params[:slug])
      redirect("/#{@redirect.slug}/info", :status => 303)
    else
      @error = 'An error occured while attempting to update this redirect.'
      smart_haml :error
    end
  else
    smart_haml :not_found
  end
end

# Delete URL (does deactivate, not hard delete, for stats reasons)
delete %r{\/([\w\/]+)\/delete} do
  allowed_to

  slug = params[:captures].first
  get_redirect(slug)

  unless @redirect.blank?
    if @redirect.update_attributes(:active => false)
      redirect("/#{@redirect.slug}/info", :status => 303)
    else
      @error = 'An error occured while attempting to delete this redirect.'
      smart_haml :error
    end
  else
    smart_haml :not_found
  end
end

# Show redirect information
get %r{\/([\w\/]+)\/info} do
  allowed_to

  slug = params[:captures].first
  get_redirect(slug)
  smart_haml (!@redirect.blank? ? :info : :not_found)
end


# Default redirection
get %r{\/([\w\/]+)} do
  slug = params[:captures].first
  get_redirect(slug)

  audit = {
    :redirect_id => (!@redirect.blank? ? @redirect.id : nil),
    :redirect_url => (@redirect.blank? ? (request.env['REQUEST_URI'] || nil) : nil),
    :referer_url => request.env['HTTP_REFERER'] || nil,
    :ip_address => request.env['REMOTE_ADDR'] || nil,
    :user_agent => request.env['HTTP_USER_AGENT'] || nil
  }

  unless @redirect.blank?
    if @redirect.active
      @redirect.audits.create(audit) unless configatron.enable_redirect_audits
      redirect(@redirect.service_url.blank? ? @redirect.destination_url : @redirect.service_url) and return
    else # The redirect has been "deleted", therefore it should pretend to fail.
      smart_haml :not_found
    end
  else
    if configatron.enable_default_redirect
      Audit.create(audit) unless configatron.enable_redirect_audits # Make audit

      redirect configatron.default_redirect_url.gsub(/\%s/, slug) and return
    else
      smart_haml :not_found
    end
  end
end