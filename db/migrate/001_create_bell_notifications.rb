class CreateBellNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :bell_notifications do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :notifiable, polymorphic: true, index: true
      t.string :event_type, null: false
      t.integer :actor_id
      t.string :title, null: false
      t.text :body
      t.string :url
      t.datetime :read_at, index: true
      t.timestamps
    end

    # Composite index for efficient unread queries
    add_index :bell_notifications, [:user_id, :read_at, :created_at], name: 'index_bell_notif_user_read_created'

    # Polymorphic association index
    add_index :bell_notifications, [:notifiable_type, :notifiable_id], name: 'index_bell_notif_notifiable'

    # Index for cleanup queries
    add_index :bell_notifications, :created_at
  end
end
