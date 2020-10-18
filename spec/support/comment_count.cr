class CommentCount < BaseModel
  view do
    belongs_to post : Post
    column count : Int32
  end
end
