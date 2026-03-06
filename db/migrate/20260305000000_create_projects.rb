class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :slack_thread_url
      t.string :notion_url
      t.integer :problem_type, null: false
      t.integer :priority, null: false
      t.integer :status, null: false, default: 0
      t.string :owner
      t.text :summary
      t.jsonb :hypothesis_tree

      t.timestamps
    end

    add_index :projects, :created_at, order: { created_at: :desc }
    add_index :projects, :status
    add_index :projects, :priority
  end
end

