class AvController < ApplicationController
  require 'time'
  require 'fileutils'
  require 'tempfile'
  require 'open3'
  require 'json'
  require 'webvtt'
  require 'streamio-ffmpeg'

  include AvHelper

  def index
    params[:page] = params[:page] ? params[:page] : 1
    @fullsort = params[:sort] && !params[:sort].empty? ? params[:sort] : 'updated_at_desc'
    @avmaterials = Avmaterial.all
    @editors = @avmaterials.map{|elem| elem.vtteditors }.flatten.uniq.compact
    @editors = [['All', '']].concat(@editors.map{|editor|[editor, editor]})
    if @avmaterials.length > 0
      @oldestdate = Avmaterial.all.order(:updated_at).limit(1).first.updated_at.strftime("%m/%d/%Y")
      whereitems = ["converted", "avtype", "issilent", "publiccaps"]
      whereitems.each do |key|
        if params[key] && !params[key].empty?
            @avmaterials = @avmaterials.where("#{key}": params[key])
        end
      end
      if params[:dateto] && params[:datefrom] && !params[:dateto].empty? && !params[:datefrom].empty?
        datefrom = Date.strptime(params[:datefrom], "%m/%d/%Y")
        dateto = Date.strptime(params[:dateto], "%m/%d/%Y")
        @avmaterials = @avmaterials.where(updated_at: datefrom.beginning_of_day..dateto.end_of_day)
      end
      if params[:vtteditors].present?
        editoritems = @avmaterials.select{|elem| elem.vtteditors.include?(params[:vtteditors])}
        @avmaterials = Avmaterial.where(id: editoritems.map(&:id))
      end
      if params[:search] && !params[:search].empty?
        @avmaterials = @avmaterials.where('outputpath LIKE ?', "%" + params[:search] + "%")
      end
    end
    if params[:captions] && !params[:captions].empty?
      captionlist = @avmaterials.select {|avmaterial| avmaterial.captions.present? == eval(params[:captions])}
      @avmaterials = Avmaterial.where(id: captionlist.map(&:id))
    end
    sort, _, dir = @fullsort.rpartition('_')
    @avmaterials = @avmaterials.order("#{sort}": :"#{dir}").page(params[:page]).per(ENV['per_page'].to_i)
  end
  
  def show
    Rails.cache.clear
    @avmaterials = Avmaterial.find_by slug: params[:slug]
  end

  def transcript
    @avmaterials = Avmaterial.find_by slug: params[:slug]
    transcript = getTranscript(@avmaterials)
    return render html: "#{transcript}".html_safe
  end 

  def embed
    @avmaterials = Avmaterial.find_by slug: params[:slug]
    render layout: 'embed'
  end

  def makepublic
    @avmaterial = Avmaterial.find_by slug: params[:slug]
    @avmaterial.publiccaps = !@avmaterial.publiccaps
    @avmaterial.save
    return redirect_back(fallback_location: root_path)
  end

  def updatevtt
    @avmaterial = Avmaterial.find_by slug: params[:filename]
    path = captionpath(@avmaterial)
    File.open(path, 'w') { |file|
      file.write(params[:contents])
    }
    @avmaterial.vtteditors = params[:editor].split(",").map{|elem|elem.strip}
    @avmaterial.vttlastmodified = Time.now
    @avmaterial.save
    render json: { status: 200, detail: "Caption updated" }, status: 200 
  end

  def edit
    Rails.cache.clear
    @avmaterial = Avmaterial.find_by slug: params[:slug]
  end

  def reprocess
    @avmaterial = Avmaterial.find_by slug: params[:av_slug]
    if File.exist?(@avmaterial.inputpath)
      AvconverterJob.perform_later({:inputpath=>@avmaterial.inputpath})
    else
      flash[:reprocess] = "#{@avmaterial.inputpath} does not exist. Please place file in the path to reprocess."
    end
    redirect_to action: "show", slug: params[:av_slug]
  end

  def chooseposter
    avmaterials = Avmaterial.find_by slug: params[:slug]
    spritepath = avmaterials.exists('-sprite.vtt')
    parse = WebVTT.read(spritepath['path'])
    imagepath = spritepath['url'].reverse.split('/', 2).map(&:reverse).reverse[0]
    @imageareamatch = {}
    parse.cues.each do |cue|
      image, area = cue.text.split("#xywh=")
      image = File.join(imagepath, image)
      if !@imageareamatch.include?(image)
        @imageareamatch[image] = []
      end
      x, y, w, h = area.split(',')
      cords = "#{x},#{y},#{x.to_i+w.to_i},#{y.to_i+h.to_i}"
      @imageareamatch[image].push({'seektime': (cue.start.to_f+cue.end.to_f)/2, 'area': cords})
    end
  end

  def createposter
    avmaterial = Avmaterial.find_by slug: params[:slug]
    output = avmaterial.output
    posterpath = avmaterial.exists('.png')['path']
    filepath = Dir.glob(create_filepath(output))
    movie = FFMPEG::Movie.new(filepath[0]) 
    movie.screenshot(posterpath, {seek_time: params[:seektime], resolution: movie.resolution}, preserve_aspect_ratio: :width)
    redirect_to action: "show", slug: params[:slug]
  end

  def uploadfile
    tmppath = params[:file].tempfile.path
    expextension = params[:extension]
    type = params[:file].content_type
    if type && type.include?('image') && expextension == '.png'
      newpath = tmppath.gsub(File.extname(tmppath), '.png')
      `convert #{tmppath} #{newpath}`
      tmppath = newpath
    end
    extension = File.extname(tmppath)
    if extension != expextension
      flash["#{expextension.gsub('.', '')}error"] = "File is not #{expextension} file! Choose another file and try again."
    else
      avmaterial = Avmaterial.find_by slug: params[:slug]
      path = avmaterial.exists(expextension)['path']
      FileUtils.mv(tmppath, path)
      FileUtils.chmod 0644, path
    end
    redirect_to action: "show", slug: params[:slug]
  end

  def forcedalignment
    if params[:transcript]
      aeneasforcedalignment(params)
      redirect_to action: "show", slug: params[:slug]
    end
  end
end
