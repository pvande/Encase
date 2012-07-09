require 'encase/contract'

module Encase::Contracts
  # Including this module will include the +Contract+ decorator.
  # @param base [Class] the class including this module
  # @implicit
  def self.included(base)
    base.send(:include, Encase::Contract.module)
  end
end
