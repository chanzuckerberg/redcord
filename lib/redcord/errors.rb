# frozen_string_literal: true

module Redcord
  class RedcordError < StandardError; end

  # Raised by Model.find
  class RecordNotFound < RedcordError; end
  class InvalidAction < RedcordError; end

  # Raised by Model.where
  class InvalidQuery < RedcordError; end
  class AttributeNotIndexed < RedcordError; end
  class WrongAttributeType < TypeError; end
  class CustomIndexInvalidQuery < RedcordError; end
  class CustomIndexInvalidDesign < RedcordError; end
  class RedcordDeletedError < ::Redis::CommandError; end

  # Raised by shared_by_attribute
  class InvalidAttribute < RedcordError; end
end
