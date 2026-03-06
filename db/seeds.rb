# Create admin user
admin = User.find_or_initialize_by(email: "admin@prd.com")
admin.update!(
  name: "Admin",
  password: "Ax+by+cz=123",
  admin: true,
  notion_api_key: ENV["NOTION_API_KEY"],
  notion_database_id: ENV["NOTION_DATABASE_ID"]
)
puts "Admin user created/updated: #{admin.email}"
