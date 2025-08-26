# frozen_string_literal: true

module AdminHelper
  def pretty_json(data)
    new_data = data.each_with_object({}) do |(key, value), obj|
                 obj[key] = secure_value(key, value)
               end

    JSON.pretty_generate(new_data)
  end

  def secure_key?(data)
    Setting.demo_mode && data.keys.select {|k| secure?(k) }.any?
  end

  def secure_value(key, value)
    (secure?(key) && Setting.demo_mode) ? filtered_token(value) : value
  end

  private

  def secure?(key)
    Rails.application
         .config
         .filter_parameters
         .select { |p| key.to_s.downcase.include?(p.to_s) }
         .size
         .positive?
  end

  def filtered_token(chars)
    chars = chars.to_s
    return '*' * chars.size if chars.size < 4

    average = chars.size / 4
    prefix = chars[0..average - 1]
    hidden = '*' * (average * 2)
    suffix = chars[(prefix.size + average * 2)..-1]
    "#{prefix}#{hidden}#{suffix}"
  end
end
