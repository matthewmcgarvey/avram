class CreateCommentCountsView::V20201018010800 < Avram::Migrator::Migration::V1
  def migrate
    execute <<-SQL
      CREATE VIEW comment_counts
      AS SELECT post_id, SUM(custom_id) as count
      FROM comments
      GROUP BY post_id;
    SQL
  end

  def rollback
    execute "DROP VIEW comment_counts"
  end
end
