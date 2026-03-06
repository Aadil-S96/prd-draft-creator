class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.string :avatar_url
      t.string :google_uid
      t.string :password_digest
      t.boolean :admin, default: false, null: false
      t.string :notion_api_key
      t.string :notion_database_id
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :google_uid, unique: true

    add_reference :projects, :user, foreign_key: true
  end
end
