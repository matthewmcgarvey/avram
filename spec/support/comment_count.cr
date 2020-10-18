class CommentCount < BaseModel
  skip_default_columns

  table do
    belongs_to post : Post
    column count : Int32
  end
end
