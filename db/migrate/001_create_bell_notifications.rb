class CreateBellNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :bell_notifications do |t|
      t.integer :user_id, null: false
      t.integer :notifiable_id
      t.string :notifiable_type
      t.string :event_type, null: false
      t.integer :actor_id
      t.string :title, null: false
      t.text :body
      t.string :url
      t.datetime :read_at
      t.timestamps
    end

    # Add foreign key manually with correct type
    add_foreign_key :bell_notifications, :users
    add_index :bell_notifications, :user_id
    add_index :bell_notifications, :read_at

    # Composite index for efficient unread queries
    add_index :bell_notifications, [:user_id, :read_at, :created_at], name: 'index_bell_notif_user_read_created'

    # Polymorphic association index
    add_index :bell_notifications, [:notifiable_type, :notifiable_id], name: 'index_bell_notif_notifiable'

    # Index for cleanup queries
    add_index :bell_notifications, :created_at
  end
end
