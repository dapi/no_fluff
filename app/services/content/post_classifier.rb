# frozen_string_literal: true

module Content
  class PostClassifier
    INSTRUCTIONS = <<~TEXT.freeze
      Classify the Telegram post. Return JSON only with deliverable (boolean),
      importance_score (integer 0..100), and confidence (number 0..1).
      A post is deliverable only when it is useful rather than fluff or advertising.
    TEXT

    def classify(post)
      response = RubyLLM.chat.with_instructions(INSTRUCTIONS).ask(post.text.to_s)
      data = JSON.parse(response.content).symbolize_keys
      {
        deliverable: ActiveModel::Type::Boolean.new.cast(data.fetch(:deliverable)),
        importance_score: Integer(data.fetch(:importance_score)).clamp(0, 100),
        confidence: Float(data.fetch(:confidence)).clamp(0.0, 1.0)
      }
    rescue JSON::ParserError, KeyError, TypeError, ArgumentError => error
      raise Content::ClassificationError, "invalid classifier response: #{error.class}"
    end
  end

  class ClassificationError < StandardError; end
end
