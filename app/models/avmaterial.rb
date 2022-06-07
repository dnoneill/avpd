class Avmaterial < ApplicationRecord
  require 'json'
  require 'mini_magick'
  require 'webvtt'
  include AvHelper
  include Rails.application.routes.url_helpers
  serialize :vtteditors, Array
  
  def to_param
    slug
  end
  def poster
      check = exists('.png')
      if self.slug && check['exists']
        imageurl = check['url']
        imagesrc = check['path']
      elsif ENV['default_poster'].present? 
        imageurl = ENV['default_poster']
        imagesrc = imageurl
      end
      if imagesrc.present?
        imageinfo = MiniMagick::Image.open(imagesrc)
        return {'id' => imageurl, 'format' => 'image/png', 'width' => imageinfo[:width], 'height' => imageinfo[:height], 'label' => 'Poster image'}
      end
  end

  def output
    if !self.outputpath || !File.directory?(self.outputpath)
      folder = File.join(ENV['avoutputpath'], self.slug)
      if !File.directory?(folder)
        folder = nil
      end
    else
      folder = self.outputpath
    end
    return folder
  end

  def exists(extension) 
    if self.output
      filename = File.join(self.output, self.slug) + extension
      urlfilepath = ENV['ignorepath'] && filename ? filename.gsub(ENV['ignorepath'], '') : filename;
      return {'exists' => File.exists?(filename), 'url' => File.join(root_url, urlfilepath), 'path' => filename}
    else
      return {'exists' => false}
    end
  end
  
  def transcript
    transcripts = []
    vttexists = exists('.vtt')
    if vttexists['exists'] && self.publiccaps
      transcripts.push({'id' => transcript_url(self.slug), 'format' => 'text/txt', 'label' => 'Text transcript'})
    end
    pdfexists = exists('.pdf')
    pdfexists = pdfexists['exists'] ? pdfexists : exists('-transcriptedited.pdf')
    if pdfexists['exists']
      transcripts.push({'id' => pdfexists['url'], 'format' => 'application/pdf', 'label' => 'PDF transcript'})
    end
    transcripts = transcripts.length == 0 ? nil : transcripts
    return transcripts
  end

  def sprites
    spriteexists = exists('-sprite.vtt')
    if spriteexists['exists']
      return {'id' => spriteexists['url'], 'format' => 'text/vtt', "label" => "image sprite metadata"}
    end
  end

  def avmaterial
    if self.output
      files = Dir.glob(create_filepath(self.output))
      if files.length > 0
        output = []
        files.each do |file|
          extension = File.extname(file)
          filedata = exists(extension)
          avdict = {"id" => filedata['url'], "format" => "#{self.avtype}/#{extension.delete('.')}"}
          videometa = ffmpegdata(file)['metadata']['streams'].select{|item|item['codec_type'] == 'video'}
          if videometa.length > 0
            avdict["height"] = videometa[0]["height"]
            avdict["width"] = videometa[0]["width"]
          end
          output.push(avdict)
        end
      end
      return output
    end
  end

  def duration
    if self.ffmpeginfo && !self.ffmpeginfo.include?('error')
      durationseconds = JSON.parse(self.ffmpeginfo)['metadata']['format']['duration']
      return durationseconds
    else
      return nil
    end
  end

  # def silencedata
  #   if self.silencedata
  #     return JSON.parse(self.silencedata)
  #   end
  # end

  def captions
    doesexists = exists('.vtt')
    if doesexists['exists']
      return {'id' => doesexists['url'], 'format' => 'text/vtt', 'label' => 'Captions'}
    end
  end

  def waveform
    waves = exists('.json')
    if waves['exists']
      return {'id' => waves['url'], 'format' => 'application/json', 'label' => 'Waveform JSON'}
    end
  end
end
