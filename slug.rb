class Redirect
  include DataMapper::Resource

  property :id,               Serial
  property :slug,             String
  property :service_url,      String
  property :destination_url,  String
  property :views_count,      Integer
  property :created_at,       DateTime
  property :active,           Boolean


  has n, :audits

end


# Audit log, for tracking view counts, referrer information, and more.
# (Only used if enabled in settings.yml.)
class Audit
  include DataMapper::Resource
  
  property :id,               Serial
  property :redirect_id,      Integer
  property :redirect_url,     String
  property :referer_url,      String
  property :ip_address,       String
  property :user_agent,       String
  property :created_at,       DateTime


  belongs_to :redirect

end