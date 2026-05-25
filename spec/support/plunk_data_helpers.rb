module PlunkDataHelpers
  def non_persistent_plunk_value(value)
    { value: value, persistent: false }
  end

  def plunk_data_value(data, key)
    value = data[key] || data[key.to_s]
    return value[:value] if value.is_a?(Hash) && value.key?(:value)
    return value['value'] if value.is_a?(Hash) && value.key?('value')

    value
  end
end

RSpec.configure do |config|
  config.include PlunkDataHelpers
end
