# frozen_string_literal: true

module RubyLLM
  # Parameter definition for Tool methods.
  class Parameter
    attr_reader :name, :type, :description, :required

    def initialize(name, type: 'string', desc: nil, required: true)
      @name = name
      @type = type
      @description = desc
      @required = required
    end
  end

  # Base class for creating tools that AI models can use
  class Tool
    # Stops conversation continuation after tool execution
    class Halt
      attr_reader :content, :input_tokens, :output_tokens, :model_id, :raw

      def initialize(content, input_tokens: nil, output_tokens: nil, model_id: nil, raw: nil)
        @content = content
        @input_tokens = input_tokens
        @output_tokens = output_tokens
        @model_id = model_id
        @raw = raw
      end

      def self.from_message(content, message)
        new(
          content,
          input_tokens: message.respond_to?(:input_tokens) ? message.input_tokens : nil,
          output_tokens: message.respond_to?(:output_tokens) ? message.output_tokens : nil,
          model_id: message.respond_to?(:model_id) ? message.model_id : nil,
          raw: message.respond_to?(:raw) ? message.raw : nil
        )
      end

      def with_metadata_from(message)
        self.class.from_message(@content, message)
      end

      def to_s
        @content.to_s
      end

      def to_h
        {
          content: content,
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          model_id: model_id,
          raw: raw
        }.compact
      end
    end

    class << self
      def description(text = nil)
        return @description unless text

        @description = text
      end

      def param(name, **options)
        parameters[name] = Parameter.new(name, **options)
      end

      def parameters
        @parameters ||= {}
      end
    end

    def name
      klass_name = self.class.name
      normalized = klass_name.to_s.dup.force_encoding('UTF-8').unicode_normalize(:nfkd)
      normalized.encode('ASCII', replace: '')
                .gsub(/[^a-zA-Z0-9_-]/, '-')
                .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                .downcase
                .delete_suffix('_tool')
    end

    def description
      self.class.description
    end

    def parameters
      self.class.parameters
    end

    def call(args)
      RubyLLM.logger.debug "Tool #{name} called with: #{args.inspect}"
      result = execute(**args.transform_keys(&:to_sym))
      RubyLLM.logger.debug "Tool #{name} returned: #{result.inspect}"
      result
    end

    def execute(...)
      raise NotImplementedError, 'Subclasses must implement #execute'
    end

    protected

    def halt(message, **metadata)
      Halt.new(message, **metadata)
    end
  end
end
