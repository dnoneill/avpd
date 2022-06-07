class AvSerializer < ActiveModel::Serializer
  attributes :context, :slug, :id, :type, :embedurl, :poster, :avmaterial, :captions, :sprites, :transcript,  :issilent, :duration, :waveform
  include Rails.application.routes.url_helpers
  def context
    return api_context_url
  end

  def type
    return "https://schema.org/" + object.avtype.capitalize + 'Object'
  end
      
  def id
    return av_api_url(object.slug)
  end

  def embedurl
    return embed_url(object.slug)
  end

  def captions
    if object.captions && object.publiccaps
      return object.captions
    end
  end

  def duration
    if object.duration
      return ActiveSupport::Duration.build(object.duration.to_f).iso8601(precision: 3)
    end
  end
end
