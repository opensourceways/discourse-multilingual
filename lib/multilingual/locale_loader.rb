# frozen_string_literal: true
class Multilingual::LocaleLoader
  # JIT 语言包加载核心方法（类方法）
  def self.load(locale)
    {
      locale.to_sym => {
        js: I18n.t("js", locale: locale).deep_symbolize_keys
      }
    }.to_json
  end

  # 标签翻译加载（兼容旧版）
  def self.load_tags(locale)
    {
      locale.to_sym => {
        tags: Multilingual::Translation.get("tag").slice(locale.to_sym)
      }
    }.to_json
  end
end