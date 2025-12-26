class AddActorIndexAndForeignKey < ActiveRecord::Migration[6.1]
  def change
    # Add index for actor_id to improve query performance when eager loading
    add_index :bell_notifications, :actor_id unless index_exists?(:bell_notifications, :actor_id)

    # Add foreign key constraint to maintain referential integrity
    # Note: Use on_delete: :nullify to set actor_id to NULL if user is deleted
    # This preserves the notification even if the actor is removed
    unless foreign_key_exists?(:bell_notifications, :users, column: :actor_id)
      add_foreign_key :bell_notifications, :users, column: :actor_id, on_delete: :nullify
    end
  end
end
