class Redirect
  include DataMapper::Resource

  property :id,               Serial
  property :short_code,       String
  property :service_url,      String
  property :destination_url,  String
  property :created_at,       DateTime
  property :active,           Boolean

end