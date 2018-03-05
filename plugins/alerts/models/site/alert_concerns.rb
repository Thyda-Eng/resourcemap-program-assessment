module Site::AlertConcerns
  extend ActiveSupport::Concern

  included do
    before_index :set_alert, if: ->(site) { site.collection.alerts_plugin_enabled? }
  end

  def set_alert
    alert = collection.thresholds_test self unless self.is_a? SiteHistory
    if alert != nil
      extended_properties[:alert] = true
      extended_properties[:alert_id] = alert.id
      extended_properties[:notify_to] = {reporter: alert.notify_to_reporter?}
      extended_properties[:conditions] = alert.conditions
      extended_properties[:color] = alert.color
      extended_properties[:ord] = alert.ord
      if alert.message_notification
        message_notification = alert.message_notification.interpolate(get_template_value_hash)
      else
        message_notification = ''
      end
      extended_properties[:message_notification] = message_notification

      if Settings.notify_alert && alert.is_notify
        phone_numbers = notification_numbers alert
        emails = notification_emails alert

        # to be refactoring
        active_gateway = collection.active_gateway
        suggested_channel = active_gateway.nil?? Channel.default_nuntium_name : active_gateway.nuntium_channel_name
        Resque.enqueue SmsTask, phone_numbers, message_notification, suggested_channel, collection.id unless phone_numbers.empty?
        Resque.enqueue EmailTask, emails, message_notification, "[ResourceMap] Alert Notification" unless emails.empty?
      end
    else
      extended_properties[:alert] = false
    end
    true
  end

  def notification_numbers(alert)
    phone_numbers = collection.users.where(id: alert.phone_notification[:members]).map(&:phone_number).reject &:blank?
    phone_numbers |= alert.phone_notification[:fields].to_a.map{|field| properties[field] }.reject &:blank?
    users = alert.phone_notification[:users].to_a.map{|field| properties[field] }.reject(&:blank?)
    phone_numbers |= User.where(email: users).map(&:phone_number).reject(&:blank?)
  end

  def notification_emails(alert)
    emails = collection.users.where(id: alert.email_notification[:members]).map(&:email).reject &:blank?
    emails |= alert.email_notification[:fields].to_a.map{|field| properties[field] }.reject &:blank?
    emails |= alert.email_notification[:users].to_a.map{|field| properties[field] }.reject(&:blank?)
    if alert.email_notification[:to_reporter] == 'true'
      reporter_email = User.where(id: self.user_id).map(&:email)
      return emails |= reporter_email
    end
    return emails
  end
end
