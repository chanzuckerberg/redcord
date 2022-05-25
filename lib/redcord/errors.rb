# frozen_string_literal: true

module Redcord
  # Raised by Model.find
  class RecordNotFound < StandardError; end
  class InvalidAction < StandardError; end

  # Raised by Model.where
  class InvalidQuery < StandardError; end
  class AttributeNotIndexed < StandardError; end
  class WrongAttributeType < TypeError; end
  class CustomIndexInvalidQuery < StandardError; end
  class CustomIndexInvalidDesign < StandardError; end
  class RedcordDeletedError < ::Redis::CommandError; end

  # Raised by shared_by_attribute
  class InvalidAttribute < StandardError; end
end
