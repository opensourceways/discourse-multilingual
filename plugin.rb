# frozen_string_literal: true
# name: discourse-multilingual
# about: Features to support multilingual forums
# version: 0.2.10
# url: https://github.com/paviliondev/discourse-multilingual
# authors: Angus McLeod, Robert Barrow
# contact_emails: development@pavilion.tech

enabled_site_setting :multilingual_enabled

# 注册支持的语言（必须使用下划线格式）
register_locale("en", name: "English", nativeName: "English", plural: {
  keys: [:one, :other],
  rule: ->(n) { n == 1 ? :one : :other }
})

register_locale("zh_CN", name: "Chinese", nativeName: "简体中文", plural: {
  keys: [:other],
  rule: ->(n) { :other }
})

register_asset "stylesheets/common/multilingual.scss"
register_asset "stylesheets/mobile/multilingual.scss", :mobile

if respond_to?(:register_svg_icon)
  register_svg_icon "language"
  register_svg_icon "translate"
  register_svg_icon "floppy-disk"
end

require_relative "./lib/validators/content_languages_validator.rb"
require_relative "./lib/validators/language_switcher_validator.rb"
require_relative "./lib/validators/translator_content_tag_validator.rb"

after_initialize do
  require_relative "./lib/multilingual/multilingual.rb"
  require_relative "./lib/multilingual/locale_loader.rb"

  Multilingual.setup if SiteSetting.multilingual_enabled

  # JIT 语言包加载核心逻辑
  ::ExtraLocalesController.prepend Module.new {
    def bundle_js
      if params[:bundle]&.start_with?('multilingual_')
        locale = params[:bundle].sub('multilingual_', '')
        render json: Multilingual::LocaleLoader.load(locale),
               content_type: "application/javascript"
      else
        super
      end
    end
  }

  # 最小化扩展
  ::TopicViewSerializer.prepend Module.new {
    def content_language_tags
      Multilingual::ContentTag.filter(topic.tags).map(&:name)
    end
    def include_content_language_tags?
      Multilingual::ContentLanguage.enabled
    end
  }

  ::TopicListItemSerializer.prepend Module.new {
    def content_language_tags
      Multilingual::ContentTag.filter(topic.tags).map(&:name)
    end
    def include_content_language_tags?
      Multilingual::ContentLanguage.enabled
    end
  }

  # 核心功能注册
  register_editable_user_custom_field [:content_languages, content_languages: []]
  allow_public_user_custom_field :content_languages

  add_to_class(:site, :interface_languages) { Multilingual::InterfaceLanguage.list }
  add_to_class(:site, :content_languages) { Multilingual::ContentLanguage.list }

  add_to_class(:user, :content_languages) do
    Array(self.custom_fields["content_languages"]).select do |l|
      Multilingual::ContentLanguage.enabled?(l)
    end
  end

  add_to_class(:guardian, :topic_requires_language_tag?) do |topic|
    !topic.private_message? && 
    Multilingual::ContentLanguage.enabled &&
    (SiteSetting.multilingual_require_content_language_tag == "yes" ||
     (!is_staff? && SiteSetting.multilingual_require_content_language_tag == "non-staff"))
  end

  # 事件处理
  on(:before_create_topic) do |topic, creator|
    next unless Multilingual::ContentLanguage.enabled
    
    tags = Array(creator.opts[:content_language_tags])
    unless DiscourseTagging.validate_require_language_tag(creator.guardian, topic, tags)
      creator.rollback_from_errors!(topic)
    end
    Multilingual::ContentTag.update_topic(topic, tags)
  end

  # 话题查询扩展
  TopicQuery.add_custom_filter(:content_languages) do |result, query|
    next result unless Multilingual::ContentLanguage.topic_filtering_enabled

    langs = query.user ? query.user.content_languages : Array(query.options[:content_languages])
    langs.present? ? result.joins(:tags).where("tags.name in (?)", langs) : result
  end
end