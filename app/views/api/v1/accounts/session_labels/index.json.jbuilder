json.payload do
  json.array! @session_labels do |session_label|
    json.partial! 'api/v1/accounts/session_labels/session_label', session_label: session_label
  end
end
