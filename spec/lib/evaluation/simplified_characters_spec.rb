# frozen_string_literal: true

require 'spec_helper'
require 'csv'
require_relative '../../../lib/evaluation/simplified_characters'

RSpec.describe Evaluation do
  describe 'SIMPLIFIED_CHARACTERS' do
    subject(:table) { Evaluation::SIMPLIFIED_CHARACTERS }

    it { expect(table['这']).to eq(['這']) }
    it { expect(table['随']).to eq(['隨']) }
    it { is_expected.not_to have_key('這') }

    it 'keeps every character the dataset writes' do
      used = %w[train.csv validation.csv test.csv].flat_map do |file|
        CSV.read(File.expand_path("../../../#{file}", __dir__), headers: true).flat_map { |row| row.fields.join.chars }
      end
      expect(used.uniq.select { |char| table.key?(char) }).to be_empty
    end
  end
end
