# frozen_string_literal: true

module CanonicalJson
  module_function

  def dump(value)
    JSON.generate(deep_sort(value))
  end

  def deep_sort(value)
    case value
    when Hash
      value.keys.sort.each_with_object({}) do |key, acc|
        acc[key] = deep_sort(value[key])
      end
    when Array
      value.map { |item| deep_sort(item) }
    else
      value
    end
  end
end
