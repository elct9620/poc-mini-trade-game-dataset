# frozen_string_literal: true

##
# = Evaluation::SIMPLIFIED_CHARACTERS
# Simplified-only characters mapped to their Taiwan traditional forms, loaded from simplified_characters.tsv.
# The character set pattern cannot separate them, since Unicode interleaves simplified and traditional ideographs,
# so they are counted after decoding and a game converts the one-to-one entries.
#
# == Reference
# - {docs/tools/evaluation.md}[docs/tools/evaluation.md]
##
class Evaluation
  SIMPLIFIED_CHARACTERS = File.readlines(File.join(__dir__, 'simplified_characters.tsv'), chomp: true)
                              .reject { |line| line.start_with?('#') }
                              .to_h { |line| line.split("\t").then { |simplified, traditional| [simplified, traditional.split] } }
                              .freeze
end
