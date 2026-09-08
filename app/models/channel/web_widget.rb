# == Schema Information
#
# Table name: channel_web_widgets
#
#  id                       :integer          not null, primary key
#  allowed_domains          :text             default("")
#  announcement             :string
#  announcement_link_target :string           default("new_tab"), not null
#  announcement_url         :string
#  continuity_via_email     :boolean          default(TRUE), not null
#  display_name             :string
#  feature_flags            :integer          default(7), not null
#  hmac_mandatory           :boolean          default(FALSE)
#  hmac_token               :string
#  pre_chat_form_enabled    :boolean          default(FALSE)
#  pre_chat_form_options    :jsonb
#  reply_time               :integer          default("in_a_few_minutes")
#  website_token            :string
#  website_url              :string
#  welcome_tagline          :string
#  welcome_title            :string
#  widget_color             :string           default("#1f93ff")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :integer
#
# Indexes
#
#  index_channel_web_widgets_on_hmac_token     (hmac_token) UNIQUE
#  index_channel_web_widgets_on_website_token  (website_token) UNIQUE
#

class Channel::WebWidget < ApplicationRecord
  include Channelable
  include FlagShihTzu

  self.table_name = 'channel_web_widgets'
  EDITABLE_ATTRS = [:website_url, :widget_color, :welcome_title, :welcome_tagline, :reply_time, :pre_chat_form_enabled,
                    :continuity_via_email, :hmac_mandatory, :allowed_domains, :announcement, :announcement_url,
                    :announcement_link_target, :display_name,
                    { pre_chat_form_options: [:pre_chat_message, :require_email,
                                              { pre_chat_fields:
                                                [:field_type, :label, :placeholder, :name, :enabled, :type, :enabled, :required,
                                                 :locale, { values: [] }, :regex_pattern, :regex_cue] }] },
                    { selected_feature_flags: [] }].freeze
  ANNOUNCEMENT_LINK_TARGETS = %w[new_tab current_tab].freeze

  before_validation :validate_pre_chat_options
  validates :website_url, presence: true
  validates :widget_color, presence: true
  # The announcement link is rendered as an href in the visitor's browser, so anything but a real
  # web address (javascript: chief among them) has to be rejected before it is stored.
  validates :announcement_url, format: { with: %r{\Ahttps?://}, message: I18n.t('errors.inboxes.announcement_url.invalid') },
                               allow_blank: true
  validates :announcement_link_target, inclusion: { in: ANNOUNCEMENT_LINK_TARGETS }
  has_many :portals, foreign_key: 'channel_web_widget_id', dependent: :nullify, inverse_of: :channel_web_widget

  has_secure_token :website_token
  has_secure_token :hmac_token

  has_flags 1 => :attachments,
            2 => :emoji_picker,
            3 => :end_conversation,
            4 => :use_inbox_avatar_for_bot,
            5 => :allow_mobile_webview,
            :column => 'feature_flags',
            :check_for_column => false

  enum reply_time: { in_a_few_minutes: 0, in_a_few_hours: 1, in_a_day: 2 }

  def name
    'Website'
  end

  # What the visitor is shown. The inbox name is an internal label the team picks for the
  # dashboard, so a configured display name takes precedence everywhere the widget names itself.
  def visitor_name
    display_name.presence || inbox.name
  end

  def web_widget_script
    "
    <script>
      (function(d,t) {
        var BASE_URL=\"#{ENV.fetch('FRONTEND_URL', '')}\";
        var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
        g.src=BASE_URL+\"/packs/js/sdk.js\";
        g.async = true;
        s.parentNode.insertBefore(g,s);
        g.onload=function(){
          window.chatwootSDK.run({
            websiteToken: '#{website_token}',
            baseUrl: BASE_URL
          })
        }
      })(document,\"script\");
    </script>
    "
  end

  def validate_pre_chat_options
    return if pre_chat_form_options.with_indifferent_access['pre_chat_fields'].present?

    self.pre_chat_form_options = {
      pre_chat_message: 'Share your queries or comments here.',
      pre_chat_fields: [
        {
          'field_type': 'standard', 'label': 'Email Id', 'name': 'emailAddress', 'type': 'email', 'required': true, 'enabled': false
        },
        {
          'field_type': 'standard', 'label': 'Full name', 'name': 'fullName', 'type': 'text', 'required': false, 'enabled': false
        },
        {
          'field_type': 'standard', 'label': 'Phone number', 'name': 'phoneNumber', 'type': 'text', 'required': false, 'enabled': false
        }
      ]
    }
  end

  def create_contact_inbox(additional_attributes = {})
    ::ContactInboxWithContactBuilder.new({
                                           inbox: inbox,
                                           contact_attributes: { additional_attributes: additional_attributes }
                                         }).perform
  end
end
