# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/validator'

RSpec.describe Validator do
  describe '.all' do
    subject(:validators) { described_class.all }

    it { expect(validators).to all(respond_to(:validate)) }
    it { expect(validators.map(&:class)).to include(Validator::JsonSyntax, Validator::PriceRangeValidator, Validator::BargainingValidator) }
  end
end
