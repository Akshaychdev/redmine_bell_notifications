class AddActorIndexAndForeignKey < ActiveRecord::Migration[6.1]
  def up
    # Add foreign key constraint to maintain referential integrity
    # Note: Use on_delete: :nullify to set actor_id to NULL if user is deleted
    # This preserves the notification even if the actor is removed
    # Foreign key automatically creates an index in MySQL
    unless foreign_key_exists?(:bell_notifications, :users, column: :actor_id)
      add_foreign_key :bell_notifications, :users, column: :actor_id, on_delete: :nullify
    end
  end

  def down
    # Remove foreign key first, before dropping any indexes
    if foreign_key_exists?(:bell_notifications, :users, column: :actor_id)
      remove_foreign_key :bell_notifications, column: :actor_id
    end

    # Remove index if it exists (only if it was explicitly created, not by FK)
    if index_exists?(:bell_notifications, :actor_id)
      remove_index :bell_notifications, :actor_id
    end
  end
end
