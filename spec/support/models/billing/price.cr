module Billing
  class Price < BaseModel
    skip_default_columns

    table(table_name: "prices") do
      primary_key id : UUID
      timestamps
      column in_cents : Int32
      belongs_to line_item : LineItem
    end
  end
end

class PriceQuery < Billing::Price::BaseQuery
end

class SavePrice < Billing::Price::SaveOperation
  permit_columns in_cents
  needs line_item : LineItem

  before_save do
    line_item_id.value = line_item.id
  end
end
