class Quote
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :date, :open, :high, :low, :close, :adj_close, :volume

  validates_presence_of :date
  validates_format_of :date, :multiline => true, :with => /^[A-Z]{1}[a-z]{2}\s\d{1,2},\s\d{4}$/ 

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def persisted?
    false
  end
end
